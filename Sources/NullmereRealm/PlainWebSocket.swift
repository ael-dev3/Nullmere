import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A WebSocket (RFC 6455) over a plain TCP connection, for `ws://` alone:
/// where the system has none of its own (Linux's Foundation has no
/// WebSockets), and for a realm on this machine. Text messages only; pings
/// are answered as they come. Every call but `close` blocks.
final class PlainWebSocket: @unchecked Sendable {
    enum Failure: Error, Equatable {
        case badAddress
        case unreachable
        case refused(String)
        case closed
        case tooLarge
    }

    private let descriptor: Int32
    private let lock = NSLock()
    private var buffer: [UInt8] = []
    private var isClosed = false
    /// The most a single message may hold.
    static let largest = 8 << 20

    private init(descriptor: Int32, leftover: [UInt8]) {
        self.descriptor = descriptor
        self.buffer = leftover
    }

    /// Connects to `url`, asking for `protocols` and sending `headers`.
    static func open(_ url: URL, protocols: [String], headers: [String: String], timeout: Double = 10) throws -> PlainWebSocket {
        guard url.scheme == "ws", let host = url.host else { throw Failure.badAddress }
        let port = url.port ?? 80
        let descriptor = try connect(host: host, port: port, timeout: timeout)
        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query { path += "?" + query }
        var key = [UInt8](repeating: 0, count: 16)
        for index in key.indices { key[index] = UInt8.random(in: 0...255) }
        var request = "GET \(path) HTTP/1.1\r\nHost: \(host):\(port)\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        request += "Sec-WebSocket-Key: \(Data(key).base64EncodedString())\r\nSec-WebSocket-Version: 13\r\n"
        if !protocols.isEmpty { request += "Sec-WebSocket-Protocol: \(protocols.joined(separator: ", "))\r\n" }
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) { request += "\(name): \(value)\r\n" }
        request += "\r\n"
        do {
            try write(Array(request.utf8), to: descriptor)
            // The answer's head, up to the blank line; what follows is frames.
            var head: [UInt8] = []
            while true {
                let chunk = try read(from: descriptor)
                head += chunk
                if let end = PlainWebSocket.headEnd(head) {
                    let text = String(decoding: head[..<end], as: UTF8.self)
                    guard text.hasPrefix("HTTP/1.1 101") else {
                        throw Failure.refused(text.split(separator: "\r\n").first.map(String.init) ?? text)
                    }
                    setTimeout(descriptor, seconds: 0)
                    return PlainWebSocket(descriptor: descriptor, leftover: Array(head[(end + 4)...]))
                }
                guard head.count < 64 << 10 else { throw Failure.refused("an answer with no end") }
            }
        } catch {
            _ = systemClose(descriptor)
            throw error
        }
    }

    /// Where the head of an HTTP answer ends: the start of its blank line.
    static func headEnd(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        for index in 0...(bytes.count - 4) where bytes[index] == 13 && bytes[index + 1] == 10 && bytes[index + 2] == 13 && bytes[index + 3] == 10 {
            return index
        }
        return nil
    }

    // MARK: Frames

    /// A frame as a client sends it: masked, as the protocol asks.
    static func frame(opcode: UInt8, payload: [UInt8], mask: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = [0x80 | opcode]
        let count = payload.count
        if count < 126 {
            bytes.append(0x80 | UInt8(count))
        } else if count < 65_536 {
            bytes += [UInt8(0x80 | 126), UInt8(count >> 8), UInt8(count & 0xFF)]
        } else {
            bytes.append(UInt8(0x80 | 127))
            for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8((UInt64(count) >> UInt64(shift)) & 0xFF)) }
        }
        bytes += mask
        for (index, byte) in payload.enumerated() { bytes.append(byte ^ mask[index % 4]) }
        return bytes
    }

    /// A frame read from the front of `bytes`, if all of it is there: its
    /// opcode, whether it ends its message, its payload, and its length.
    static func parse(_ bytes: [UInt8]) throws -> (opcode: UInt8, final: Bool, payload: [UInt8], length: Int)? {
        guard bytes.count >= 2 else { return nil }
        let final = bytes[0] & 0x80 != 0
        let opcode = bytes[0] & 0x0F
        let masked = bytes[1] & 0x80 != 0
        var count = Int(bytes[1] & 0x7F)
        var at = 2
        if count == 126 {
            guard bytes.count >= 4 else { return nil }
            count = Int(bytes[2]) << 8 | Int(bytes[3])
            at = 4
        } else if count == 127 {
            guard bytes.count >= 10 else { return nil }
            var long: UInt64 = 0
            for index in 2..<10 { long = long << 8 | UInt64(bytes[index]) }
            guard long <= UInt64(largest) else { throw Failure.tooLarge }
            count = Int(long)
            at = 10
        }
        var mask: [UInt8] = []
        if masked {
            guard bytes.count >= at + 4 else { return nil }
            mask = Array(bytes[at..<(at + 4)])
            at += 4
        }
        guard bytes.count >= at + count else { return nil }
        var payload = Array(bytes[at..<(at + count)])
        if masked {
            for index in payload.indices { payload[index] ^= mask[index % 4] }
        }
        return (opcode, final, payload, at + count)
    }

    func send(text: String) throws {
        var mask = [UInt8](repeating: 0, count: 4)
        for index in mask.indices { mask[index] = UInt8.random(in: 0...255) }
        try sendFrame(PlainWebSocket.frame(opcode: 0x1, payload: Array(text.utf8), mask: mask))
    }

    private func sendFrame(_ bytes: [UInt8]) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { throw Failure.closed }
        try PlainWebSocket.write(bytes, to: descriptor)
    }

    /// The next text message; nil once the other side closes.
    func receive() throws -> String? {
        var message: [UInt8] = []
        while true {
            while let frame = try PlainWebSocket.parse(buffer) {
                buffer.removeFirst(frame.length)
                switch frame.opcode {
                case 0x8:
                    close()
                    return nil
                case 0x9:
                    try sendFrame(PlainWebSocket.frame(opcode: 0xA, payload: frame.payload, mask: [1, 2, 3, 4]))
                case 0x1, 0x2, 0x0:
                    message += frame.payload
                    guard message.count <= PlainWebSocket.largest else { throw Failure.tooLarge }
                    if frame.final {
                        return String(decoding: message, as: UTF8.self)
                    }
                default:
                    break
                }
            }
            let chunk: [UInt8]
            do {
                chunk = try PlainWebSocket.read(from: descriptor)
            } catch {
                if isClosedNow { return nil }
                throw error
            }
            buffer += chunk
        }
    }

    private var isClosedNow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isClosed
    }

    /// Ends the connection; a `receive` waiting returns nil.
    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true
        _ = shutdown(descriptor, Int32(SHUT_RDWR))
        _ = PlainWebSocket.systemClose(descriptor)
    }

    deinit { close() }

    // MARK: The socket

    private static func connect(host: String, port: Int, timeout: Double) throws -> Int32 {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if os(Linux)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        var found: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &found) == 0, let first = found else { throw Failure.unreachable }
        defer { freeaddrinfo(first) }
        var candidate: UnsafeMutablePointer<addrinfo>? = first
        while let info = candidate {
            let descriptor = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
            if descriptor >= 0 {
                setTimeout(descriptor, seconds: timeout)
                #if !os(Linux)
                var on: Int32 = 1
                _ = setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
                #endif
                if systemConnect(descriptor, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 {
                    return descriptor
                }
                _ = systemClose(descriptor)
            }
            candidate = info.pointee.ai_next
        }
        throw Failure.unreachable
    }

    private static func setTimeout(_ descriptor: Int32, seconds: Double) {
        var time = timeval(tv_sec: Int(seconds), tv_usec: 0)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
    }

    private static func write(_ bytes: [UInt8], to descriptor: Int32) throws {
        var sent = 0
        while sent < bytes.count {
            let count = bytes[sent...].withUnsafeBytes { raw -> Int in
                #if os(Linux)
                return Glibc.send(descriptor, raw.baseAddress, raw.count, Int32(MSG_NOSIGNAL))
                #else
                return Darwin.send(descriptor, raw.baseAddress, raw.count, 0)
                #endif
            }
            guard count > 0 else { throw Failure.closed }
            sent += count
        }
    }

    private static func read(from descriptor: Int32) throws -> [UInt8] {
        var chunk = [UInt8](repeating: 0, count: 16 << 10)
        let count = chunk.withUnsafeMutableBytes { raw in recv(descriptor, raw.baseAddress, raw.count, 0) }
        guard count > 0 else { throw Failure.closed }
        return Array(chunk[..<count])
    }

    private static func systemConnect(_ descriptor: Int32, _ address: UnsafeMutablePointer<sockaddr>?, _ length: socklen_t) -> Int32 {
        #if os(Linux)
        return Glibc.connect(descriptor, address, length)
        #else
        return Darwin.connect(descriptor, address, length)
        #endif
    }

    private static func systemClose(_ descriptor: Int32) -> Int32 {
        #if os(Linux)
        return Glibc.close(descriptor)
        #else
        return Darwin.close(descriptor)
        #endif
    }
}

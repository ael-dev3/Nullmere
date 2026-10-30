import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A WebSocket server on this machine, for one client at a time, that
/// answers the handshake and then says what a test tells it to: enough of
/// SpacetimeDB's subscribe endpoint to hear a client out.
public final class WebSocketServer: @unchecked Sendable {
    private let listener: Int32
    public let port: Int
    private let lock = NSLock()
    private var client: Int32 = -1
    private var heardText: [String] = []
    private var heardHead = ""
    /// What the server says once a client has sent its first message.
    private let replies: [String]
    /// Whether it closes once it has said them.
    private let closesAfter: Bool
    /// The status line it answers the handshake with, if not 101.
    private let refusal: String?

    public init(replies: [String], closesAfter: Bool = false, refusal: String? = nil) throws {
        self.replies = replies
        self.closesAfter = closesAfter
        self.refusal = refusal
        #if os(Linux)
        let stream = Int32(SOCK_STREAM.rawValue)
        #else
        let stream = SOCK_STREAM
        #endif
        let descriptor = socket(AF_INET, stream, 0)
        var on: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(descriptor, 1) == 0 else { throw PlainError.cannotListen }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        listener = descriptor
        port = Int(UInt16(bigEndian: address.sin_port))
        let thread = Thread { [self] in serve() }
        thread.start()
    }

    enum PlainError: Error { case cannotListen }

    public var url: URL { URL(string: "ws://127.0.0.1:\(port)/v1/database/realm/subscribe?compression=None")! }

    /// The texts the client sent, and its handshake's head.
    public var heard: [String] {
        lock.lock()
        defer { lock.unlock() }
        return heardText
    }

    public var head: String {
        lock.lock()
        defer { lock.unlock() }
        return heardHead
    }

    public func stop() {
        lock.lock()
        let client = self.client
        lock.unlock()
        if client >= 0 { _ = shutdown(client, Int32(SHUT_RDWR)) }
        _ = shutdown(listener, Int32(SHUT_RDWR))
        #if os(Linux)
        _ = Glibc.close(listener)
        #else
        _ = Darwin.close(listener)
        #endif
    }

    private func serve() {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        lock.lock()
        self.client = client
        lock.unlock()
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        // The handshake.
        while !String(decoding: bytes, as: UTF8.self).contains("\r\n\r\n") {
            let count = buffer.withUnsafeMutableBytes { recv(client, $0.baseAddress, $0.count, 0) }
            guard count > 0 else { return }
            bytes += buffer[..<count]
        }
        let text = String(decoding: bytes, as: UTF8.self)
        lock.lock()
        heardHead = text
        lock.unlock()
        if let refusal {
            send(Array("\(refusal)\r\nContent-Length: 0\r\n\r\n".utf8), to: client)
            return
        }
        var answer = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(Self.proof(for: text))\r\n"
        if text.contains("v1.json.spacetimedb") { answer += "Sec-WebSocket-Protocol: v1.json.spacetimedb\r\n" }
        send(Array((answer + "\r\n").utf8), to: client)
        bytes.removeAll()
        // The client's first message, then what the server has to say.
        while true {
            if let frame = try? Self.read(&bytes) {
                lock.lock()
                heardText.append(String(decoding: frame, as: UTF8.self))
                lock.unlock()
                break
            }
            let count = buffer.withUnsafeMutableBytes { recv(client, $0.baseAddress, $0.count, 0) }
            guard count > 0 else { return }
            bytes += buffer[..<count]
        }
        // A ping first, which the client must answer.
        send([0x89, 0x02, 0x68, 0x69], to: client)
        for reply in replies {
            let payload = Array(reply.utf8)
            var frame: [UInt8] = [0x81]
            if payload.count < 126 {
                frame.append(UInt8(payload.count))
            } else {
                frame += [126, UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)]
            }
            send(frame + payload, to: client)
        }
        if closesAfter {
            send([0x88, 0x00], to: client)
        }
        // Hears the client out until it goes.
        while true {
            let count = buffer.withUnsafeMutableBytes { recv(client, $0.baseAddress, $0.count, 0) }
            guard count > 0 else { return }
            bytes += buffer[..<count]
            while let frame = try? Self.read(&bytes) {
                lock.lock()
                heardText.append(String(decoding: frame, as: UTF8.self))
                lock.unlock()
            }
        }
    }

    /// The handshake's proof, from the client's key: checked by the system's
    /// own WebSockets, where there are any.
    static func proof(for head: String) -> String {
        let key = head.split(separator: "\r\n").first { $0.lowercased().hasPrefix("sec-websocket-key:") }
            .map { $0.dropFirst("sec-websocket-key:".count).trimmingCharacters(in: .whitespaces) } ?? ""
        #if canImport(CryptoKit)
        let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
        return Data(digest).base64EncodedString()
        #else
        return key
        #endif
    }

    /// One masked frame from the front of `bytes`, taken off it.
    private static func read(_ bytes: inout [UInt8]) throws -> [UInt8]? {
        guard bytes.count >= 2 else { return nil }
        var count = Int(bytes[1] & 0x7F), at = 2
        if count == 126 {
            guard bytes.count >= 4 else { return nil }
            count = Int(bytes[2]) << 8 | Int(bytes[3])
            at = 4
        }
        guard bytes.count >= at + 4 + count else { return nil }
        let mask = Array(bytes[at..<(at + 4)])
        let payload = (0..<count).map { bytes[at + 4 + $0] ^ mask[$0 % 4] }
        bytes.removeFirst(at + 4 + count)
        return payload
    }

    private func send(_ bytes: [UInt8], to client: Int32) {
        _ = bytes.withUnsafeBytes { raw in
            #if os(Linux)
            Glibc.send(client, raw.baseAddress, raw.count, Int32(MSG_NOSIGNAL))
            #else
            Darwin.send(client, raw.baseAddress, raw.count, 0)
            #endif
        }
    }
}

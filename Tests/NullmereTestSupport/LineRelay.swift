import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A line between a client on this machine and a server, carried byte for
/// byte through a port of its own, that a test can cut and mend: the network
/// lost under a client, every connection it had through the line dropped and
/// none taken while it is down, then found again, the server going on all
/// the while. HTTP and WebSockets alike go through it unread.
public final class LineRelay: @unchecked Sendable {
    /// The port on this machine the line is reached at.
    public let port: Int
    private let listener: Int32
    private var server: sockaddr_in
    private let lock = NSLock()
    /// Every connection through the line: the client's end and the server's.
    private var lines: [ObjectIdentifier: Line] = [:]
    private var down = false
    private var stopped = false
    private var refusedWhileDown = 0
    private var carried = 0

    private final class Line {
        let client: Int32
        let server: Int32
        /// Its two directions still carrying.
        var carrying = 2
        init(client: Int32, server: Int32) {
            self.client = client
            self.server = server
        }
    }

    enum RelayError: Error { case cannotListen, unknownHost(String) }

    /// A line to the server `url` names, by its host and port: this machine's
    /// own, by its number or as localhost.
    public init(to url: URL) throws {
        let host = url.host ?? "127.0.0.1"
        let number = host == "localhost" ? "127.0.0.1" : host
        let address = inet_addr(number)
        guard address != INADDR_NONE else { throw RelayError.unknownHost(host) }
        server = sockaddr_in()
        server.sin_family = sa_family_t(AF_INET)
        server.sin_port = in_port_t(UInt16(url.port ?? (url.scheme == "https" ? 443 : 80)).bigEndian)
        server.sin_addr.s_addr = address
        let descriptor = socket(AF_INET, Self.stream, 0)
        var on: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
        var mine = sockaddr_in()
        mine.sin_family = sa_family_t(AF_INET)
        mine.sin_port = 0
        mine.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &mine) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(descriptor, 64) == 0 else {
            Self.close(descriptor)
            throw RelayError.cannotListen
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &mine) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        listener = descriptor
        port = Int(UInt16(bigEndian: mine.sin_port))
        Thread { [self] in serve() }.start()
    }

    /// `url` reached through the line: the same, but for its host and port.
    public func carrying(_ url: URL) -> URL {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        parts.host = "127.0.0.1"
        parts.port = port
        return parts.url!
    }

    /// Cuts the line: every connection through it dropped at once, and none
    /// taken until it is mended.
    public func cut() {
        lock.lock()
        defer { lock.unlock() }
        down = true
        for line in lines.values {
            _ = shutdown(line.client, Int32(SHUT_RDWR))
            _ = shutdown(line.server, Int32(SHUT_RDWR))
        }
    }

    /// Mends the line: connections taken through it again.
    public func mend() {
        lock.lock()
        down = false
        lock.unlock()
    }

    /// Connections the line turned away while it was down.
    public var refused: Int {
        lock.lock()
        defer { lock.unlock() }
        return refusedWhileDown
    }

    /// Connections the line has carried to the server.
    public var connections: Int {
        lock.lock()
        defer { lock.unlock() }
        return carried
    }

    /// Stops the line for good: every connection dropped, and the port let go.
    public func stop() {
        cut()
        lock.lock()
        stopped = true
        lock.unlock()
        _ = shutdown(listener, Int32(SHUT_RDWR))
        Self.close(listener)
    }

    private func serve() {
        while true {
            let client = accept(listener, nil, nil)
            lock.lock()
            let over = stopped
            lock.unlock()
            if over {
                if client >= 0 { Self.close(client) }
                return
            }
            guard client >= 0 else {
                if errno == EINTR { continue }
                return
            }
            if isDown {
                lock.lock()
                refusedWhileDown += 1
                lock.unlock()
                Self.close(client)
                continue
            }
            let upstream = socket(AF_INET, Self.stream, 0)
            Self.quiet(client)
            Self.quiet(upstream)
            var address = server
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(upstream, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            let line = Line(client: client, server: upstream)
            lock.lock()
            // Cut while it connected: dropped as the cut dropped the rest.
            let taken = connected == 0 && !down && !stopped
            if taken {
                lines[ObjectIdentifier(line)] = line
                carried += 1
            } else if down {
                refusedWhileDown += 1
            }
            lock.unlock()
            guard taken else {
                Self.close(client)
                Self.close(upstream)
                continue
            }
            Thread { [self] in carry(from: client, to: upstream, of: line) }.start()
            Thread { [self] in carry(from: upstream, to: client, of: line) }.start()
        }
    }

    private var isDown: Bool {
        lock.lock()
        defer { lock.unlock() }
        return down
    }

    /// Carries one direction of a connection until either end goes; then
    /// both ends are shut, so the other direction stops too, and the last
    /// to stop closes them.
    private func carry(from source: Int32, to sink: Int32, of line: Line) {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        carrying: while true {
            let count = buffer.withUnsafeMutableBytes { recv(source, $0.baseAddress, $0.count, 0) }
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { break }
            var sent = 0
            while sent < count {
                let wrote = buffer.withUnsafeBytes { raw in Self.send(sink, raw.baseAddress! + sent, count - sent) }
                if wrote < 0, errno == EINTR { continue }
                guard wrote > 0 else { break carrying }
                sent += wrote
            }
        }
        _ = shutdown(source, Int32(SHUT_RDWR))
        _ = shutdown(sink, Int32(SHUT_RDWR))
        lock.lock()
        line.carrying -= 1
        let last = line.carrying == 0
        if last { lines[ObjectIdentifier(line)] = nil }
        lock.unlock()
        if last {
            Self.close(line.client)
            Self.close(line.server)
        }
    }

    #if os(Linux)
    private static let stream = Int32(SOCK_STREAM.rawValue)
    #else
    private static let stream = SOCK_STREAM
    #endif

    /// A write to a peer gone is an error to the writer, never a signal that
    /// ends the process.
    private static func quiet(_ descriptor: Int32) {
        #if !os(Linux)
        var on: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }

    private static func send(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
        #if os(Linux)
        return Glibc.send(descriptor, bytes, count, Int32(MSG_NOSIGNAL))
        #else
        return Darwin.send(descriptor, bytes, count, 0)
        #endif
    }

    private static func close(_ descriptor: Int32) {
        #if os(Linux)
        _ = Glibc.close(descriptor)
        #else
        _ = Darwin.close(descriptor)
        #endif
    }
}

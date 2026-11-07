#!/usr/bin/env python3
"""A line between a client on this machine and a server, carried byte for
byte, that can be cut and mended while it runs: the network lost under the
keeper's phone and found again, the realm going on all the while.
HTTP and WebSockets alike go through it unread.

    scripts/line-relay.py <port> <host:port>   # 0 for a port of its own
    scripts/line-relay.py --self-test

Says "listening <port>" once it listens. SIGUSR1 cuts the line: every
connection through it dropped at once, and none taken (each accepted and
closed) until SIGUSR2 mends it. SIGTERM stops it.
"""
import signal
import socket
import sys
import threading


class Line:
    """The relay: its listening socket, and every connection through it."""

    def __init__(self, port, server):
        self.server = server
        self.lock = threading.RLock()
        self.pairs = {}
        self.down = False
        self.refused = 0
        self.carried = 0
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind(("127.0.0.1", port))
        self.listener.listen(64)
        self.port = self.listener.getsockname()[1]

    def cut(self):
        with self.lock:
            self.down = True
            for ends in self.pairs.values():
                for end in ends:
                    shut(end)

    def mend(self):
        with self.lock:
            self.down = False

    def serve(self):
        while True:
            try:
                client, _ = self.listener.accept()
            except OSError:
                return
            with self.lock:
                down = self.down
                if down:
                    self.refused += 1
            if down:
                client.close()
                continue
            upstream = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                upstream.connect(self.server)
            except OSError:
                client.close()
                upstream.close()
                continue
            with self.lock:
                # Cut while it connected: dropped as the cut dropped the rest.
                if self.down:
                    self.refused += 1
                    client.close()
                    upstream.close()
                    continue
                key = object()
                self.pairs[key] = (client, upstream)
                self.carried += 1
            left = [2]
            for source, sink in ((client, upstream), (upstream, client)):
                threading.Thread(target=self.carry, args=(source, sink, key, left), daemon=True).start()

    def carry(self, source, sink, key, left):
        """One direction of a connection, until either end goes; then both
        ends are shut, so the other direction stops too, and the last to
        stop closes them."""
        try:
            while True:
                data = source.recv(65536)
                if not data:
                    break
                sink.sendall(data)
        except OSError:
            pass
        shut(source)
        shut(sink)
        with self.lock:
            left[0] -= 1
            last = left[0] == 0
            if last:
                ends = self.pairs.pop(key, ())
        if last:
            for end in ends:
                end.close()

    def stop(self):
        self.cut()
        shut(self.listener)
        self.listener.close()


def shut(end):
    try:
        end.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass


def self_test():
    """An echo server, a line to it: carried, cut (dropped and turned away),
    mended (carried again)."""
    echo = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    echo.bind(("127.0.0.1", 0))
    echo.listen(8)

    def answer():
        while True:
            try:
                peer, _ = echo.accept()
            except OSError:
                return

            def back(peer=peer):
                with peer:
                    while True:
                        data = peer.recv(4096)
                        if not data:
                            return
                        peer.sendall(data)
            threading.Thread(target=back, daemon=True).start()
    threading.Thread(target=answer, daemon=True).start()

    line = Line(0, echo.getsockname())
    threading.Thread(target=line.serve, daemon=True).start()

    def ask(words):
        with socket.create_connection(("127.0.0.1", line.port), timeout=5) as asking:
            asking.sendall(words)
            return asking.recv(4096)

    failures = []
    if ask(b"hello") != b"hello":
        failures.append("not carried")
    held = socket.create_connection(("127.0.0.1", line.port), timeout=5)
    held.sendall(b"held")
    if held.recv(4096) != b"held":
        failures.append("the held connection not carried")
    line.cut()
    if held.recv(4096) != b"":
        failures.append("the held connection not dropped at the cut")
    held.close()
    try:
        turned = ask(b"anyone?")
    except OSError:
        turned = b""
    if turned != b"":
        failures.append("carried while cut")
    if line.refused < 1:
        failures.append("nothing turned away while cut")
    line.mend()
    if ask(b"again") != b"again":
        failures.append("not carried once mended")
    line.stop()
    echo.close()
    if failures:
        print("line-relay.py self-test failed: " + "; ".join(failures), file=sys.stderr)
        return 1
    print("line-relay.py self-test passed")
    return 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 64
    host, _, port = arguments[1].rpartition(":")
    line = Line(int(arguments[0]), (host or "127.0.0.1", int(port)))

    def cut(*_):
        line.cut()
        print("cut", flush=True)

    def mend(*_):
        line.mend()
        print("mended", flush=True)

    signal.signal(signal.SIGUSR1, cut)
    signal.signal(signal.SIGUSR2, mend)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(f"listening {line.port}", flush=True)
    try:
        line.serve()
    finally:
        print(f"carried {line.carried} connections, turned away {line.refused} while cut", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

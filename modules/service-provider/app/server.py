#!/usr/bin/env python3
"""Tiny HTTPS app for the PrivateLink lab. Standard library only.

Every connection from the NLB starts with a PROXY protocol v2 header. For PrivateLink
traffic AWS adds a TLV of type 0xEA whose value is one subtype byte (0x01) followed by
the caller's VPC endpoint ID. This server reads that header, then does the TLS handshake,
and tells the caller which endpoint it came through. That is how the app tells Payments
from Analytics even though every connection arrives from the NLB's own addresses.
"""

import datetime
import ipaddress
import json
import os
import socket
import socketserver
import ssl
import struct

PP2_SIGNATURE = b"\r\n\r\n\x00\r\nQUIT\n"
PP2_TYPE_AWS = 0xEA
PP2_SUBTYPE_AWS_VPCE_ID = 0x01

PORT = int(os.environ.get("APP_PORT", "443"))
INSTANCE_ID = os.environ.get("INSTANCE_ID", "unknown")
AZ_ID = os.environ.get("AZ_ID", "unknown")
CREDS = os.environ.get("CREDENTIALS_DIRECTORY", "/etc/app/tls")


def _recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("connection closed while reading PROXY header")
        data += chunk
    return data


def read_proxy_v2(sock):
    """Consume a PROXY v2 header. Returns (client_ip, vpce_id). Raises ValueError if absent."""
    head = _recv_exact(sock, 16)
    if head[:12] != PP2_SIGNATURE:
        raise ValueError("no PROXY v2 signature")
    ver_cmd, fam, length = head[12], head[13], struct.unpack("!H", head[14:16])[0]
    if ver_cmd >> 4 != 2:
        raise ValueError("unsupported PROXY version")
    body = _recv_exact(sock, length)

    client_ip, offset = None, 0
    if ver_cmd & 0x0F == 0x01:  # PROXY command (0x00 is LOCAL, used for health checks)
        if fam >> 4 == 0x1:  # AF_INET
            client_ip, offset = str(ipaddress.IPv4Address(body[0:4])), 12
        elif fam >> 4 == 0x2:  # AF_INET6
            client_ip, offset = str(ipaddress.IPv6Address(body[0:16])), 36

    vpce_id = None
    while offset + 3 <= len(body):
        tlv_type = body[offset]
        tlv_len = struct.unpack("!H", body[offset + 1:offset + 3])[0]
        value = body[offset + 3:offset + 3 + tlv_len]
        if tlv_type == PP2_TYPE_AWS and value[:1] == bytes([PP2_SUBTYPE_AWS_VPCE_ID]):
            vpce_id = value[1:].decode("ascii", "replace")
        offset += 3 + tlv_len
    return client_ip, vpce_id


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        sock = self.request
        sock.settimeout(5)
        try:
            client_ip, vpce_id = read_proxy_v2(sock)
        except (ValueError, ConnectionError, socket.timeout):
            return  # TCP health checks and anything without a valid header end here

        try:
            tls = self.server.tls.wrap_socket(sock, server_side=True)
            request_line = tls.recv(4096).split(b"\r\n", 1)[0].decode("ascii", "replace")
        except (ssl.SSLError, OSError):
            return

        body = (
            "shared-services app\n"
            f"served_by={INSTANCE_ID} ({AZ_ID})\n"
            f"caller_vpce={vpce_id or 'unknown'}\n"
        ).encode()
        tls.sendall(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n"
            + f"Content-Length: {len(body)}\r\n\r\n".encode()
            + body
        )
        tls.close()

        # One structured line per request: which consumer called, from where, for what.
        print(json.dumps({
            "time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "caller_vpce": vpce_id,
            "client_ip": client_ip,
            "request": request_line,
        }), flush=True)


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    server = Server(("0.0.0.0", PORT), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(os.path.join(CREDS, "app.crt"), os.path.join(CREDS, "app.key"))
    server.tls = ctx
    print(f"listening on {PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

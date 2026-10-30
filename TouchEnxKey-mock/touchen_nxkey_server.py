#!/usr/bin/env python3
"""T-money TouchEn nxKey installation-check mock; Python standard library only.

The protocol was independently implemented from T-money's public client checks.
No keyboard capture, encryption, login, or outbound network calls are implemented.
"""

import argparse
import base64
import hashlib
import json
import os
import ssl
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ORIGIN = "https://pay.tmoney.co.kr"
CALL_PATH = "/raon/touchenex/Call"
MAX_MESSAGE_BYTES = 1024 * 1024
VERSIONS = {
    "daemon": "1.0.1.8",
    "ex": "1.0.1.1550",
    "m": [{"name": "nxkey", "version": "1.0.0.18"}],
}
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def diagnostic(event, **fields):
    # Only explicitly selected metadata; never log arguments, license, keys or body.
    print(json.dumps(dict(event=event, **fields), ensure_ascii=False), file=sys.stderr, flush=True)


class ProtocolError(Exception):
    def __init__(self, reason, **facts):
        super().__init__(reason)
        self.facts = facts


def installation_response(text):
    # Browser WebSocket.send({}) coerces the port probe to this exact string.
    if text == "[object Object]":
        return {}
    try:
        request = json.loads(text)
    except json.JSONDecodeError as error:
        raise ProtocolError("invalid_json", expected="JSON object", length=len(text), position=error.pos)
    if not isinstance(request, dict):
        raise ProtocolError("invalid_request_type", expected="object", actual=type(request).__name__)
    if request.get("origin") != ORIGIN:
        raise ProtocolError("unsupported_origin", expected=ORIGIN, actual_matches=False,
                            field_present="origin" in request)
    if request.get("init") == "get_versions" and request.get("m") == "nxkey":
        return VERSIONS
    if request.get("module") != "nxkey":
        raise ProtocolError("unsupported_module", expected="nxkey", actual_matches=False)
    identifier = request.get("id")
    if not isinstance(identifier, str) or not identifier:
        raise ProtocolError("invalid_request_id", expected="nonempty string",
                            actual=type(identifier).__name__)
    function = request.get("exfunc", {})
    if not isinstance(function, dict):
        raise ProtocolError("invalid_function", expected="object", actual=type(function).__name__)
    name = function.get("fname")
    if not isinstance(name, str) or len(name) > 80 or not name.isidentifier():
        raise ProtocolError("invalid_function_name", expected="method identifier, at most 80 characters",
                            actual_type=type(name).__name__,
                            actual_length=len(name) if isinstance(name, str) else None)
    if request.get("cmd") == "setcallback" and name in ("new", "add"):
        reply = {}
    elif request.get("cmd") == "native" and name == "Key_Init":
        # The page otherwise leaves TK_bInit=0 and blurs its input fields.
        # Acknowledge setup only; no keyboard protection or encryption is run.
        reply = {"result": "true", "enc2": "false"}
    elif request.get("cmd") == "native" and name == "Key_Start":
        # The page otherwise clears ordinary input while bstart remains zero.
        # Do not inspect exfunc.args: it can contain a field's current value.
        reply = {"StartReadyComplete": "success"}
    elif request.get("cmd") == "native" and name in ("Key_Stop", "Key_RealStop"):
        reply = {"result": "true"}
    else:
        # Acknowledge transport to drain the client's queue, but never claim that
        # an unimplemented keyboard/crypto operation succeeded.
        reply = {"result": "false", "error": "INSTALLATION_CHECK_ONLY"}
        diagnostic("unsupported_operation", command_is_native=request.get("cmd") == "native",
                   actual_function=name, expected="setup, ready or stop acknowledgement",
                   arguments_omitted=True)
    # InvokeCallback unwraps response.reply.reply; the interface then unwraps
    # result.reply before calling the page's callback. Both layers are needed.
    return {"response": {"id": identifier, "status": "TRUE", "reply": {"reply": {"reply": reply}}}}


def read_exact(stream, count):
    result = bytearray()
    while len(result) < count:
        block = stream.read(count - len(result))
        if not block:
            raise EOFError()
        result.extend(block)
    return bytes(result)


def read_frame(stream):
    first, second = read_exact(stream, 2)
    final, opcode = bool(first & 0x80), first & 0x0F
    if first & 0x70 or not second & 0x80:
        raise ProtocolError("invalid_frame", expected="masked frame with RSV=0",
                            masked=bool(second & 0x80), rsv=first & 0x70)
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", read_exact(stream, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", read_exact(stream, 8))[0]
    maximum = 125 if opcode >= 8 else MAX_MESSAGE_BYTES
    if length > maximum or (opcode >= 8 and not final):
        raise ProtocolError("invalid_frame_size", actual=length, maximum=maximum,
                            final=final, opcode=opcode)
    if opcode == 8 and length == 1:
        raise ProtocolError("invalid_close_size", actual=length, expected="zero or at least two bytes")
    mask = read_exact(stream, 4)
    payload = read_exact(stream, length)
    return final, opcode, bytes(value ^ mask[index % 4] for index, value in enumerate(payload))


def write_frame(stream, payload, opcode=1):
    length = len(payload)
    if length < 126:
        header = bytes((0x80 | opcode, length))
    elif length < 65536:
        header = bytes((0x80 | opcode, 126)) + struct.pack("!H", length)
    else:
        header = bytes((0x80 | opcode, 127)) + struct.pack("!Q", length)
    stream.write(header + payload)
    stream.flush()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() != "websocket":
            if self.path == "/":
                body = json.dumps({"name": "TouchEnxKey-mock", "mode": "installation-only"}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_error(404)
            return
        if self.path not in ("/", CALL_PATH) or self.headers.get("Origin") != ORIGIN:
            diagnostic("unsupported_handshake", path_matches=self.path in ("/", CALL_PATH),
                       origin_matches=self.headers.get("Origin") == ORIGIN)
            self.send_error(403)
            return
        key = self.headers.get("Sec-WebSocket-Key", "")
        try:
            valid_key = len(base64.b64decode(key, validate=True)) == 16
        except (ValueError, base64.binascii.Error):
            valid_key = False
        if not valid_key or self.headers.get("Sec-WebSocket-Version") != "13":
            diagnostic("invalid_handshake", key_valid=valid_key,
                       expected_version="13", version_matches=self.headers.get("Sec-WebSocket-Version") == "13")
            self.send_error(400)
            return
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode("ascii")).digest()).decode("ascii")
        self.send_response(101)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.close_connection = True
        fragmented = False
        message = bytearray()
        try:
            while True:
                final, opcode, payload = read_frame(self.rfile)
                if opcode == 8:
                    write_frame(self.wfile, payload, opcode=8)
                    return
                if opcode == 9:
                    write_frame(self.wfile, payload, opcode=10)
                    continue
                if opcode == 10:
                    continue
                if opcode == 1 and not fragmented:
                    message = bytearray(payload)
                elif opcode == 0 and fragmented:
                    message.extend(payload)
                else:
                    raise ProtocolError("invalid_opcode", expected="text or continuation", actual=opcode,
                                        fragmented=fragmented)
                if len(message) > MAX_MESSAGE_BYTES:
                    raise ProtocolError("message_too_large", maximum=MAX_MESSAGE_BYTES, actual=len(message))
                fragmented = not final
                if final:
                    try:
                        text = message.decode("utf-8")
                    except UnicodeDecodeError as error:
                        raise ProtocolError("invalid_utf8", byte_count=len(message), position=error.start)
                    response = installation_response(text)
                    write_frame(self.wfile, json.dumps(response, separators=(",", ":")).encode("utf-8"))
        except EOFError:
            pass
        except ProtocolError as error:
            diagnostic(str(error), **error.facts, body_omitted=True)
            try:
                write_frame(self.wfile, struct.pack("!H", 1002), opcode=8)
            except OSError:
                pass
        except (OSError, ssl.SSLError) as error:
            diagnostic("connection_error", error_type=type(error).__name__, errno=error.errno)


def watch_parent(pid):
    while True:
        time.sleep(2)
        try:
            os.kill(pid, 0)
        except OSError:
            os._exit(0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--port", type=int, default=34581)
    parser.add_argument("--parent-pid", type=int)
    args = parser.parse_args()
    phase = "load_certificate"
    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(args.cert, args.key)
        phase = "bind_loopback"
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
        phase = "configure_tls"
        server.socket = context.wrap_socket(server.socket, server_side=True)
    except (OSError, ssl.SSLError) as error:
        diagnostic("startup_failed", expected="readable TLS files and free loopback port",
                   host="127.0.0.1", port=args.port, error_type=type(error).__name__, errno=error.errno,
                   phase=phase, filename=error.filename,
                   key_contents_omitted=True)
        return 1
    if args.parent_pid:
        threading.Thread(target=watch_parent, args=(args.parent_pid,), daemon=True).start()
    diagnostic("ready", host="127.0.0.1", port=args.port, mode="installation-only")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

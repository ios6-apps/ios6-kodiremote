#!/usr/bin/env python3
"""A stand-in for Kodi's remote-control interfaces, for developing and testing the app without a Kodi.

    python3 tools/mock_kodi.py [--host 127.0.0.1] [--port 8090] [--notify-port 9090] [--user kodi --password secret]

It serves, with made-up content:
  * JSON-RPC over HTTP at /jsonrpc (POST with a JSON body, or GET with ?request=...): the methods the app uses
    (JSONRPC.Ping, Application.*, Player.*, Input.*, Addons.*, GUI.ActivateWindow) with a small playing state that moves on.
  * /image/<anything>: a generated PNG, so cover art and add-on icons show up.
  * Kodi's TCP notification channel (default port 9090, the app always uses 9090): events are pushed to every connected client.
  * Optional HTTP Basic authentication (--user/--password), answering 401 like Kodi does.

Mock-only helpers, for tests:
  GET  /mock/log      every call received so far, as JSON: [{"method": ..., "params": ...}, ...]
  POST /mock/reset    clears the log and puts the playing state back to its start
  POST /mock/notify   broadcasts {"method": ..., "params": ...} to the notification clients, e.g.
                      {"method": "Input.OnInputRequested", "params": {"data": {"title": "Search", "type": "keyboard", "value": ""}}}
                      (--split sends each event in two TCP segments, to exercise the app's reassembly)

Standard library only. Prints "ready" once it listens."""
import argparse, base64, hashlib, json, socket, struct, sys, threading, time, zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ADDONS = {
    "video": [("plugin.video.demo.films", "Open Films", "Freely licensed short films"),
              ("plugin.video.demo.live", "Live Streams", "Made-up channel list"),
              ("plugin.video.demo.docs", "Documentaries", "")],
    "audio": [("plugin.audio.demo.radio", "Internet Radio", "Made-up station list"),
              ("plugin.audio.demo.podcasts", "Podcasts", "Shows and episodes")],
    "executable": [("script.demo.sleep", "Sleep Timer", "Stops playback after a while"),
                   ("script.demo.tools", "Maintenance Tools", "Clean caches")],
}
ITEM = {"title": "Sintel", "label": "Sintel", "type": "movie", "thumbnail": "image://demo-sintel/"}
TOTAL = 14 * 60 + 48     # seconds
START_AT = 3 * 60 + 5    # where playback starts after a reset


class State:
    def __init__(self, args):
        self.args = args
        self.lock = threading.Lock()
        self.clients = []
        self.reset()

    def reset(self):
        with self.lock:
            self.log = []
            self.volume, self.muted = 60, False
            self.paused, self.position, self.stamp = False, float(START_AT), time.time()
            self.playing = True

    def now(self):
        """position in seconds, advanced by the wall clock while playing"""
        if self.playing and not self.paused:
            self.position = min(TOTAL, self.position + time.time() - self.stamp)
        self.stamp = time.time()
        return self.position

    def notify(self, method, params):
        data = json.dumps({"jsonrpc": "2.0", "method": method, "params": params}).encode()
        for c in list(self.clients):
            try:
                if self.args.split:
                    c.sendall(data[:len(data) // 2]); time.sleep(0.2); c.sendall(data[len(data) // 2:])
                else:
                    c.sendall(data)
            except OSError:
                self.clients.remove(c)

    def rpc(self, method, params):
        with self.lock:
            if method not in ("JSONRPC.Ping", "Application.GetProperties", "Player.GetActivePlayers", "Player.GetItem", "Player.GetProperties"):
                self.log.append({"method": method, "params": params})
            pos = self.now()
            if method == "JSONRPC.Ping":
                return "pong"
            if method == "Application.GetProperties":
                return {"volume": self.volume, "muted": self.muted}
            if method == "Application.SetVolume":
                self.volume = max(0, min(100, int(params.get("volume", self.volume)))); return self.volume
            if method == "Player.GetActivePlayers":
                return [{"playerid": 1, "type": "video", "playertype": "internal"}] if self.playing else []
            if method == "Player.GetItem":
                return {"item": ITEM}
            if method == "Player.GetProperties":
                t = int(pos)
                return {"speed": 0 if self.paused else 1, "percentage": 100.0 * pos / TOTAL,
                        "time": {"hours": t // 3600, "minutes": t // 60 % 60, "seconds": t % 60, "milliseconds": 0},
                        "totaltime": {"hours": TOTAL // 3600, "minutes": TOTAL // 60 % 60, "seconds": TOTAL % 60, "milliseconds": 0}}
            if method == "Player.Seek":
                v = params.get("value", {})
                if isinstance(v, dict) and "percentage" in v:
                    self.position = TOTAL * float(v["percentage"]) / 100.0; self.stamp = time.time()
                return {"percentage": 100.0 * self.position / TOTAL}
            if method == "Input.ExecuteAction":
                a = params.get("action")
                if a == "playpause": self.paused = not self.paused
                elif a == "mute": self.muted = not self.muted
                elif a == "stop": self.playing = False
                return "OK"
            if method == "Addons.GetAddons":
                kind = params.get("content")
                return {"addons": [{"addonid": a, "name": n, "summary": s, "thumbnail": "image://%s/" % a, "type": "xbmc.addon"}
                                   for a, n, s in ADDONS.get(kind, [])], "limits": {"start": 0, "end": 0, "total": 0}}
            if method in ("Input.Up", "Input.Down", "Input.Left", "Input.Right", "Input.Select", "Input.Back", "Input.Home",
                          "Input.SendText", "Addons.ExecuteAddon", "GUI.ActivateWindow"):
                return "OK"
            return None   # unknown method


def png(w, h, seed):
    """a flat-colour gradient PNG, colours picked from the seed"""
    d = hashlib.md5(seed.encode()).digest()
    a, b = d[0:3], d[3:6]
    rows = bytearray()
    for y in range(h):
        t = y / max(1, h - 1)
        rows.append(0)
        for x in range(w):
            rows += bytes(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    def chunk(k, body):
        c = struct.pack(">I", len(body)) + k + body
        return c + struct.pack(">I", zlib.crc32(k + body) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(rows))) + chunk(b"IEND", b"")


def make_handler(state):
    args = state.args

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def authorized(self):
            if not args.user:
                return True
            want = "Basic " + base64.b64encode(("%s:%s" % (args.user, args.password)).encode()).decode()
            if self.headers.get("Authorization") == want:
                return True
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Kodi"')
            self.send_header("Content-Length", "0")
            self.end_headers()
            return False

        def reply(self, code, body, ctype="application/json"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def answer(self, req):
            if isinstance(req, list):
                return json.dumps([self.answer_one(r) for r in req]).encode()
            return json.dumps(self.answer_one(req)).encode()

        def answer_one(self, req):
            result = state.rpc(req.get("method", ""), req.get("params") or {})
            if result is None:
                return {"jsonrpc": "2.0", "id": req.get("id"), "error": {"code": -32601, "message": "Method not found."}}
            return {"jsonrpc": "2.0", "id": req.get("id"), "result": result}

        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0)
            if self.path == "/mock/reset":
                state.reset(); return self.reply(200, b"{}")
            if self.path == "/mock/notify":
                e = json.loads(body); state.notify(e["method"], e.get("params", {})); return self.reply(200, b"{}")
            if not self.path.startswith("/jsonrpc"):
                return self.reply(404, b"not found", "text/plain")
            if not self.authorized():
                return
            try:
                req = json.loads(body)
            except ValueError:
                return self.reply(200, json.dumps({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error."}}).encode())
            self.reply(200, self.answer(req))

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/mock/log":
                return self.reply(200, json.dumps(state.log).encode())
            if not self.authorized():
                return
            if path.startswith("/image/"):
                return self.reply(200, png(160, 160, self.path), "image/png")
            if path == "/jsonrpc" and "?request=" in self.path:
                from urllib.parse import unquote
                return self.reply(200, self.answer(json.loads(unquote(self.path.split("?request=", 1)[1]))))
            self.reply(404, b"not found", "text/plain")

    return Handler


def serve_notifications(state, host, port):
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((host, port)); s.listen(5)
    def loop():
        while True:
            c, _ = s.accept()
            state.clients.append(c)
    threading.Thread(target=loop, daemon=True).start()


def main():
    ap = argparse.ArgumentParser(description="A stand-in for Kodi's JSON-RPC interfaces.")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8090, help="HTTP port (Kodi's own default is 8080)")
    ap.add_argument("--notify-port", type=int, default=9090, help="TCP notification port, 0 to disable (the app always uses 9090)")
    ap.add_argument("--user"); ap.add_argument("--password", default="")
    ap.add_argument("--split", action="store_true", help="send each notification in two TCP segments")
    args = ap.parse_args()
    state = State(args)
    if args.notify_port:
        serve_notifications(state, args.host, args.notify_port)
    httpd = ThreadingHTTPServer((args.host, args.port), make_handler(state))
    print("ready http://%s:%d notify=%s" % (args.host, args.port, args.notify_port or "off"), flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

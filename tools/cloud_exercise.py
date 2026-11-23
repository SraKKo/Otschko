"""Exercise 4 tests. All HTTP writes go only to a local mock bound to 127.0.0.1."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import threading
import time
from urllib.parse import urlparse, unquote
from pc_exercise import build
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports/cloud"

class State:
    def __init__(self):
        self.entries = {}
        self.gets = 0
        self.posts = 0
        self.successful_posts = 0
        self.conflicts = 0
        self.expected_versions = []
        self.delay_get = 0
        self.delay_post = 0
        self.lock = threading.Lock()

class MockHandler(BaseHTTPRequestHandler):
    def log_message(self, *_args): pass
    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def profile(self):
        parts = urlparse(self.path).path.strip("/").split("/")
        if len(parts) != 5 or parts[:3] != ["v1", "kv", "51796"] or parts[4] != "save":
            return None
        return unquote(parts[3])
    def do_GET(self):
        profile = self.profile()
        if profile is None: return self.reply(404, {"ok": False, "error": "bad_path"})
        state = self.server.state
        time.sleep(state.delay_get)
        with state.lock:
            state.gets += 1
            saved = state.entries.get(profile)
            body = {"ok": True, "found": saved is not None, **(saved or {"version": 0})}
        self.reply(200, body)
    def do_POST(self):
        size = int(self.headers.get("Content-Length", 0))
        if size > 16384: return self.reply(413, {"ok": False})
        body = json.loads(self.rfile.read(size) or b"{}")
        state = self.server.state
        if self.path == "/v1/_test":
            with state.lock:
                if "seed" in body:
                    item = body["seed"]
                    state.entries[item["profile"]] = {"value": item["value"], "version": item["version"], "updatedAt": 1700000000000 + item["version"] * 1000}
                if "delay_post" in body: state.delay_post = body["delay_post"]
                if "delay_get" in body: state.delay_get = body["delay_get"]
            return self.reply(200, {"ok": True})
        profile = self.profile()
        if profile is None: return self.reply(404, {"ok": False, "error": "bad_path"})
        time.sleep(state.delay_post)
        with state.lock:
            state.posts += 1
            state.expected_versions.append(body.get("expectedVersion"))
            previous = state.entries.get(profile, {"version": 0})
            if body.get("expectedVersion") != previous["version"]:
                state.conflicts += 1
                code, result = 409, {"ok": False, "error": "version_conflict", **previous}
            else:
                state.successful_posts += 1
                value = {"value": body["value"], "version": previous["version"] + 1, "updatedAt": 1700000000000 + (previous["version"] + 1) * 1000}
                state.entries[profile] = value
                code, result = 200, {"ok": True, **value}
        self.reply(code, result)

def verify(source=False):
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in (["source"] if source else ["debug"]):
        state = State()
        server = ThreadingHTTPServer(("127.0.0.1", 0), MockHandler)
        server.state = state
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        fixture = Path(tempfile.mkdtemp(prefix=kind + "-local-", dir=OUT))
        try:
            for phase in ("write", "read"):
                output = OUT / (kind + "-" + phase + "-checks.json")
                if output.exists(): output.unlink()
                cmd = ([str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"), "--path", str(ROOT)] if source else [str(ROOT / "builds" / ("windows-" + kind) / "Blackjack.exe")])
                cmd += ["--audio-driver", "Dummy", "--log-file", str(OUT / (kind + "-" + phase + "-godot.log")), "--", "--verify-cloud=" + phase, "--profiles-dir=" + str(fixture), "--cloud-api-url=http://127.0.0.1:" + str(server.server_port) + "/v1", "--cloud-output=" + str(output)]
                result = subprocess.run(cmd, capture_output=True, timeout=60)
                data = result.stdout + result.stderr
                log = OUT / (kind + "-" + phase + "-runtime.log")
                log.write_bytes(data)
                if result.returncode or b"ERROR:" in data or b"WARNING:" in data:
                    raise RuntimeError(f"{kind} {phase}: inspect {log}")
                checks = json.loads(output.read_text(encoding="utf-8"))
                if not checks["passed"]: raise RuntimeError("Cloud checks failed")
                print(kind, phase, "passed", len(checks["checks"]), "checks (localhost only)", flush=True)
            assert all(isinstance(v, int) and v >= 0 for v in state.expected_versions)
            (OUT / (kind + "-mock-requests.json")).write_text(json.dumps({"host":"127.0.0.1", "real_cloud_writes":0,"gets":state.gets,"post_attempts":state.posts,"successful_posts":state.successful_posts,"conflicts":state.conflicts,"expected_versions":state.expected_versions}, indent=2), encoding="utf-8")
            user = Path(os.environ["APPDATA"]) / "Godot/app_userdata/blackjack"
            for image in user.glob("cloud-*.png"):
                target = OUT / (kind + "-" + image.name)
                try: shutil.copy2(image, target)
                except OSError:
                    # A desktop image preview may hold an older PNG open on Windows.
                    shutil.copy2(image, OUT / (kind + "-" + str(time.time_ns()) + "-" + image.name))
        finally:
            server.shutdown()
            server.server_close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["source", "verify", "all"])
    parser.add_argument("--godot", default=str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"))
    args = parser.parse_args()
    if args.action == "all": build(args.godot)
    verify(source=args.action == "source")

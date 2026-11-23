"""Verify exercise 7 with an isolated profile directory and localhost HTTP."""
from http.server import ThreadingHTTPServer
from pathlib import Path
import json
import sys
import tempfile
import threading
from urllib.parse import parse_qs, unquote, urlsplit

from cloud_exercise import MockHandler
from pc_exercise import ROOT, REPORTS, build, run


class DrmHandler(MockHandler):
    def do_GET(self):
        url = urlsplit(self.path)
        if url.path == "/v1/license/51796/check":
            query = parse_qs(url.query)
            owner = self.server.licenses.get(query["license"][0])
            return self.reply(200, {"ok": True, "valid": owner == query["user"][0], "owner": owner})
        if url.path.endswith("/premium_chips"):
            name = unquote(url.path.split("/")[4])
            balance = self.server.balances.get(name)
            return self.reply(200, {"ok": True, "found": balance is not None, "value": str(balance or 0)})
        return self.reply(404, {"ok": False, "error": "bad_path"})

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.server.posts.append(self.path)
        if self.path == "/v1/license/51796/new":
            key = f"TEST-KEY-{len(self.server.licenses) + 1}"
            self.server.licenses[key] = None
            return self.reply(200, {"ok": True, "license": key})
        if self.path == "/v1/license/51796/activate":
            key = body["license"]
            if key not in self.server.licenses:
                return self.reply(404, {"ok": False, "error": "invalid_license"})
            if self.server.licenses[key] is not None:
                return self.reply(409, {"ok": False, "error": "already_activated"})
            self.server.licenses[key] = body["user"]
            return self.reply(200, {"ok": True})
        if self.path.endswith("/premium_chips/add"):
            amount = body["amount"]
            if abs(amount) > 100:
                return self.reply(422, {"ok": False, "error": "rejected"})
            name = unquote(self.path.split("/")[4])
            balance = self.server.balances.get(name, 0) + amount
            self.server.balances[name] = balance
            return self.reply(200, {"ok": True, "value": str(balance)})
        return self.reply(404, {"ok": False, "error": "bad_path"})


def main():
    godot = Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"
    if "--verify-only" not in sys.argv:
        build(godot)
        web = ROOT / "builds/web/index.html"
        web.parent.mkdir(exist_ok=True)
        run([godot, "--headless", "--path", ROOT, "--export-release", "Web", web], "07-export-web.log")
        for file in (web, web.with_suffix(".pck"), web.with_suffix(".wasm")):
            assert file.stat().st_size > 0, file

    with ThreadingHTTPServer(("127.0.0.1", 0), DrmHandler) as server:
        server.licenses, server.balances, server.posts = {}, {}, []
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory(prefix="drm-", dir=REPORTS) as profiles:
                for phase in ("write", "read"):
                    exe = ROOT / "builds/windows-debug/Blackjack.exe"
                    log = REPORTS / f"07-{phase}-godot.log"
                    run([exe, "--audio-driver", "Dummy", "--log-file", log, "--", "--verify-drm", f"--drm-phase={phase}",
                         f"--profiles-dir={profiles}", f"--drm-api-url=http://127.0.0.1:{server.server_port}/v1"],
                        f"07-{phase}-runtime.log", timeout=45)
                    output = log.read_text(encoding="utf-8")
                    assert "DRM_RESULT " in output and "0 failures" in output, output
                    assert "SCRIPT ERROR" not in output and "ERROR:" not in output, f"Inspect {log}"
                    print("\n".join(line for line in output.splitlines() if line.startswith("DRM ") or line.startswith("DRM_RESULT")), flush=True)
        finally:
            server.shutdown()
        assert server.balances == {"Ala": 50}
        assert len(server.posts) == 5, server.posts


if __name__ == "__main__":
    main()

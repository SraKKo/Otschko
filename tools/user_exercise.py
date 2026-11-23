"""Exercise 3: isolated local-profile tests, including separate process restarts."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pc_exercise import build
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports/users"

def verify(source=False):
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in (["source"] if source else ["debug"]):
        fixture = Path(tempfile.mkdtemp(prefix=kind + "-profiles-", dir=OUT))
        for phase in ("write", "read"):
            result_path = OUT / (kind + "-" + phase + "-checks.json")
            if result_path.exists(): result_path.unlink()
            command = ([str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"), "--path", str(ROOT)] if source else [str(ROOT / "builds" / ("windows-" + kind) / "Blackjack.exe")])
            command += ["--log-file", str(OUT / (kind + "-" + phase + "-godot.log")), "--", "--verify-users=" + phase, "--profiles-dir=" + str(fixture), "--user-output=" + str(result_path)]
            result = subprocess.run(command, capture_output=True, timeout=45)
            data = result.stdout + result.stderr
            (OUT / (kind + "-" + phase + "-runtime.log")).write_bytes(data)
            if result.returncode or b"ERROR:" in data or b"WARNING:" in data:
                raise RuntimeError(kind + " " + phase + ": inspect " + str(OUT / (kind + "-" + phase + "-runtime.log")))
            checks = json.loads(result_path.read_text(encoding="utf-8"))
            if not checks["passed"] or not checks["checks"]: raise RuntimeError("User checks did not pass")
            print(kind, phase, "passed", len(checks["checks"]), "checks", flush=True)
        user = Path(os.environ["APPDATA"]) / "Godot/app_userdata/blackjack"
        for image in user.glob("users-*.png"): shutil.copy2(image, OUT / image.name)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["verify", "source", "all"])
    parser.add_argument("--godot", default=str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"))
    args = parser.parse_args()
    if args.action == "all": build(args.godot)
    verify(source=args.action == "source")

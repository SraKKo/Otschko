"""Exercise 2 controller integration checks for exported Windows builds."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
from pc_exercise import build

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports/controllers"

def verify():
    OUT.mkdir(parents=True, exist_ok=True)
    cfg = Path(os.environ["APPDATA"]) / "Godot/app_userdata/blackjack/settings.cfg"
    backup = cfg.read_bytes() if cfg.exists() else None
    try:
        for kind in ("debug", "release"):
            result_path = OUT / (kind + "-checks.json")
            if result_path.exists(): result_path.unlink()
            result = subprocess.run([str(ROOT / "builds" / ("windows-" + kind) / "Blackjack.exe"), "--log-file", str(OUT / (kind + "-godot.log")), "--", "--verify-controllers", "--controller-output=" + str(result_path)], capture_output=True, timeout=45)
            data = result.stdout + result.stderr
            (OUT / (kind + "-runtime.log")).write_bytes(data)
            if result.returncode or b"ERROR:" in data or b"WARNING:" in data:
                raise RuntimeError(kind + ": inspect " + str(OUT / (kind + "-runtime.log")))
            checks = json.loads(result_path.read_text(encoding="utf-8"))
            if not checks["passed"] or not checks["checks"]:
                raise RuntimeError(kind + ": integration checks failed")
            if (b"[DEV]" in data) != (kind == "debug"):
                raise RuntimeError("Unexpected diagnostic output")
            print(kind, "passed", len(checks["checks"]), "checks; physical controllers:", checks["physical_controllers"], flush=True)
        for image in cfg.parent.glob("controller-*.png"):
            shutil.copy2(image, OUT / image.name)
    finally:
        if backup is not None: cfg.write_bytes(backup)
        elif cfg.exists(): cfg.unlink()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["verify", "all"])
    parser.add_argument("--godot", default=str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"))
    args = parser.parse_args()
    if args.action == "all": build(args.godot)
    verify()

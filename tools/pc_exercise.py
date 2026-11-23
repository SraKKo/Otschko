"""Build and benchmark the Windows PC exercise. Python standard library only."""
import argparse
import json
import os
from pathlib import Path
import shutil
from check_localization import check as check_localization
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"

def run(command, log, timeout=180):
    result = subprocess.run([str(v) for v in command], capture_output=True, timeout=timeout)
    data = result.stdout + result.stderr
    (REPORTS / log).write_bytes(data)
    if result.returncode or b"SCRIPT ERROR" in data or b"Parse Error" in data:
        raise RuntimeError(f"Failed: {log} (exit {result.returncode})")
    return data

def build(godot):
    check_localization()
    for kind in ("debug", "release"):
        target = ROOT / "builds" / ("windows-" + kind) / "Blackjack.exe"
        target.parent.mkdir(parents=True, exist_ok=True)
        run([godot, "--headless", "--path", ROOT, "--export-" + kind, "Otshcko! V0.4", target], "export-" + kind + ".log")
        if not target.exists():
            raise RuntimeError(f"Missing export: {target}")
        print("Built", kind, flush=True)

def verify():
    user = Path(os.environ["APPDATA"]) / "Godot/app_userdata/blackjack"
    cfg = user / "settings.cfg"
    backup = cfg.read_bytes() if cfg.exists() else None
    try:
        for phase in ("write", "read"):
            data = run([ROOT / "builds/windows-release/Blackjack.exe", "--log-file", REPORTS / ("settings-" + phase + "-godot.log"), "--", "--pc-verify-settings=" + phase], "settings-" + phase + ".log", 40)
            if ("SETTINGS_CHECK_OK: " + phase).encode() not in data:
                raise RuntimeError("Settings check did not complete")
        for name in ("settings-crt-on.png", "settings-crt-off.png"):
            shutil.copy2(user / name, REPORTS / name)
    finally:
        if backup is not None:
            cfg.write_bytes(backup)
        elif cfg.exists():
            cfg.unlink()
    print("Settings and CRT persistence passed", flush=True)

def benchmark():
    results = {}
    for kind in ("debug", "release"):
        result_path = REPORTS / ("benchmark-" + kind + ".json")
        if result_path.exists():
            result_path.unlink()
        data = run([ROOT / "builds" / ("windows-" + kind) / "Blackjack.exe", "--log-file", REPORTS / (kind + "-godot.log"), "--", "--pc-benchmark", "--benchmark-output=" + str(result_path)], kind + "-runtime.log", 70)
        results[kind] = json.loads(result_path.read_text(encoding="utf-8"))
        if results[kind]["build"] != kind or results[kind]["duration_seconds"] < 30:
            raise RuntimeError("Invalid benchmark duration/build")
        if results[kind]["rendered_frames"] < results[kind]["frames"] * 0.95:
            raise RuntimeError("Window did not render the measured frames")
        if results[kind]["vsync"] != 0 or results[kind]["fps_limit"] != 0:
            raise RuntimeError("Frame limiting is enabled")
        if (b"[DEV]" in data) != (kind == "debug"):
            raise RuntimeError("Unexpected diagnostic logs")
        if b"ERROR:" in data or b"WARNING:" in data:
            raise RuntimeError("Inspect runtime log: " + kind)
        print(kind, results[kind]["average_fps"], flush=True)
    d, r = results["debug"], results["release"]
    for field in ("scene", "window_size", "renderer", "crt", "seed", "cpu", "gpu"):
        if d[field] != r[field]:
            raise RuntimeError("Workload differs: " + field)
    difference = (r["average_fps"] - d["average_fps"]) / d["average_fps"] * 100
    comparison = {"debug": d, "release": r, "difference_percent": difference}
    (REPORTS / "comparison.json").write_text(json.dumps(comparison, indent=2, ensure_ascii=False), encoding="utf-8")
    sentence = f'Przy wyłączonym VSync i limicie FPS, w tej samej scenie GameProper (1280 x 720, CRT włączony), przez 30 s po 5 s rozgrzewki zmierzono średnio {d["average_fps"]:.2f} FPS w debug i {r["average_fps"]:.2f} FPS w release, co daje zmianę {(difference):+.2f}% względem debug.'
    (REPORTS / "wynik_pomiaru.txt").write_text(sentence + "\n", encoding="utf-8")
    print(sentence)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["build", "verify", "benchmark", "all"])
    parser.add_argument("--godot", default=shutil.which("godot") or str(Path.home() / "Desktop/Godot_v4.5.1-stable_win64.exe"))
    args = parser.parse_args()
    REPORTS.mkdir(exist_ok=True)
    if args.action in ("build", "all"):
        build(args.godot)
    if args.action in ("verify", "all"):
        verify()
    if args.action in ("benchmark", "all"):
        benchmark()

"""Run localization checks with isolated game settings and profiles."""
from pathlib import Path
import tempfile

from pc_exercise import ROOT, REPORTS, run


def main():
    game = ROOT / "builds/windows-debug/Blackjack.exe"
    with tempfile.TemporaryDirectory(prefix="locale-", dir=REPORTS) as directory:
        fixture = Path(directory)
        for phase in ("write", "read", "pseudo"):
            config = fixture / ("pseudo.cfg" if phase == "pseudo" else "settings.cfg")
            log = REPORTS / f"09-{phase}-godot.log"
            command = [
                game, "--audio-driver", "Dummy", "--log-file", log, "--",
                f"--verify-localization={phase}", f"--settings-file={config}",
                f"--profiles-dir={fixture / 'profiles'}", f"--locale-reports={REPORTS}",
            ]
            if phase == "pseudo":
                command.append("--pseudo-locale")
            run(command, f"09-{phase}-runtime.log", timeout=45)
            messages = log.read_text(encoding="utf-8")
            if f"LOCALIZATION_OK: {phase}" not in messages or "SCRIPT ERROR" in messages or "ERROR:" in messages:
                raise RuntimeError(f"Inspect {log}")
            print(next(line for line in messages.splitlines() if line.startswith("LOCALIZATION_OK:")), flush=True)


if __name__ == "__main__":
    main()

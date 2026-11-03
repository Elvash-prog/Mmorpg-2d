"""Run meaningful checks with timeouts and preserve failures, including Godot script errors."""
from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which("godot") or shutil.which("godot4")
if GODOT is None:
    raise SystemExit("Godot 4.6.3 não encontrado no PATH")
checks = [
    ("tools/validate_content.gd", "CONTENT_PASS"),
    ("tests/combat_test.gd", "COMBAT_PASS"),
    ("tests/ui_test.gd", "UI_PASS"),
    ("tests/realms_test.gd", "REALMS_PASS"),
    ("tests/architecture_test.gd", "ARCHITECTURE_PASS"),
]
for script, marker in checks:
    try:
        run = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--script", script],
                             capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired as exc:
        print(f"FAIL: {script} excedeu 20 s", file=sys.stderr)
        for output in (exc.stdout, exc.stderr):
            if output:
                print(output.decode(errors="replace") if isinstance(output, bytes) else output,
                      file=sys.stderr)
        raise SystemExit(1)
    output = run.stdout + run.stderr
    print(output, end="")
    if run.returncode != 0 or marker not in output or "ERROR:" in output:
        raise SystemExit(run.returncode or 1)
if "--network" in sys.argv:
    run = subprocess.run([sys.executable, str(ROOT / "tests/network_smoke.py")])
    if run.returncode:
        raise SystemExit(run.returncode)
print("CHECKS_PASS: content, gameplay, interface, realms and architecture" + (", network" if "--network" in sys.argv else ""))

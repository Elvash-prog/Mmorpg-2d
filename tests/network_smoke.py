"""Launch actual local ENet peers and verify the replicated gameplay contract."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which("godot") or shutil.which("godot4")
if not GODOT:
    raise SystemExit("Godot 4.6.3 não encontrado no PATH")
BASE = [GODOT, "--headless", "--path", str(ROOT), "--"]
with tempfile.TemporaryFile(mode="w+t") as log:
    server = subprocess.Popen(BASE + ["--server", "--smoke-host"], stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            log.seek(0)
            output = log.read()
            if "SERVER_READY" in output:
                break
            if server.poll() is not None:
                raise RuntimeError("Servidor encerrou durante startup:\n" + output)
            time.sleep(0.05)
        else:
            raise RuntimeError("Servidor não ficou pronto:\n" + output)
        client = subprocess.run(BASE + ["--smoke-client"], capture_output=True, text=True, timeout=18)
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
    log.seek(0)
    output = log.read() + client.stdout + client.stderr
    print(output)
    assert client.returncode == 0, "Cliente não concluiu o teste"
    assert "NETWORK_CLIENT_PASS" in output and "NETWORK_HOST_PASS" in output
    assert "ERROR:" not in output and "MTU" not in output
print("NETWORK_PASS: real peers, compressed state, class change, special skill and quests")

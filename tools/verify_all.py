#!/usr/bin/env python3
"""Run every check in one go (needs the ROM in orig/ and RGBDS; the C steps need a compiler):

    python tools/verify_all.py [--rgbds DIR] [--cc COMPILER] [--frames N]

1. RGBDS build is byte-identical to the original      2. the reference assembler reproduces every byte from src/
3. dynamic coverage: nothing executes outside the static trace (needs Pillow-free emu.py, ~1 minute)
4. native build: recompile, compile, stress with random input (several seeds), no fatal errors
"""
import argparse, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("--rgbds", default=os.environ.get("RGBDS_DIR", ""))
ap.add_argument("--cc", default=os.environ.get("CC", ""))
ap.add_argument("--frames", type=int, default=6000)
ap.add_argument("--seeds", type=int, default=3)
a = ap.parse_args()
py = sys.executable
fails = []


def run(title, cmd, ok=lambda r: r.returncode == 0):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    good = ok(r)
    last = (r.stdout.strip().splitlines() or r.stderr.strip().splitlines() or [""])[-1]
    print(("PASS " if good else "FAIL ") + title + (": " + last if last else ""))
    if not good:
        fails.append(title)
    return r


run("RGBDS build matches the original", [py, "tools/build.py"] + (["--rgbds", a.rgbds] if a.rgbds else []))
run("reference assembler round trip", [py, "tools/gb_dis.py", "--check"])
run("emulator coverage inside the static trace", [py, "tools/coverage.py", "--frames", "1500"],
    ok=lambda r: r.returncode == 0 and " 0 not in the static trace" in r.stdout)
if a.cc:
    run("recompile and build the native runner", [py, "tools/build_port.py", "--cc", a.cc])
    exe = os.path.join(ROOT, "build", "recomp", "game_headless" + (".exe" if os.name == "nt" else ""))
    for seed in range(1, a.seeds + 1):
        run(f"native stress run, seed {seed}", [exe, "-", str(a.frames), "--press",
                                                "250:start:3", "--random", str(seed)])
else:
    print("SKIP native build (pass --cc)")
print("ALL PASSED" if not fails else "FAILED: " + ", ".join(fails))
sys.exit(1 if fails else 0)

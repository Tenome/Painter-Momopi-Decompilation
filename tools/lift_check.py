#!/usr/bin/env python3
"""Check the hand written routines of port/logic.c against the generated code, frame by frame.

    python tools/lift_check.py --rgbds E:/rgbds --cc clang [--frames 6000] [--seeds 4]

Builds the headless runner twice: once with the labels that port/logic.c defines taken out of port/overrides.txt (generated code for them) and once
as the port is built, then plays random input with several seeds and compares the hash of work RAM, high RAM, video RAM and OAM after every frame.
"""
import argparse, os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("--rgbds", default=os.environ.get("RGBDS_DIR", ""))
ap.add_argument("--cc", required=True)
ap.add_argument("--frames", type=int, default=6000)
ap.add_argument("--seeds", type=int, default=4)
ap.add_argument("--rounds", default="1,5,9,13,17,21,25,29", help="rounds to force in extra runs of 2500 frames (empty for none)")
a = ap.parse_args()
exe = ".exe" if os.name == "nt" else ""
ov = os.path.join(ROOT, "port", "overrides.txt")
logic = open(os.path.join(ROOT, "port", "logic.c"), encoding="utf-8").read()
lifted = set(re.findall(r"gb_native_(\w+)\(void\)", logic))
full = open(ov).read()
out = os.path.join(ROOT, "build", "recomp", "game_headless" + exe)
tmp = tempfile.mkdtemp()


def build():
    cmd = [sys.executable, os.path.join(ROOT, "tools", "build_port.py"), "--cc", a.cc]
    if a.rgbds:
        cmd += ["--rgbds", a.rgbds]
    subprocess.run(cmd, check=True, cwd=ROOT, stdout=subprocess.DEVNULL)


try:
    open(ov, "w", newline="\n").write("".join(ln for ln in full.splitlines(True) if ln.strip() not in lifted))
    build()
    base = os.path.join(tmp, "base" + exe)
    shutil.copy(out, base)
finally:
    open(ov, "w", newline="\n").write(full)
build()
bad = 0
for s in range(1, a.seeds + 1):
    h = []
    for name, prog in (("base", base), ("lifted", out)):
        p = os.path.join(tmp, f"{name}{s}.txt")
        subprocess.run([prog, "-", str(a.frames), "--press", "250:start:3", "--random", str(s), "--hashes", p], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        h.append(open(p).read())
    ok = h[0] == h[1]
    bad += not ok
    first = next((i for i, (x, y) in enumerate(zip(h[0].splitlines(), h[1].splitlines())) if x != y), None)
    print(f"seed {s}: {'same' if ok else 'DIFFERENT from frame ' + str(first)} ({len({x.split()[1] for x in h[0].splitlines()})} distinct frames)")
for rnd in [x for x in a.rounds.split(",") if x]:
    h = []
    for name, prog in (("base", base), ("lifted", out)):
        p = os.path.join(tmp, f"{name}_r{rnd}.txt")
        subprocess.run([prog, "-", "2500", "--press", "250:start:3", "--random", rnd, "--round", rnd, "--hashes", p], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        h.append(open(p).read())
    ok = h[0] == h[1]
    bad += not ok
    print(f"round {rnd}: {'same' if ok else 'DIFFERENT'}")
print(f"{len(lifted)} lifted routines:", ", ".join(sorted(lifted)))
sys.exit(1 if bad else 0)

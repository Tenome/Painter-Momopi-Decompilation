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
ap.add_argument("--keep", action="store_true", help="keep the two runners in build/lift_check/ for debugging")
ap.add_argument("--rounds", default=",".join(str(i) for i in range(1, 33)), help="rounds to force in extra runs of 2500 frames (empty for none)")
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
    if a.keep:
        os.makedirs(os.path.join(ROOT, "build", "lift_check"), exist_ok=True)
        shutil.copy(out, os.path.join(ROOT, "build", "lift_check", "base" + exe))
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
    first = next((i for i, (x, y) in enumerate(zip(h[0].splitlines(), h[1].splitlines())) if x != y), None)
    print(f"round {rnd}: {'same' if ok else 'DIFFERENT from frame ' + str(first)}")
if a.keep:
    shutil.copy(out, os.path.join(ROOT, "build", "lift_check", "lifted" + exe))
# the magic screen needs cards: a run with all nine cards and plenty of magic points, several rounds and seeds
cards = []
for k in range(9):
    cards += ["--poke", f"254:{0xC43E + k:x}:{k + 1}"]
cards += ["--poke", f"254:{0xC44A:x}:250", "--poke", f"254:{0xC44B:x}:1"]
for rnd in ("1", "9", "17", "25"):
    for seed in ("3", "7"):
        h = []
        for name, prog in (("base", base), ("lifted", out)):
            p = os.path.join(tmp, f"{name}_cards{rnd}_{seed}.txt")
            subprocess.run([prog, "-", "4000", "--press", "250:start:3", "--random", seed, "--round", rnd, "--hashes", p] + cards, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            h.append(open(p).read())
        ok = h[0] == h[1]
        bad += not ok
        first = next((i for i, (x, y) in enumerate(zip(h[0].splitlines(), h[1].splitlines())) if x != y), None)
        print(f"cards, round {rnd}, seed {seed}: {'same' if ok else 'DIFFERENT from frame ' + str(first)}")
# every card selected from the start (wActiveMagic) with plenty of magic points: the random A presses cast it
for card in range(1, 10):
    for seed in ("5", "11"):
        h = []
        for name, prog in (("base", base), ("lifted", out)):
            p = os.path.join(tmp, f"{name}_card{card}_{seed}.txt")
            subprocess.run([prog, "-", "3000", "--press", "250:start:3", "--random", seed, "--round", str(card * 3), "--hashes", p,
                            "--poke", f"254:{0xC447:x}:{card}", "--poke", f"254:{0xC44A:x}:250", "--poke", f"254:{0xC44B:x}:1"], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            h.append(open(p).read())
        ok = h[0] == h[1]
        bad += not ok
        first = next((i for i, (x, y) in enumerate(zip(h[0].splitlines(), h[1].splitlines())) if x != y), None)
        print(f"card {card} selected, seed {seed}: {'same' if ok else 'DIFFERENT from frame ' + str(first)}")
# a round that is nearly painted: the last cells are painted by the random walk, so RoundCleared, NextRound and the next screens run
for rnd in ("1", "3", "7", "11", "20", "28", "32", "33", "19", "23", "27"):
    h = []
    for name, prog in (("base", base), ("lifted", out)):
        p = os.path.join(tmp, f"{name}_clear{rnd}.txt")
        subprocess.run([prog, "-", "5000", "--press", "250:start:3", "--random", "9", "--round", rnd, "--hashes", p,
                        "--poke", f"600:{0xC520:x}:3"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        h.append(open(p).read())
    ok = h[0] == h[1]
    bad += not ok
    first = next((i for i, (x, y) in enumerate(zip(h[0].splitlines(), h[1].splitlines())) if x != y), None)
    print(f"nearly painted, round {rnd}: {'same' if ok else 'DIFFERENT from frame ' + str(first)}")
print(f"{len(lifted)} lifted routines:", ", ".join(sorted(lifted)))
sys.exit(1 if bad else 0)

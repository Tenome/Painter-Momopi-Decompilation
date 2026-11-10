#!/usr/bin/env python3
"""Check a level pack: python tools/pack_check.py pack.pmpack [--play] [--frames 3000]

1. the static checks of the level editor (map, enemies, sizes) plus: every path cell must be reachable from the player's start cell
2. with --play (needs build/recomp/game_headless from tools/build_port.py): every level is started in the native runner with random buttons; the report says
   whether it runs for the given frames without a crash or a hang, and whether the random walk cleared it (with only 3 cells left to paint, so the
   clear, the next round and the screens in between are exercised). Exit status 1 when a problem was found."""
import argparse, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import levelpack as lp
import enemy_icons

ap = argparse.ArgumentParser()
ap.add_argument("pack")
ap.add_argument("--play", action="store_true")
ap.add_argument("--frames", type=int, default=4000)
a = ap.parse_args()

pack = lp.load(a.pack)
bad = 0
warn = lp.problems(pack)
for w in warn:
    print("WARNING", w)
bad += len(warn)
print("%d levels, %d warnings" % (len(pack.levels), len(warn)))
if a.play:
    prog = enemy_icons.runner()
    if not prog:
        sys.exit("game_headless is not built: python tools/build_port.py")
    with tempfile.TemporaryDirectory() as tmp:
        ini = os.path.join(tmp, "check.ini")
        with open(ini, "w") as f:
            f.write("[game]\nlevel_pack=%s\n" % os.path.abspath(a.pack))
        for i, lv in enumerate(pack.levels, 1):
            dump = os.path.join(tmp, "d%d.bin" % i)
            cmd = [prog, "-", str(a.frames), "--ini", ini, "--press", "250:start:3", "--random", str(i), "--round", str(i), "--poke", "600:c520:3", "--dump", str(a.frames - 5), dump]
            try:
                r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)
            except subprocess.TimeoutExpired:
                print("Level %d (%s): the runner did not finish (hang)" % (i, lv.name))
                bad += 1
                continue
            if r.returncode != 0 or not os.path.exists(dump):
                print("Level %d (%s): the runner failed (exit %d)" % (i, lv.name, r.returncode))
                bad += 1
                continue
            rnd = open(dump, "rb").read()[0xC522 - 0xC000]
            print("Level %d (%s): ran %d frames; %s" % (i, lv.name, a.frames, "cleared by the random walk" if rnd > i else "not cleared by the random walk (it may just be a hard level)"))
sys.exit(1 if bad else 0)

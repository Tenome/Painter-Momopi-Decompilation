#!/usr/bin/env python3
"""Play the ROM headless with scripted/random input and report instructions that executed but are not in the static trace.

    python tools/coverage.py [--frames N] [--write-seeds]     appends new entry points to seeds.csv (bank,addr,comment)
"""
import argparse, os, random, sys
sys.path.insert(0, os.path.dirname(__file__))
import emu, gb_dis

ap = argparse.ArgumentParser()
ap.add_argument("--frames", type=int, default=3000)
ap.add_argument("--write-seeds", action="store_true")
a = ap.parse_args()
rom = gb_dis.Rom(os.path.join(gb_dis.ROOT, "orig", "painter_momopie.gb"))
rom.trace()
cov = set()
raw = open(os.path.join(gb_dis.ROOT, "orig", "painter_momopie.gb"), "rb").read()


def session(seed, modes_to_force=(), frames=a.frames):
    random.seed(seed)
    gb = emu.GB(raw)
    gb.coverage = cov
    j = 0
    for fr in range(frames):
        if fr < 250:
            gb.joy = 0
        elif fr < 253:
            gb.joy = 0x80
        else:
            if fr % random.choice((20, 40, 60)) == 0:
                j = random.choice((0, 1, 2, 4, 8, 1, 2, 4, 8, 0x10, 0x20, 0x80))
            gb.joy = j
        if fr in modes_to_force:
            gb.a = modes_to_force[fr]
            gb.pc = 0x01AD
            gb.sp = 0xDFFF
            gb.ime = False
        try:
            gb.run_frame()
        except RuntimeError:
            break


for seed in range(6):
    session(seed)
for m in range(8):
    session(100 + m, {400: m}, 1500)
known = set(rom.insns)
new = sorted(x for x in cov if x not in known and x[0] < 2 and x[1] < 0x8000)
print(f"executed {len(cov)} distinct instruction addresses; {len(new)} not in the static trace")
for b, ad in new[:60]:
    print(f"  {b}:{ad:04x}")
if a.write_seeds and new:
    path = os.path.join(gb_dis.ROOT, "seeds.csv")
    have = {(int(r[0]), int(r[1], 16)) for r in gb_dis.read_csv(path) if r[0] != "bank"}
    # only routine entry candidates: the first address of each contiguous run of new addresses
    # instruction lengths vary, so only take addresses whose predecessor instruction does not run into them
    starts = [x for i, x in enumerate(new) if i == 0 or new[i - 1][0] != x[0] or x[1] - new[i - 1][1] > 3]
    with open(path, "a", newline="\n") as f:
        for b, ad in starts:
            if (b, ad) not in have:
                f.write(f"{b},{ad:04x},executed in the emulator\n")
    print("seeds appended:", len(starts))

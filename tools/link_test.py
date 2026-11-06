#!/usr/bin/env python3
"""Run two emulated Game Boys connected by a link cable (emu.GB.partner) and start a 2 player game.

    python tools/link_test.py [--frames N] [--shot out.png]

Machine A presses Start on the title screen with 2 PLAYER selected; both end up in the same randomly chosen round with hLinkFlags bit 0 set.
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import emu

ap = argparse.ArgumentParser()
ap.add_argument("--frames", type=int, default=600)
ap.add_argument("--shot")
a = ap.parse_args()
raw = open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "orig", "painter_momopie.gb"), "rb").read()
A, B = emu.GB(raw), emu.GB(raw)
A.partner, B.partner = B, A


def step(ja, jb):
    A.joy, B.joy = ja, jb
    A.run_frame()
    B.run_frame()


for _ in range(300):
    step(0, 0)
for _ in range(6):
    step(0x40, 0x40)           # Select: cursor to 2 PLAYER on both
for _ in range(20):
    step(0, 0)
for _ in range(8):
    step(0x80, 0)              # Start on machine A
for _ in range(a.frames):
    step(0, 0)
print("hLinkFlags A/B: %02x %02x   hSerialByte A/B: %02x %02x   round A/B: %d %d" % (
    A.hram[0x6D], B.hram[0x6D], A.hram[0x6B], B.hram[0x6B], A.wram[0x522], B.wram[0x522]))
if a.shot:
    from PIL import Image
    sh = (255, 170, 85, 0)
    sheet = Image.new("L", (320, 144))
    for k, g in enumerate((A, B)):
        im = Image.new("L", (160, 144))
        im.putdata([sh[v] for row in g.render() for v in row])
        sheet.paste(im, (k * 160, 0))
    sheet.save(a.shot)

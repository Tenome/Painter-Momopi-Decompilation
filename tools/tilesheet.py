#!/usr/bin/env python3
"""Render ROM bytes as a sheet of 2bpp Game Boy tiles (16 tiles per row) to a PNG (Pillow).

    python tools/tilesheet.py BANK START LENGTH out.png [--scale 2]     START is a CPU address ($4000-$7fff) in BANK
"""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bank, start, length, out = int(sys.argv[1]), int(sys.argv[2], 0), int(sys.argv[3], 0), sys.argv[4]
scale = int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 2
rom = open(os.path.join(ROOT, "orig", "painter_momopie.gb"), "rb").read()
base = bank * 0x4000 + (start - 0x4000 if bank else start)
n = length // 16
w = 16
h = (n + w - 1) // w
im = Image.new("L", (w * 8, h * 8), 255)
px = im.load()
shades = (255, 170, 85, 0)
for t in range(n):
    for y in range(8):
        lo, hi = rom[base + t * 16 + y * 2], rom[base + t * 16 + y * 2 + 1]
        for x in range(8):
            px[(t % w) * 8 + x, (t // w) * 8 + y] = shades[((hi >> (7 - x)) & 1) << 1 | ((lo >> (7 - x)) & 1)]
if scale > 1:
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
im.save(out)
print(f"{n} tiles -> {out}")

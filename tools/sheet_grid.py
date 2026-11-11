#!/usr/bin/env python3
"""A labelled copy of a texture sheet, to find tile numbers: python tools/sheet_grid.py SHEET.png [--out grid.png]

Draws the column (0-F) and row (0_-F_) of every tile around the sheet and grid lines between the tiles: tile number = row * 16 + column. Sprites on a transparent
background are shown on white. Needs Pillow; the sheets come from tools/export_textures.py or build/recomp/textures/ (your own game data: keep the result out of git)."""
import argparse
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("sheet")
ap.add_argument("--out", default="grid.png")
a = ap.parse_args()
im = Image.open(a.sheet).convert("RGBA")
n = im.width // 128
bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
bg.alpha_composite(im)
im = bg.convert("RGB")
s = 8 * n
big = Image.new("RGB", (im.width + 40, im.height + 14), (255, 255, 255))
big.paste(im, (40, 14))
d = ImageDraw.Draw(big)
for c in range(16):
    d.text((40 + c * s + s // 2 - 4, 1), "%X" % c, fill=(200, 0, 0))
for r in range(im.height // s):
    d.text((6, 14 + r * s + s // 2 - 5), "%X_" % r, fill=(200, 0, 0))
for x in range(0, im.width + 1, s):
    d.line([(40 + x, 14), (40 + x, 14 + im.height)], fill=(220, 220, 255))
for y in range(0, im.height + 1, s):
    d.line([(40, 14 + y), (40 + im.width, 14 + y)], fill=(220, 220, 255))
big.save(a.out)
print("wrote", a.out)

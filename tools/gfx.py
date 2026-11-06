#!/usr/bin/env python3
"""Convert the 2bpp tile assets listed in gfx.csv to editable PNG sheets and back.

    python tools/gfx.py png     assets/bank_BB/AAAA_Name.bin -> assets/gfx/B_AAAA_Name.png   (16 tiles per row, 4 grey shades)
    python tools/gfx.py bin     assets/gfx/*.png            -> assets/bank_BB/AAAA_Name.bin   (the build runs this first)

Shades: index 0 = white (255), 1 = light grey (170), 2 = dark grey (85), 3 = black (0). Edit the PNGs (keep the size and the four grey values); the
ROM is rebuilt from them. A PNG that is not 8-pixel aligned is rejected.
"""
import csv, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADES = (255, 170, 85, 0)
PER_ROW = 16


def entries():
    with open(os.path.join(ROOT, "gfx.csv"), encoding="utf-8") as f:
        for r in csv.reader(l for l in f if l.strip() and not l.startswith("#")):
            if r[0] == "bank":
                continue
            yield int(r[0]), r[1], r[2]


def bin_path(bank, addr, name):
    return os.path.join(ROOT, "assets", f"bank_{bank:02x}", f"{addr}_{name}.bin")


def png_path(bank, addr, name):
    return os.path.join(ROOT, "assets", "gfx", f"{bank}_{addr}_{name}.png")


def to_png(data):
    n = len(data) // 16
    rows = (n + PER_ROW - 1) // PER_ROW
    im = Image.new("L", (PER_ROW * 8, rows * 8), 255)
    px = im.load()
    for t in range(n):
        for y in range(8):
            lo, hi = data[t * 16 + y * 2], data[t * 16 + y * 2 + 1]
            for x in range(8):
                px[(t % PER_ROW) * 8 + x, (t // PER_ROW) * 8 + y] = SHADES[((hi >> (7 - x)) & 1) << 1 | ((lo >> (7 - x)) & 1)]
    return im


def to_bin(im, ntiles):
    im = im.convert("L")
    if im.width != PER_ROW * 8 or im.height % 8:
        raise SystemExit(f"PNG must be {PER_ROW * 8} pixels wide with a height that is a multiple of 8 (got {im.size})")
    px = im.load()
    out = bytearray()
    for t in range(ntiles):
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                v = px[(t % PER_ROW) * 8 + x, (t // PER_ROW) * 8 + y]
                idx = min(range(4), key=lambda i: abs(SHADES[i] - v))
                lo |= (idx & 1) << (7 - x)
                hi |= (idx >> 1) << (7 - x)
            out += bytes([lo, hi])
    return bytes(out)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "png":
        os.makedirs(os.path.join(ROOT, "assets", "gfx"), exist_ok=True)
        for b, a, n in entries():
            to_png(open(bin_path(b, a, n), "rb").read()).save(png_path(b, a, n))
        print("wrote PNG sheets to assets/gfx/")
    elif cmd == "bin":
        done = 0
        for b, a, n in entries():
            p = png_path(b, a, n)
            if not os.path.exists(p):
                continue
            target = bin_path(b, a, n)
            ntiles = os.path.getsize(target) // 16
            data = to_bin(Image.open(p), ntiles)
            if data != open(target, "rb").read():
                open(target, "wb").write(data)
                print("updated", os.path.relpath(target, ROOT))
            done += 1
        print(done, "PNG sheets checked")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()

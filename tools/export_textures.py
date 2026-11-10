#!/usr/bin/env python3
"""Write the texture pack template: textures/<bank>_<addr>_<name>.png for every tile sheet, enlarged N times (default 4) with the plain Game Boy greys.

    python tools/export_textures.py [--scale N] [--out textures]

Paint over the sheets in any editor with full colour (and transparency for sprites). Keep the file names and the size (128*N pixels wide, 16 tiles per row).
The native player (game_win.exe) loads the folder named by `texture_pack` in painter_momopie.ini and replaces every tile that you changed; untouched tiles
keep the Game Boy look. See docs/TEXTURES.md.
"""
import os, shutil, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    args = sys.argv[1:]
    scale = int(args[args.index("--scale") + 1]) if "--scale" in args else 4
    out = args[args.index("--out") + 1] if "--out" in args else os.path.join(ROOT, "textures")
    if not 1 <= scale <= 8:
        raise SystemExit("--scale must be 1-8")
    src = os.path.join(ROOT, "assets", "gfx")
    if not os.path.isdir(src):
        raise SystemExit("assets/gfx is missing: run python tools/gb_dis.py --write first (needs your ROM)")
    os.makedirs(out, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(src)):
        if name.endswith(".png"):
            im = Image.open(os.path.join(src, name)).convert("RGB")
            im.resize((im.width * scale, im.height * scale), Image.NEAREST).save(os.path.join(out, name))
            n += 1
    note = os.path.join(ROOT, "port", "textures_readme.ini")
    if os.path.exists(note):
        shutil.copy(note, os.path.join(out, "README.ini"))
    print(f"{n} sheets written to {out} ({scale}x)")


if __name__ == "__main__":
    main()

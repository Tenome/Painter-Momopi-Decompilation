#!/usr/bin/env python3
"""Make an example texture pack with a recoloured player: python tools/make_example_player.py [--out textures_example]

Takes the exported sheets (build/recomp/textures, from tools/build_port.py), recolours the player's frames with the whole-character tool
(tools/sprite_sheet.py: black to dark purple, dark and light grey to purple and pink; white stays transparent) and writes the pack. Use it with
`texture_pack=textures_example` in painter_momopie.ini. It is a starting point to see how a texture pack works; the pictures come from your game, so the folder is not committed."""
import argparse, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(ROOT, "textures_example"))
ap.add_argument("--src", default=os.path.join(ROOT, "build", "recomp", "textures"))
a = ap.parse_args()
from PIL import Image

sheet = os.path.join(a.src, "2_4000_SpriteTiles.png")
if not os.path.exists(sheet):
    sys.exit("missing %s: run python tools/build_port.py first" % sheet)
os.makedirs(a.out, exist_ok=True)
shutil.copy(sheet, os.path.join(a.out, "2_4000_SpriteTiles.png"))
shutil.copy(os.path.join(a.src, "README.ini"), os.path.join(a.out, "README.ini")) if os.path.exists(os.path.join(a.src, "README.ini")) else None
tool = os.path.join(HERE, "sprite_sheet.py")
target = os.path.join(a.out, "2_4000_SpriteTiles.png")
with tempfile.TemporaryDirectory() as tmp:
    pic = os.path.join(tmp, "player.png")
    subprocess.run([sys.executable, tool, "assemble", "--sheet", target, "--out", pic], check=True)
    im = Image.open(pic).convert("RGBA")
    ramp = [(40, 10, 70), (120, 55, 175), (240, 150, 205)]      # the dark shades of the Game Boy palette
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, al = px[x, y]
            if al and r < 250:                    # pure white is the transparent shade of a sprite: it stays as it is
                shade = 0 if r < 43 else 1 if r < 128 else 2
                px[x, y] = ramp[shade] + (al,)
    edited = os.path.join(tmp, "edited.png")
    im.save(edited)
    subprocess.run([sys.executable, tool, "split", "--sheet", target, "--edited", edited, "--out", target], check=True)
print("example pack written to", a.out, "- set texture_pack=%s in painter_momopie.ini" % os.path.basename(a.out))

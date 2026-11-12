#!/usr/bin/env python3
"""Picture of every enemy kind, for the level editor: python tools/enemy_icons.py [--out DIR]

For each kind the native runner plays level 1 of the original rounds twice, with and without one enemy of that kind (no input), and the pixels that differ
at one frame are cut out as the icon. The pictures come from the game, so they are written to tools/.enemy_icons/ (git-ignored) and never committed.
Needs build/recomp/game_headless(.exe) (python tools/build_port.py) and Pillow."""
import argparse, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import levelpack as lp

ROOT = lp.ROOT
DEFAULT_OUT = os.path.join(os.path.dirname(lp.data_path("painter_momopie.gb")), "enemy_icons") if lp.FROZEN else os.path.join(HERE, ".enemy_icons")
FRAMES = (470, 520, 560)               # shots taken after the round has started; the first that shows a difference is used


def runner():
    return lp.runner_path()


def shots(prog, kind, tmp, tag):
    pack = lp.original()
    pack.levels = pack.levels[:1]
    lv = pack.levels[0]
    lv.waves = [[] for _ in range(6)]
    if kind is not None:
        lv.waves[0] = [[kind, 136, 138, 0]]
    pf = os.path.join(tmp, tag + ".pmpack")
    lp.save(pack, pf)
    ini = os.path.join(tmp, tag + ".ini")
    with open(ini, "w") as f:
        f.write("[game]\nlevel_pack=%s\n" % pf)
    out = os.path.join(tmp, tag)
    os.makedirs(out, exist_ok=True)
    cmd = [prog, "-", str(max(FRAMES) + 10), "--ini", ini, "--press", "250:start:3", "--outdir", out]
    for fr in FRAMES:
        cmd += ["--shot", str(fr)]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return [os.path.join(out, "rc_%04d.pgm" % fr) for fr in FRAMES]


def load_pgm(path):
    from PIL import Image
    return Image.open(path).convert("RGB")


def make(out=DEFAULT_OUT):
    from PIL import Image, ImageChops
    prog = runner()
    if not prog:
        return 0
    os.makedirs(out, exist_ok=True)
    n = 0
    with tempfile.TemporaryDirectory() as tmp:
        base = [load_pgm(p) for p in shots(prog, None, tmp, "base")]
        for kind in sorted(lp.KINDS):
            for img, ref in zip((load_pgm(p) for p in shots(prog, kind, tmp, "k%d" % kind)), base):
                box = ImageChops.difference(img, ref).getbbox()
                if box and (box[2] - box[0]) <= 48 and (box[3] - box[1]) <= 48:
                    pad = 1
                    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(img.width, box[2] + pad), min(img.height, box[3] + pad))
                    icon = img.crop(box).convert("RGBA")
                    px = icon.load()
                    rf = ref.crop(box).convert("RGBA").load()
                    for y in range(icon.height):           # pixels equal to the empty room become transparent
                        for x in range(icon.width):
                            if px[x, y][:3] == rf[x, y][:3]:
                                px[x, y] = (0, 0, 0, 0)
                    icon.save(os.path.join(out, "%d.png" % kind))
                    n += 1
                    break
    return n


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    a = ap.parse_args()
    print("%d enemy icons written to %s" % (make(a.out), a.out))

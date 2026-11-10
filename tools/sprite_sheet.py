#!/usr/bin/env python3
"""Paint a whole character instead of single 8x8 tiles: python tools/sprite_sheet.py assemble|split ...

The game draws a character from 8x8 tiles placed by a shape (docs/SPRITES.md). `assemble` puts the tiles of every frame of a character together into
one picture, `split` cuts an edited picture back into the tiles of a texture sheet. The pictures come from your game, so keep them out of git.

  python tools/sprite_sheet.py assemble --sheet textures/2_4000_SpriteTiles.png --out player.png
  (paint player.png: any colours, transparency allowed, keep the size)
  python tools/sprite_sheet.py split --sheet textures/2_4000_SpriteTiles.png --edited player.png [--out textures/2_4000_SpriteTiles.png]

`--character player` (the default) has nine frames: rows down, side (facing left; the game mirrors it when walking right) and up, three frames each.
Any other character: `--frames 0x48dc,0x48e3,...` (CPU addresses of the animation records in bank 1: a shape number and the tile numbers of its parts),
and `--columns N` for the layout. Needs build/painter_momopie.gb (python tools/build.py) and Pillow."""
import argparse, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ROM = os.path.join(ROOT, "build", "painter_momopie.gb")
PLAYER = [0x48DC, 0x48E3, 0x48EA,        # down: stand, step, step
          0x48F1, 0x48F8, 0x48FF,        # side (facing left)
          0x4906, 0x490D, 0x4914]        # up
CELL_W, CELL_H = 16, 24                  # pixels of a frame at the Game Boy scale: the shape spans x -8..8, y -16..8
GAP = 2


def sbyte(b):
    return b - 256 if b > 127 else b


def frame_parts(rom, rec):
    """[(tile id, x, y)] of a frame, x and y from the top left of the 16 x 24 cell"""
    shape_ptr = rom[0x06A4 + 2 * rom[rec]] | rom[0x06A5 + 2 * rom[rec]] << 8
    count = rom[shape_ptr]
    return [(rom[rec + 1 + i], sbyte(rom[shape_ptr + 1 + 2 * i]) + 8, sbyte(rom[shape_ptr + 2 + 2 * i]) + 16) for i in range(count)]


def layout(frames, columns):
    """cell origin (at the game scale) of every frame"""
    return [(GAP + (i % columns) * (CELL_W + GAP), GAP + (i // columns) * (CELL_H + GAP)) for i in range(len(frames))]


def sheet_scale(sheet):
    n = sheet.width // 128
    if n < 1 or sheet.width != 128 * n:
        sys.exit("the sheet must be 128 pixels wide times a whole number (it is %d wide)" % sheet.width)
    return n


def tile_box(tid, n):
    s = 8 * n
    return ((tid % 16) * s, (tid // 16) * s, (tid % 16) * s + s, (tid // 16) * s + s)


def build(frames, columns, rom, sheet):
    from PIL import Image
    n = sheet_scale(sheet)
    origins = layout(frames, columns)
    rows = (len(frames) + columns - 1) // columns
    canvas = Image.new("RGBA", ((GAP + columns * (CELL_W + GAP)) * n, (GAP + rows * (CELL_H + GAP)) * n), (0, 0, 0, 0))
    for rec, (ox, oy) in zip(frames, origins):
        for tid, x, y in frame_parts(rom, rec):
            canvas.alpha_composite(sheet.crop(tile_box(tid, n)), ((ox + x) * n, (oy + y) * n))
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=("assemble", "split"))
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--out")
    ap.add_argument("--edited")
    ap.add_argument("--character", default="player", choices=("player",))
    ap.add_argument("--frames", help="comma separated animation record addresses instead of --character")
    ap.add_argument("--columns", type=int, default=3)
    a = ap.parse_args()
    from PIL import Image
    if not os.path.exists(ROM):
        sys.exit("needs build/painter_momopie.gb: python tools/build.py")
    rom = open(ROM, "rb").read()
    frames = [int(x, 0) for x in a.frames.split(",")] if a.frames else PLAYER
    sheet = Image.open(a.sheet).convert("RGBA")
    n = sheet_scale(sheet)
    if a.action == "assemble":
        out = a.out or "character.png"
        build(frames, a.columns, rom, sheet).save(out)
        print("wrote %s (%d frames, %dx scale)" % (out, len(frames), n))
        return
    if not a.edited:
        sys.exit("split needs --edited picture.png")
    edited = Image.open(a.edited).convert("RGBA")
    original = build(frames, a.columns, rom, sheet)
    if edited.size != original.size:
        sys.exit("the edited picture must keep its size %dx%d (it is %dx%d)" % (original.width, original.height, edited.width, edited.height))
    s = 8 * n
    wanted = {}                                              # tile id -> new picture
    conflicts = set()
    for rec, (ox, oy) in zip(frames, layout(frames, a.columns)):
        for tid, x, y in frame_parts(rom, rec):
            box = ((ox + x) * n, (oy + y) * n, (ox + x) * n + s, (oy + y) * n + s)
            new, old = edited.crop(box), original.crop(box)
            if new.tobytes() == old.tobytes():
                continue
            if tid in wanted and wanted[tid].tobytes() != new.tobytes():
                conflicts.add(tid)
                continue
            wanted[tid] = new
    groups = {}                                              # tiles with the same picture in the game's graphics share one replacement
    for rec in frames:
        for tid, _, _ in frame_parts(rom, rec):
            groups.setdefault(sheet.crop(tile_box(tid, n)).tobytes(), set()).add(tid)
    for ids in groups.values():
        if len(ids) > 1:
            results = {(wanted[t] if t in wanted else sheet.crop(tile_box(t, n))).tobytes() for t in ids}
            if len(results) > 1:
                print("tiles %s have the same picture in the game, so they share one replacement; paint them the same or only one of them shows" % ", ".join("$%02x" % t for t in sorted(ids)))
    for tid in sorted(conflicts):
        print("tile $%02x is drawn differently by two frames; the first edit is kept" % tid)
    for tid, im in wanted.items():
        sheet.paste(im, tile_box(tid, n)[:2])
    out = a.out or a.sheet
    sheet.save(out)
    print("%d tiles changed, written to %s" % (len(wanted), out))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Level pack files (.pmpack): read, write and the conversion of the game's own 33 rounds.

    python tools/levelpack.py original [--rom build/painter_momopie.gb] [--out packs/original.pmpack]
    python tools/levelpack.py check packs/my.pmpack

Format (text, one item per line; see docs/LEVELS.md):
    pack My pack title
    textures folder            (optional: texture sheets used by every level)
    level Level name
    theme 3                    0-16: the look (tile set, floor, walls, room name); default = as in the original at this position
    music 0x84                 song id $81-$8b; default = original
    title NIGHT                (optional) up to 8 letters shown as the room name on the round intro screen
    song music.mml             (optional) a music text file played instead (docs/MUSIC.md)
    time 90                    seconds; magic 100  starting magic points; bonus 1  bonus screens follow; variant 1  spawn flag bit (1 or 2)
    textures folder            (optional: texture sheets used only in this level)
    map                        then 16 lines of 16 digits 0-3
    wave 0                     then lines `kind x y delay` (x = column * 16 + 24, y = row * 16 + 24 + flags, delay in seconds); waves 0-5
    end
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_LEVELS = 99
KINDS = {0: "Statue", 1: "Chaser", 2: "Wanderer", 3: "Fast chaser", 4: "Time-up chaser (paint cannot hurt it)", 5: "Shooter chaser",
         6: "Statue (B)", 7: "Path walker", 8: "Statue (C)", 9: "Teleporter", 10: "Shooter", 11: "Tile hider", 12: "Shooter (projectile)",
         13: "Last-round chaser"}
FIELDS = ("theme", "music", "time", "magic", "bonus", "variant")


class Level:
    def __init__(self):
        self.name = ""
        self.theme = self.music = self.time = self.magic = self.bonus = self.variant = None   # None = the original's value at this position
        self.textures = ""
        self.song = ""
        self.title = ""
        self.map = [[0] * 16 for _ in range(16)]
        self.waves = [[] for _ in range(6)]          # lists of [kind, x, y, delay]

    def paint_cells(self):
        return sum(1 for row in self.map for c in row if c)

    def copy(self):
        n = Level()
        n.name = self.name
        n.textures = self.textures
        n.song = self.song
        n.title = self.title
        for k in FIELDS:
            setattr(n, k, getattr(self, k))
        n.map = [row[:] for row in self.map]
        n.waves = [[e[:] for e in w] for w in self.waves]
        return n


class Pack:
    def __init__(self):
        self.title = "Untitled pack"
        self.author = ""
        self.textures = ""
        self.levels = []


def load(path):
    pack = Pack()
    cur = None
    in_map = 0
    wave = 0
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    for no, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line[0] in "#;":
            continue
        if in_map:
            if re.fullmatch("[0-3]{16}", line):
                cur.map[16 - in_map] = [int(c) for c in line]
                in_map -= 1
                continue
            raise ValueError("%s:%d: map rows are 16 digits 0-3" % (path, no))
        parts = line.split(None, 1)
        key, rest = parts[0], (parts[1] if len(parts) > 1 else "")
        if cur is None:
            if key == "pack":
                pack.title = rest
            elif key == "author":
                pack.author = rest
            elif key == "textures":
                pack.textures = rest
            elif key == "level":
                cur = Level()
                cur.name = rest
                pack.levels.append(cur)
                wave = 0
            continue
        if key == "level":
            cur = Level()
            cur.name = rest
            pack.levels.append(cur)
            wave = 0
        elif key in FIELDS:
            setattr(cur, key, int(rest, 0))
        elif key == "textures":
            cur.textures = rest
        elif key == "song":
            cur.song = rest
        elif key == "title":
            cur.title = rest
        elif key == "map":
            in_map = 16
        elif key == "wave":
            wave = int(rest)
        elif key == "end":
            cur = None
        elif key.isdigit():
            nums = [int(x) for x in line.split()]
            if len(nums) != 4:
                raise ValueError("%s:%d: spawn lines are `kind x y delay`" % (path, no))
            cur.waves[wave].append(nums)
    return pack


def save(pack, path):
    out = ["pack " + pack.title]
    if pack.author:
        out.append("author " + pack.author)
    if pack.textures:
        out.append("textures " + pack.textures)
    for lv in pack.levels:
        out.append("")
        out.append("level " + lv.name)
        for key in FIELDS:
            v = getattr(lv, key)
            if v is not None:
                out.append("%s %s" % (key, hex(v) if key == "music" else v))
        if lv.title:
            out.append("title " + lv.title)
        if lv.song:
            out.append("song " + lv.song)
        if lv.textures:
            out.append("textures " + lv.textures)
        out.append("map")
        out.extend("".join(str(c) for c in row) for row in lv.map)
        for w, spawns in enumerate(lv.waves):
            if spawns:
                out.append("wave %d" % w)
                out.extend(" ".join(str(n) for n in e) for e in spawns)
        out.append("end")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


def cell_of(x, y):
    """the map cell (column, row) of a spawn position"""
    return (x >> 4) - 1, (y >> 4) - 1


def pos_of(col, row, flags=0):
    """the spawn position of a cell: x = column * 16 + 24, y = row * 16 + 24 (+ the low 3 bits as flags)"""
    return col * 16 + 24, row * 16 + 24 + flags


def problems(pack):
    """a list of readable warnings about a pack"""
    out = []
    if not pack.levels:
        out.append("The pack has no levels.")
    if len(pack.levels) > MAX_LEVELS:
        out.append("More than %d levels." % MAX_LEVELS)
    total = 0
    for i, lv in enumerate(pack.levels, 1):
        tag = "Level %d (%s)" % (i, lv.name)
        if lv.paint_cells() == 0:
            out.append("%s: the map has no path cells." % tag)
        elif lv.paint_cells() > 255:
            out.append("%s: more than 255 path cells (the counter is a byte)." % tag)
        if not lv.map[6][7]:
            out.append("%s: the player starts on column 7, row 6 (counting from 0), which is not a path." % tag)
        for w, spawns in enumerate(lv.waves):
            total += 1 + 4 * max(len(spawns), 1)
            for kind, x, y, delay in spawns:
                col, row = cell_of(x, y)
                if not (0 <= col < 16 and 0 <= row < 16):
                    out.append("%s: an enemy (kind %d, wave %d) is outside the map." % (tag, kind, w))
                elif not lv.map[row][col] and kind not in (0, 6, 7, 8):
                    out.append("%s: an enemy (kind %d, wave %d) starts off the path at column %d, row %d." % (tag, kind, w, col, row))
                if not 0 <= kind <= 13:
                    out.append("%s: enemy kind %d does not exist (0-13)." % (tag, kind))
    if total + len(pack.levels) * 12 > 0x4000:
        out.append("Too many enemies in total for one pack.")
    return out


def sym_table(sym):
    t = {}
    for line in open(sym):
        m = re.match(r"([0-9a-f]{2}):([0-9a-f]{4}) (\w+)", line)
        if m:
            t[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    return t


def original(rom_path=None):
    rom_path = rom_path or os.path.join(ROOT, "build", "painter_momopie.gb")
    rom = open(rom_path, "rb").read()
    sym = sym_table(os.path.join(ROOT, "build", "painter_momopie.sym"))

    def b0(name):
        return sym[name][1]                          # bank 0 addresses are file offsets

    def word(a):
        return rom[a] | rom[a + 1] << 8

    pack = Pack()
    pack.title = "Painter Momopie (original 33 rounds)"
    for i in range(33):
        lv = Level()
        lv.name = "Round %d" % (i + 1)
        look = 16 if i == 32 else i & 15
        mp = word(b0("RoomMapTable") + 2 * look)
        for k in range(256):
            lv.map[k // 16][k % 16] = (rom[mp + k // 4] >> (6 - 2 * (k % 4))) & 3
        table = word(b0("RoundDataTable") + 2 * i)
        for w in range(6):
            lst = word(table + 2 * w)
            count = rom[lst]
            lv.waves[w] = [list(rom[lst + 1 + 4 * s: lst + 5 + 4 * s]) for s in range(count)]
        lv.theme = look
        lv.time = 90 if i == 32 else rom[b0("RoundTimeTable") + ((i + 1) >> 2)]
        lv.magic = rom[0x1462 + 2 * (i + 1)] << 8 | rom[0x1462 + 2 * (i + 1) + 1]
        lv.music = rom[0x1400 + ((i + 1) >> 2)]
        lv.bonus = 1 if i + 2 in (4, 8, 12, 20, 24, 28) else 0
        lv.variant = 2 if i + 1 >= 17 else 1
        pack.levels.append(lv)
    return pack


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
    elif a[0] == "original":
        rom = a[a.index("--rom") + 1] if "--rom" in a else None
        out = a[a.index("--out") + 1] if "--out" in a else os.path.join(ROOT, "packs", "original.pmpack")
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        save(original(rom), out)
        print("wrote", out)
    elif a[0] == "check":
        p = load(a[1])
        w = problems(p)
        print("%d levels, %d warnings" % (len(p.levels), len(w)))
        for x in w:
            print(" ", x)


if __name__ == "__main__":
    main()

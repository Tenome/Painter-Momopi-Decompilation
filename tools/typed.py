#!/usr/bin/env python3
"""Editable text forms of data regions listed in typed.csv.

    python tools/typed.py txt     assets/bank_BB/AAAA_*.bin -> assets/typed/<name>.txt
    python tools/typed.py bin     assets/typed/<name>.txt   -> assets/bank_BB/AAAA_*.bin   (the build runs this first)

Types:
  map    a room map: 16 lines of 16 digits 0-3 (2 bits per cell; 0 empty, 1 and 2 path pieces, 3 unused so far); 64 bytes in the ROM.
  u8     COUNT decimal values 0-255 (the first COUNT bytes of the region; the rest of the region is kept)
  u16be  COUNT decimal values 0-65535 stored high byte first
  shapes the sprite shape data (offsets of the 8x8 parts of each shape), see tools/shape_fmt.py
  anim   animation frames (shape id + tile ids) in the first COUNT bytes of the region; needs the shape table
  song   a sound data region: header and token stream, see tools/song_fmt.py (notes, lengths, commands; the size must stay the same)
  rounddata  the enemy spawn waves of a round: 6 pointers then the wave lists. Text: `wave N` then one line per spawn `kind x y delay`
         (`kind` indexes the enemy kinds, `delay` is compared with the seconds counter). The number of spawns in each wave must stay the same.
"""
import csv, glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import song_fmt
import shape_fmt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def entries():
    with open(os.path.join(ROOT, "typed.csv"), encoding="utf-8") as f:
        for r in csv.reader(l for l in f if l.strip() and not l.startswith("#")):
            if r[0] != "bank":
                yield int(r[0]), r[1], r[2], r[3], int(r[4]) if len(r) > 4 and r[4] else 0


def find_bin(bank, addr):
    hits = glob.glob(os.path.join(ROOT, "assets", f"bank_{bank:02x}", f"{addr}*.bin"))
    if not hits:
        raise SystemExit(f"no asset file for bank {bank} address {addr}")
    return hits[0]


def map_to_txt(data):
    cells = [(b >> (6 - 2 * k)) & 3 for b in data for k in range(4)]
    return "\n".join("".join(str(c) for c in cells[r * 16:r * 16 + 16]) for r in range(16)) + "\n"


def map_to_bin(text):
    rows = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if len(rows) != 16 or any(len(r) != 16 or set(r) - set("0123") for r in rows):
        raise SystemExit("a map needs 16 lines of 16 digits (0-3)")
    cells = [int(c) for r in rows for c in r]
    return bytes(cells[i] << 6 | cells[i + 1] << 4 | cells[i + 2] << 2 | cells[i + 3] for i in range(0, 256, 4))


def rounddata_to_txt(data, start):
    out = []
    for w in range(6):
        p = (data[2 * w] | data[2 * w + 1] << 8) - start
        n = data[p]
        out.append(f"wave {w}")
        out += [" ".join(str(v) for v in data[p + 1 + 4 * i:p + 5 + 4 * i]) for i in range(n)]
    return "\n".join(out) + "\n"


def rounddata_to_bin(text, old, start, name):
    data = bytearray(old)
    cur, waves = None, {}
    for ln in text.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        if ln.startswith("wave"):
            cur = int(ln.split()[1])
            waves[cur] = []
        else:
            vals = [int(x) for x in ln.split()]
            if len(vals) != 4 or any(not 0 <= v < 256 for v in vals):
                raise SystemExit(f"{name}: a spawn line needs 4 values 0-255: {ln!r}")
            waves[cur].append(vals)
    written = {}
    for w in range(6):
        p = (old[2 * w] | old[2 * w + 1] << 8) - start
        n = old[p]
        if len(waves.get(w, [])) != n:
            raise SystemExit(f"{name}: wave {w} must keep {n} spawns")
        flat = bytes(v for e in waves[w] for v in e)
        if p in written and written[p] != flat:
            raise SystemExit(f"{name}: waves sharing the list at {p + start:04x} must stay identical")
        written[p] = flat
        data[p + 1:p + 1 + len(flat)] = flat
    return bytes(data)


_COUNTS = []


def shape_counts():
    if not _COUNTS:
        data = open(find_bin(0, "06a4"), "rb").read()
        _COUNTS.extend(shape_fmt.counts(data, 0x06A4))
    return _COUNTS


def to_txt(t, c, data, start=0):
    if t == "anim":
        return shape_fmt.anim_to_txt(data, c, shape_counts())
    if t == "shapes":
        return shape_fmt.to_txt(data, start)
    if t == "song":
        return song_fmt.to_txt(data, start)
    if t == "rounddata":
        return rounddata_to_txt(data, start)
    if t == "map":
        return map_to_txt(data)
    if t == "u8":
        return " ".join(str(v) for v in data[:c]) + "\n"
    return " ".join(str(data[2 * i] << 8 | data[2 * i + 1]) for i in range(c)) + "\n"


def to_bin(t, c, n, text, old, start=0):
    if t == "anim":
        return shape_fmt.anim_to_bin(text, old, c, shape_counts())
    if t == "shapes":
        return shape_fmt.to_bin(text, old, start)
    if t == "song":
        return song_fmt.to_bin(text, start, len(old))
    if t == "rounddata":
        return rounddata_to_bin(text, old, start, n)
    if t == "map":
        return map_to_bin(text)
    vals = [int(x) for x in text.split()]
    if len(vals) != c:
        raise SystemExit(f"{n}: expected {c} values, found {len(vals)}")
    data = bytes(vals) if t == "u8" else b"".join(bytes([v >> 8, v & 255]) for v in vals)
    return data + old[len(data):]


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "txt":
        os.makedirs(os.path.join(ROOT, "assets", "typed"), exist_ok=True)
        for b, a, t, n, c in entries():
            data = open(find_bin(b, a), "rb").read()
            open(os.path.join(ROOT, "assets", "typed", n + ".txt"), "w", newline="\n").write(to_txt(t, c, data, int(a, 16)))
        print("wrote text forms to assets/typed/")
    elif cmd == "bin":
        done = 0
        for b, a, t, n, c in entries():
            p = os.path.join(ROOT, "assets", "typed", n + ".txt")
            if not os.path.exists(p):
                continue
            target = find_bin(b, a)
            old = open(target, "rb").read()
            data = to_bin(t, c, n, open(p).read(), old, int(a, 16))
            if data != old:
                open(target, "wb").write(data)
                print("updated", os.path.relpath(target, ROOT))
            done += 1
        print(done, "text assets checked")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()

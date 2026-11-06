#!/usr/bin/env python3
"""Editable text forms of data regions listed in typed.csv.

    python tools/typed.py txt     assets/bank_BB/AAAA_*.bin -> assets/typed/<name>.txt
    python tools/typed.py bin     assets/typed/<name>.txt   -> assets/bank_BB/AAAA_*.bin   (the build runs this first)

Types:
  map    a room map: 16 lines of 16 digits 0-3 (2 bits per cell; 0 empty, 1 and 2 path pieces, 3 unused so far); 64 bytes in the ROM.
  u8     COUNT decimal values 0-255 (the first COUNT bytes of the region; the rest of the region is kept)
  u16be  COUNT decimal values 0-65535 stored high byte first
"""
import csv, glob, os, sys

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


def to_txt(t, c, data):
    if t == "map":
        return map_to_txt(data)
    if t == "u8":
        return " ".join(str(v) for v in data[:c]) + "\n"
    return " ".join(str(data[2 * i] << 8 | data[2 * i + 1]) for i in range(c)) + "\n"


def to_bin(t, c, n, text, old):
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
            open(os.path.join(ROOT, "assets", "typed", n + ".txt"), "w", newline="\n").write(to_txt(t, c, data))
        print("wrote text forms to assets/typed/")
    elif cmd == "bin":
        done = 0
        for b, a, t, n, c in entries():
            p = os.path.join(ROOT, "assets", "typed", n + ".txt")
            if not os.path.exists(p):
                continue
            target = find_bin(b, a)
            old = open(target, "rb").read()
            data = to_bin(t, c, n, open(p).read(), old)
            if data != old:
                open(target, "wb").write(data)
                print("updated", os.path.relpath(target, ROOT))
            done += 1
        print(done, "text assets checked")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()

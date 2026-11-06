"""Text form of the sprite shape data (ObjectShapeTable and the shapes it points to, region of 323 bytes at bank 0 $06a4).

Layout (decoded from DrawObject): 15 words (pointers to shapes), then the shapes. A shape is `count`, then `count` pairs of signed bytes:
the X and Y offset of each 8x8 part from the object's position (parts are numbered in order and take their tile ids from the animation data).
A few blocks do not follow that layout (the table entries for shapes 3 and 4 point into the middle of other data and are never used in play);
those are kept as raw bytes.

Text form:
  table 15                              number of pointers (the pointer words themselves are kept as they are)
  shape @06c2 3                         block at that address with 3 parts; one `x y` line per part (signed decimal)
  -8 -16
  raw @06e5 fc f8 fc 00                 block that is not a regular shape (hex bytes)
The blocks are listed in address order and the total size must stay the same.
"""


def _signed(b):
    return b - 256 if b > 127 else b


def to_txt(data, start):
    n = (data[0] | data[1] << 8) - start
    n //= 2
    ptrs = [data[2 * i] | data[2 * i + 1] << 8 for i in range(n)]
    starts = sorted(set(ptrs))
    out = [f"table {n}"]
    end = start + len(data)
    for i, p in enumerate(starts):
        nxt = starts[i + 1] if i + 1 < len(starts) else end
        blk = data[p - start:nxt - start]
        c = blk[0]
        if len(blk) == 1 + 2 * c and c <= 40:
            out.append(f"shape @{p:04x} {c}")
            out += [f"{_signed(blk[1 + 2 * k])} {_signed(blk[2 + 2 * k])}" for k in range(c)]
        else:
            out.append(f"raw @{p:04x} " + " ".join(f"{b:02x}" for b in blk))
    return "\n".join(out) + "\n"


def to_bin(text, old, start):
    n = (old[0] | old[1] << 8) - start
    n //= 2
    data = bytearray(old)
    lines = [ln.split("#")[0].strip() for ln in text.splitlines()]
    lines = [ln for ln in lines if ln]
    if lines[0] != f"table {n}":
        raise SystemExit(f"shape text must start with 'table {n}'")
    i = 1
    while i < len(lines):
        t = lines[i].split()
        addr = int(t[1][1:], 16) - start
        if t[0] == "raw":
            blk = bytes(int(x, 16) for x in t[2:])
            i += 1
        elif t[0] == "shape":
            c = int(t[2])
            blk = bytearray([c])
            for k in range(c):
                x, y = lines[i + 1 + k].split()
                blk += bytes([int(x) & 255, int(y) & 255])
            blk = bytes(blk)
            i += 1 + c
        else:
            raise SystemExit(f"bad line {lines[i]!r}")
        if addr + len(blk) > len(data):
            raise SystemExit("shape block runs past the region")
        if bytes(data[addr:addr + len(blk)]) != blk and False:
            pass
        data[addr:addr + len(blk)] = blk
    return bytes(data)

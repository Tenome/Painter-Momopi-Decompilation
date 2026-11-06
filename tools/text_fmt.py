r"""Text form of a VRAM text page (the credit pages): a copy list followed by its string blocks.

Layout: count, then count entries of `dest (2 bytes, little endian), source (2 bytes)`, then the blocks the sources point at, back to back.
A block is `length, rows, tiles` with one row (`rows` = 1). Charmap: tile $80+n = letter A+n, $ab+n = digit n, $ff = space, $b5 = '!', $b6 = 'x';
any other tile is written as \xNN.

Text form (one line per entry, '#' starts a comment):
  at 9c47 "STAFF"
The number of lines and the length of every string must stay the same (the region keeps its size and the entries keep their sources).
"""

CM = {0xFF: " ", 0xB5: "!", 0xB6: "x"}
for _i in range(26):
    CM[0x80 + _i] = chr(65 + _i)
for _i in range(10):
    CM[0xAB + _i] = str(_i)
REV = {v: k for k, v in CM.items()}


def enc(s):
    out, i = bytearray(), 0
    while i < len(s):
        if s[i] == "\\" and s[i + 1] == "x":
            out.append(int(s[i + 2:i + 4], 16))
            i += 4
        else:
            out.append(REV[s[i]])
            i += 1
    return bytes(out)


def dec(b):
    return "".join(CM.get(x, "\\x%02x" % x) for x in b)


def to_txt(data, start):
    n = data[0]
    pos = 1 + 4 * n
    out = []
    for i in range(n):
        dest = data[1 + 4 * i] | data[2 + 4 * i] << 8
        src = data[3 + 4 * i] | data[4 + 4 * i] << 8
        if src - start != pos:
            raise ValueError("source of an entry is not the next block")
        ln, rows = data[pos], data[pos + 1]
        if rows != 1:
            raise ValueError("only one row blocks are supported")
        out.append(f'at {dest:04x} "{dec(data[pos + 2:pos + 2 + ln])}"')
        pos += 2 + ln
    if pos != len(data):
        raise ValueError("data after the last block")
    return "\n".join(out) + "\n"


def to_bin(text, old, start):
    n = old[0]
    lines = [ln.split("#")[0].strip() for ln in text.splitlines()]
    lines = [ln for ln in lines if ln]
    if len(lines) != n:
        raise SystemExit(f"expected {n} lines")
    pos = 1 + 4 * n
    heads, blocks = bytearray([n]), bytearray()
    for i, ln in enumerate(lines):
        _, dest, rest = ln.split(None, 2)
        s = enc(rest.strip()[1:-1])
        old_len = old[pos + len(blocks)]
        if len(s) != old_len:
            raise SystemExit(f"string {i} must keep its length {old_len}: {ln!r}")
        d = int(dest, 16)
        a = start + pos + len(blocks)
        heads += bytes([d & 255, d >> 8, a & 255, a >> 8])
        blocks += bytes([len(s), 1]) + s
    out = bytes(heads) + bytes(blocks)
    if len(out) != len(old):
        raise SystemExit("size changed")
    return out

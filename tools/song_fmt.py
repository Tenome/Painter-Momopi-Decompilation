"""Text form of a sound data region (a song or an effect): header, channel streams, tokens.

Region layout (verified by playing every sound id): byte 0 = number of channels N; then N headers of 10 bytes
  flags, hardware channel (0 pulse1, 1 pulse2, 2 wave, 3 noise), pan mask, stream pointer (2 bytes, absolute CPU address), transpose,
  record +6, envelope (NRx2), tempo step, record +9
followed by the stream bytes: $e0-$f1 commands with operands, $80-$df notes, $00-$7f lengths.

Text form (one item per line, '#' starts a comment):
  channels 3
  head 80 00 ff @c0 f6 01 a4 78 00        header; @c0 = label of the stream start
  :c0                                      label (a position in the token stream)
  C e8 40                                  command with operand bytes; jump/call/repeat targets are written as @label
  N b5   L 04                              note byte / length byte
Labels are resolved to absolute addresses (region start + offset) when the text is turned back into bytes. The region must keep its size.
"""

OPS = {0xE0: 2, 0xE1: 2, 0xE2: 0, 0xE3: 0, 0xE4: 4, 0xE5: 2, 0xE6: 1, 0xE7: 1, 0xE8: 1, 0xE9: 1, 0xEA: 1, 0xEB: 0, 0xEC: 0,
       0xED: 0, 0xEE: 0, 0xEF: 1, 0xF0: 1, 0xF1: 1}
PTR_AT = {0xE0: (0,), 0xE1: (0,), 0xE5: (0,), 0xE4: (2,)}     # operand offsets that hold a 2 byte stream address


def to_txt(data, start):
    n = data[0]
    pos = 1 + 10 * n
    targets = set()
    heads = []
    for c in range(n):
        h = data[1 + 10 * c:11 + 10 * c]
        heads.append(h)
        targets.add(h[3] | h[4] << 8)
    toks = []
    q = pos
    while q < len(data):
        b = data[q]
        if b >= 0xE0:
            if b not in OPS or q + 1 + OPS[b] > len(data):
                raise ValueError(f"cannot parse byte {b:02x} at +{q:#x}")
            ops = data[q + 1:q + 1 + OPS[b]]
            for o in PTR_AT.get(b, ()):
                targets.add(ops[o] | ops[o + 1] << 8)
            toks.append((q, "C", b, ops))
            q += 1 + OPS[b]
        else:
            toks.append((q, "N" if b >= 0x80 else "L", b, b""))
            q += 1
    inside = {t for t in targets if start + pos <= t < start + len(data) and any(start + k[0] == t for k in toks)}
    names = {t: f"s{t:04x}" for t in sorted(inside)}

    def ref(v):
        return "@" + names[v] if v in names else f"{v & 255:02x} {v >> 8:02x}"

    out = [f"channels {n}"]
    for h in heads:
        p = h[3] | h[4] << 8
        out.append("head " + " ".join(f"{x:02x}" for x in h[:3]) + " " + (ref(p) if p in names else f"{h[3]:02x} {h[4]:02x}") + " " +
                   " ".join(f"{x:02x}" for x in h[5:]))
    for q, kind, b, ops in toks:
        if start + q in names:
            out.append(f":{names[start + q]}")
        if kind == "C":
            parts = [f"{b:02x}"]
            i = 0
            ptr = PTR_AT.get(b, ())
            while i < len(ops):
                if i in ptr:
                    v = ops[i] | ops[i + 1] << 8
                    parts.append("@" + names[v] if v in names else f"{ops[i]:02x} {ops[i + 1]:02x}")
                    i += 2
                else:
                    parts.append(f"{ops[i]:02x}")
                    i += 1
            out.append("C " + " ".join(parts))
        else:
            out.append(f"{kind} {b:02x}")
    return "\n".join(out) + "\n"


def to_bin(text, start, size):
    lines = [ln.split("#")[0].strip() for ln in text.splitlines()]
    lines = [ln for ln in lines if ln]
    n = int(lines[0].split()[1])
    heads = [ln for ln in lines if ln.startswith("head ")]
    if len(heads) != n:
        raise SystemExit(f"expected {n} head lines")
    body = [ln for ln in lines[1:] if not ln.startswith("head ")]
    labels = {}
    off = 1 + 10 * n
    items = []
    for ln in body:
        if ln.startswith(":"):
            labels[ln[1:]] = start + off
            continue
        kind, rest = ln.split(None, 1)
        if kind in ("N", "L"):
            items.append((kind, rest))
            off += 1
        elif kind == "C":
            toks = rest.split()
            cmd = int(toks[0], 16)
            ln_ops = OPS[cmd]
            items.append((kind, rest))
            off += 1 + ln_ops
        else:
            raise SystemExit(f"bad line {ln!r}")
    if off != size:
        raise SystemExit(f"song text assembles to {off} bytes but the region has {size}")

    def val(tok):
        return labels[tok[1:]] if tok.startswith("@") else None

    out = bytearray([n])
    for h in heads:
        t = h.split()[1:]
        bs = [int(x, 16) for x in t[:3]]
        if t[3].startswith("@"):
            a = labels[t[3][1:]]
            bs += [a & 255, a >> 8]
            rest = t[4:]
        else:
            bs += [int(t[3], 16), int(t[4], 16)]
            rest = t[5:]
        bs += [int(x, 16) for x in rest]
        if len(bs) != 10:
            raise SystemExit(f"header needs 10 bytes: {h!r}")
        out += bytes(bs)
    for kind, rest in items:
        if kind in ("N", "L"):
            out.append(int(rest, 16))
        else:
            toks = rest.split()
            out.append(int(toks[0], 16))
            for t in toks[1:]:
                if t.startswith("@"):
                    a = labels[t[1:]]
                    out += bytes([a & 255, a >> 8])
                else:
                    out.append(int(t, 16))
    if len(out) != size:
        raise SystemExit(f"song assembles to {len(out)} bytes, expected {size}")
    return bytes(out)

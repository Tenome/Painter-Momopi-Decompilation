"""SM83 (Game Boy CPU) instruction table, decoder and a tiny encoder (RGBDS syntax).

Templates use placeholders: n8, n16, a16 (absolute address), a8 (high-page offset), e8 (signed), j8 (jr target).
"""
import re

R8 = ["b", "c", "d", "e", "h", "l", "[hl]", "a"]
R16 = ["bc", "de", "hl", "sp"]
R16S = ["bc", "de", "hl", "af"]
CC = ["nz", "z", "nc", "c"]
ALU = ["add a,", "adc a,", "sub a,", "sbc a,", "and a,", "xor a,", "or a,", "cp a,"]
ROT = ["rlc", "rrc", "rl", "rr", "sla", "sra", "swap", "srl"]

OPS = {}  # opcode -> template
for i, rr in enumerate(R16):
    OPS[0x01 + 16 * i] = f"ld {rr}, n16"
    OPS[0x09 + 16 * i] = f"add hl, {rr}"
    OPS[0x03 + 16 * i] = f"inc {rr}"
    OPS[0x0B + 16 * i] = f"dec {rr}"
    if i < 4:
        OPS[0xC1 + 16 * i] = f"pop {R16S[i]}"
        OPS[0xC5 + 16 * i] = f"push {R16S[i]}"
OPS.update({
    0x00: "nop", 0x02: "ld [bc], a", 0x12: "ld [de], a", 0x22: "ld [hl+], a", 0x32: "ld [hl-], a",
    0x0A: "ld a, [bc]", 0x1A: "ld a, [de]", 0x2A: "ld a, [hl+]", 0x3A: "ld a, [hl-]",
    0x07: "rlca", 0x0F: "rrca", 0x17: "rla", 0x1F: "rra", 0x27: "daa", 0x2F: "cpl", 0x37: "scf", 0x3F: "ccf",
    0x08: "ld [a16], sp", 0x10: "stop", 0x18: "jr j8",
    0x20: "jr nz, j8", 0x28: "jr z, j8", 0x30: "jr nc, j8", 0x38: "jr c, j8",
    0xC3: "jp a16", 0xC9: "ret", 0xD9: "reti", 0xCD: "call a16", 0xE9: "jp hl",
    0xE0: "ldh [a8], a", 0xF0: "ldh a, [a8]", 0xE2: "ldh [c], a", 0xF2: "ldh a, [c]",
    0xEA: "ld [a16], a", 0xFA: "ld a, [a16]", 0xE8: "add sp, e8", 0xF8: "ld hl, sp+e8",
    0xF9: "ld sp, hl", 0xF3: "di", 0xFB: "ei", 0x76: "halt",
})
for i, r in enumerate(R8):
    OPS[0x04 + 8 * i] = f"inc {r}"
    OPS[0x05 + 8 * i] = f"dec {r}"
    OPS[0x06 + 8 * i] = f"ld {r}, n8"
    for j, s in enumerate(R8):
        if 0x40 + 8 * i + j != 0x76:
            OPS[0x40 + 8 * i + j] = f"ld {r}, {s}"
    for k, a in enumerate(ALU):
        OPS[0x80 + 8 * k + i] = f"{a} {r}"
for k, a in enumerate(ALU):
    OPS[0xC6 + 8 * k] = f"{a} n8"
for i in range(8):
    OPS[0xC7 + 8 * i] = f"rst ${i * 8:02x}"
for i, c in enumerate(CC):
    OPS[0xC0 + 8 * i] = f"ret {c}"
    OPS[0xC2 + 8 * i] = f"jp {c}, a16"
    OPS[0xC4 + 8 * i] = f"call {c}, a16"

CB = {}
for i, r in enumerate(R8):
    for k, o in enumerate(ROT):
        CB[8 * k + i] = f"{o} {r}"
    for b in range(8):
        CB[0x40 + 8 * b + i] = f"bit {b}, {r}"
        CB[0x80 + 8 * b + i] = f"res {b}, {r}"
        CB[0xC0 + 8 * b + i] = f"set {b}, {r}"


def length(tpl):
    if "n16" in tpl or "a16" in tpl:
        return 3
    if any(p in tpl for p in ("n8", "a8", "e8", "j8")) or tpl == "stop":
        return 2
    return 1


def decode(rom, pc, off, label=None):
    """Decode one instruction. pc = CPU address, off = file offset.
    Returns (length, text, kind, target) with kind in plain/jp/jr/call/ret/jpind/rst/bad."""
    op = rom[off]
    if op == 0xCB:
        return 2, CB[rom[off + 1]], "plain", None
    tpl = OPS.get(op)
    if tpl is None:
        return 1, None, "bad", None
    n = length(tpl)
    if off + n > len(rom) or (op == 0x10 and rom[off + 1] != 0):
        return 1, None, "bad", None
    kind, target = "plain", None
    if "j8" in tpl:
        d = rom[off + 1]
        d = d - 256 if d >= 128 else d
        target = (pc + 2 + d) & 0xFFFF
        text = tpl.replace("j8", label(target) if label else f"${target:04x}")
        kind = "jr"
        if tpl == "jr j8":
            kind = "jru"
    elif "a16" in tpl:
        target = rom[off + 1] | rom[off + 2] << 8
        sym = f"${target:04x}"
        if tpl.startswith(("jp", "call")) and label:
            sym = label(target)
        text = tpl.replace("a16", sym)
        if tpl.startswith("jp"):
            kind = "jpu" if tpl == "jp a16" else "jp"
        elif tpl.startswith("call"):
            kind = "call"
        else:
            target = None
    elif "n16" in tpl:
        text = tpl.replace("n16", f"${rom[off + 1] | rom[off + 2] << 8:04x}")
    elif "a8" in tpl:
        text = tpl.replace("a8", f"$ff{rom[off + 1]:02x}")
    elif "e8" in tpl:
        v = rom[off + 1]
        v = v - 256 if v >= 128 else v
        text = tpl.replace("+e8", f" + {v}" if v >= 0 else f" - {-v}").replace(
            "e8", str(v))
    elif "n8" in tpl:
        text = tpl.replace("n8", f"${rom[off + 1]:02x}")
    else:
        text = tpl
    if tpl in ("ret", "reti"):
        kind = "retu"
    elif tpl.startswith("ret"):
        kind = "ret"
    elif tpl == "jp hl":
        kind = "jpind"
    elif tpl.startswith("rst"):
        kind = "rst"
        target = int(tpl[-2:], 16)
    return n, text, kind, target


# ---- tiny encoder, used only to prove the emitted assembly round-trips ----
def _build_encoder():
    enc = []
    for op, tpl in list(OPS.items()):
        pat = re.escape(tpl)
        pat = pat.replace(re.escape("+e8"), "@@SP@@").replace("e8", "@@E8@@")
        for ph, rx in (("j8", r"(?P<j8>\.?[A-Z]\w*|\$[0-9a-f]{4})"), ("a16", r"(?P<a16>\.?[A-Z]\w*|\$[0-9a-f]{4})"), ("n16", r"(?P<n16>\$[0-9a-f]{4}|\.?[A-Z]\w*)"),
                       ("a8", r"\$ff(?P<a8>[0-9a-f]{2})"), ("n8", r"\$(?P<n8>[0-9a-f]{2})")):
            pat = pat.replace(ph, rx)
        pat = pat.replace("@@SP@@", r" (?P<sp>[+-]) (?P<e8>\d+)").replace("@@E8@@", r"(?P<e8>-?\d+)")
        enc.append((re.compile("^" + pat.replace(r"\ ", " ") + "$"), op, tpl))
    return enc


_ENC = None


def encode(text, pc, resolve):
    global _ENC
    if _ENC is None:
        _ENC = _build_encoder()
    for k, v in CB.items():
        if v == text:
            return bytes([0xCB, k])
    for rx, op, tpl in _ENC:
        m = rx.match(text)
        if not m:
            continue
        g = m.groupdict()
        if "j8" in g and g["j8"] is not None:
            t = resolve(g["j8"])
            return bytes([op, (t - (pc + 2)) & 0xFF])
        if g.get("a16") is not None:
            t = resolve(g["a16"])
            return bytes([op, t & 0xFF, t >> 8])
        if g.get("n16") is not None:
            t = resolve(g["n16"])
            return bytes([op, t & 0xFF, t >> 8])
        if g.get("a8") is not None:
            return bytes([op, int(g["a8"], 16)])
        if g.get("e8") is not None:
            v = int(g["e8"])
            if g.get("sp") == "-":
                v = -v
            return bytes([op, v & 0xFF])
        if g.get("n8") is not None:
            return bytes([op, int(g["n8"], 16)])
        return bytes([op, 0]) if tpl == "stop" else bytes([op])
    raise ValueError(f"cannot encode {text!r}")

#!/usr/bin/env python3
"""Trace-disassemble the ROM into RGBDS source (src/bank_NN.asm) and prove the source reproduces the ROM.

    python tools/gb_dis.py [--rom orig/painter_momopie.gb] [--write] [--check]

Code is found by recursive descent from the vectors and entry point plus every call/jump target; everything else is
emitted as `db`. Names come from labels.csv (bank,addr,name,comment; bank = ROM bank 0-3, addr = CPU address in hex).
Banks 1-3 are mapped at $4000: a jump/call from bank N to $4000+ stays in bank N; from bank 0 the target bank is
unknown, so those targets are listed in build/cross_bank_candidates.tsv and marked by hand (labels.csv `bank,addr,...`
with the entry in `seeds.csv`).
"""
import argparse, csv, hashlib, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import sm83

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANK = 0x4000
VECTORS = [0x00, 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38, 0x40, 0x48, 0x50, 0x58, 0x60, 0x100]


def off(bank, addr):
    return addr if addr < BANK else bank * BANK + (addr - BANK)


def read_csv(path):
    rows = []
    if os.path.exists(path):
        for r in csv.reader(l for l in open(path, encoding="utf-8") if l.strip() and not l.startswith("#")):
            rows.append(r)
    return rows


class Rom:
    def __init__(self, path):
        self.data = open(path, "rb").read()
        self.nbanks = len(self.data) // BANK
        self.names = {}      # (bank, addr) -> name
        self.comments = {}
        for r in read_csv(os.path.join(ROOT, "labels.csv")):
            if r[0] == "bank":
                continue
            self.names[(int(r[0]), int(r[1], 16))] = r[2]
            if len(r) > 3 and r[3]:
                self.comments[(int(r[0]), int(r[1], 16))] = r[3]
        self.seeds = [(int(r[0]), int(r[1], 16)) for r in read_csv(os.path.join(ROOT, "seeds.csv"))
                      if r[0] != "bank"]
        self.kind = {}       # (bank, addr) -> 'code' start map filled by trace
        self.insns = {}      # (bank, addr) -> (len, tpl_kind, target)
        self.code_bytes = set()
        self.targets = {}    # (bank, addr) -> 'code'|'data'
        self.cross = set()
        self.tables = set()  # rst-table vectors
        self.cross_bank = {}
        self.dwords = {}     # (bank, addr) -> target of a table word

    def home(self, addr, bank):
        return 0 if addr < BANK else bank

    def trace(self):
        for b, a in self.seeds:
            if a >= BANK:
                self.cross_bank[a] = b
        self.trace_once(None)
        done = set()
        while True:
            new = []
            for t in sorted(self.cross - done):
                done.add(t)
                b = self.guess_bank(t)
                if b and (b, t) not in self.insns:
                    self.cross_bank[t] = b
                    new.append((b, t))
            if not new:
                break
            self.trace_once(new)

    def guess_bank(self, t):
        """The one switchable bank in which code at t decodes cleanly to a terminator (None if ambiguous)."""
        ok = []
        for b in range(1, self.nbanks):
            pc, o, good = t, off(b, t), False
            for _ in range(24):
                if o + 3 > len(self.data) or self.data[o] == 0xFF:
                    break
                n, tx, k, tg = sm83.decode(self.data, pc, o)
                if tx is None:
                    break
                pc += n
                o += n
                if k in ('retu', 'jpu', 'jru', 'jpind'):
                    good = True
                    break
            if good:
                ok.append(b)
        return ok[0] if len(ok) == 1 else None

    def trace_once(self, extra):
        if extra:
            work = list(extra)
            self.run(work)
            return
        work = [(0, v) for v in VECTORS] + list(self.seeds)
        # rst vectors that begin like a jump-table dispatcher end the trace after each call
        for v in VECTORS[:8]:
            a = v
            if self.data[a] == 0xC3:                      # vector is a jp to the real handler
                a = self.data[a + 1] | self.data[a + 2] << 8
            if 0xE1 in self.data[a:a + 8]:                # pop hl early: rst is followed by a pointer table
                self.tables.add(v)
        self.run(work)

    def run(self, work):
        while work:
            bank, pc = work.pop()
            while True:
                if not (0 <= pc < 0x8000):
                    break
                b = self.home(pc, bank)
                key = (b, pc)
                if key in self.insns:
                    break
                o = off(b, pc)
                if o >= len(self.data):
                    break
                if self.data[o] == 0xFF:      # 0xFF is padding in this ROM, never `rst $38`
                    break
                n, text, kind, tgt = sm83.decode(self.data, pc, o)
                if text is None or any((b, pc + i) in self.code_bytes for i in range(n)):
                    break
                self.insns[key] = (n, kind, tgt)
                for i in range(n):
                    self.code_bytes.add((b, pc + i))
                if kind in ("jr", "jru", "jp", "jpu", "call"):
                    tb = self.home(tgt, bank)
                    if tgt >= 0x8000:
                        pass
                    else:
                        if tgt >= BANK and b == 0:
                            self.cross.add(tgt)
                            tb = None
                        if tb is not None:
                            self.targets[(tb, tgt)] = "code"
                            work.append((tb, tgt))
                elif kind == "rst":
                    self.targets[(0, tgt)] = "code"
                    if tgt in self.tables:
                        self.read_table(b, pc + n, work)
                        break
                if kind in ("jru", "jpu", "retu", "jpind"):
                    break
                pc += n

    def read_table(self, b, addr, work):
        """Words after a table-dispatch rst: take them while they point at plausible code."""
        while addr + 1 < 0x8000 and (b, addr) not in self.code_bytes:
            o = off(b, addr)
            t = self.data[o] | self.data[o + 1] << 8
            to = off(self.home(t, b), t)
            if not (0x150 <= t < 0x8000) or to >= len(self.data) or self.data[to] in (0x00, 0xFF):
                break
            if (b, addr) in self.targets:      # a label means the table ended
                break
            self.dwords[(b, addr)] = t
            self.code_bytes.update({(b, addr), (b, addr + 1)})
            if t >= BANK and b == 0:
                self.cross.add(t)
            else:
                tb = self.home(t, b)
                self.targets[(tb, t)] = "code"
                work.append((tb, t))
            addr += 2

    def label(self, bank):
        def f(t):
            b = self.home(t, bank)
            if bank == 0 and t >= BANK:
                b = self.cross_bank.get(t, 0)
            if t >= 0x8000 or (b, t) not in self.targets and (b, t) not in self.names:
                return f"${t:04x}"
            return self.names.get((b, t)) or (f"L_{b:02x}_{t:04x}")
        return f

    def emit(self, bank):
        base = bank * BANK
        start = 0 if bank == 0 else BANK
        end = start + BANK
        lab = self.label(bank)
        out = []
        if bank == 0:
            out.append('SECTION "bank00", ROM0[$0000]')
        else:
            out.append(f'SECTION "bank{bank:02x}", ROMX[$4000], BANK[{bank}]')
        out.append("")
        pc = start
        while pc < end:
            key = (bank, pc)
            name = None
            if key in self.names:
                name = self.names[key]
            elif key in self.targets:
                name = f"L_{bank:02x}_{pc:04x}" if self.targets[key] == "code" else f"D_{bank:02x}_{pc:04x}"
            if name:
                out.append(f"{name}::" + (f"  ; {self.comments[key]}" if key in self.comments else ""))
            if key in self.dwords:
                out.append("    dw " + lab(self.dwords[key]))
                pc += 2
                continue
            if key in self.insns:
                n, kind, tgt = self.insns[key]
                _, text, _, _ = sm83.decode(self.data, pc, base + pc - start, lab)
                out.append("    " + text)
                pc += n
                continue
            # data run up to 16 bytes, stopping at a label, a code byte or a bank end
            run = [self.data[base + pc - start]]
            q = pc + 1
            while (q < end and len(run) < 16 and (bank, q) not in self.insns and (bank, q) not in self.targets
                   and (bank, q) not in self.names and (bank, q) not in self.dwords and (q & 15) != 0):
                run.append(self.data[base + q - start])
                q += 1
            out.append("    db " + ", ".join(f"${x:02x}" for x in run))
            pc = q
        return "\n".join(out) + "\n"

    def functions(self):
        """Code labels that are call targets or vectors, with the extent up to the next label/data."""
        starts = sorted(k for k, v in self.targets.items() if v == "code")
        res = []
        starts = [k for k in starts if k in self.insns]
        for i, (b, a) in enumerate(starts):
            nxt = starts[i + 1][1] if i + 1 < len(starts) and starts[i + 1][0] == b else 1 << 20
            q = a
            while (b, q) in self.insns and q < nxt:
                n, kind, _ = self.insns[(b, q)]
                q += n
                if kind in ("jru", "jpu", "retu", "jpind"):
                    break
            res.append((b, a, q - a))
        return res


def assemble(rom, sources):
    """Assemble the emitted text with the in-repo encoder and compare with the ROM bytes."""
    labels = {}
    def lookup(t):
        return int(t[1:], 16) if t.startswith("$") else labels.get(t, 0)
    for bank in range(rom.nbanks):             # pass 1: label addresses (labels are global)
        pc = 0 if bank == 0 else BANK
        for ln in sources[bank].splitlines():
            s = ln.split(";")[0].rstrip()
            if not s or s.startswith("SECTION"):
                continue
            if s.endswith(":"):
                labels[s.rstrip(":")] = pc
            elif s.startswith("    db "):
                pc += s.count("$")
            elif s.startswith("    dw "):
                pc += 2
            else:
                pc += len(sm83.encode(s.strip(), pc, lookup))
    built = []
    for bank in range(rom.nbanks):
        pc = 0 if bank == 0 else BANK
        out = bytearray()
        for ln in sources[bank].splitlines():
            s = ln.split(";")[0].rstrip()
            if not s or s.startswith("SECTION") or s.endswith(":"):
                continue
            if s.startswith("    db "):
                v = bytes(int(x.strip()[1:], 16) for x in s[7:].split(","))
            elif s.startswith("    dw "):
                t = lookup(s[7:].strip())
                v = bytes([t & 0xFF, t >> 8])
            else:
                v = sm83.encode(s.strip(), pc, lookup)
            out += v
            pc += len(v)
        built.append(bytes(out))
    return built


def roundtrip(rom, sources):
    ok = True
    for bank, out in enumerate(assemble(rom, sources)):
        want = rom.data[bank * BANK:(bank + 1) * BANK]
        if out != want:
            ok = False
            i = next((i for i, (x, y) in enumerate(zip(out, want)) if x != y), min(len(out), len(want)))
            print(f"bank {bank}: MISMATCH at +{i:#x} (len {len(out)} vs {len(want)})")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default=os.path.join(ROOT, "orig", "painter_momopie.gb"))
    ap.add_argument("--write", action="store_true", help="write src/bank_NN.asm and config/functions.tsv")
    ap.add_argument("--check", action="store_true", help="round-trip the emitted source")
    a = ap.parse_args()
    rom = Rom(a.rom)
    rom.trace()
    src = [rom.emit(b) for b in range(rom.nbanks)]
    code = len(rom.code_bytes)
    print(f"{rom.nbanks} banks, {code} of {len(rom.data)} bytes traced as code ({100 * code / len(rom.data):.1f}%), "
          f"{len(rom.functions())} entry points, {len(rom.cross)} cross-bank targets from bank 0, "
          f"table rsts: {sorted(rom.tables)}")
    ok = True
    if a.check or a.write:
        ok = roundtrip(rom, src)
        print("round trip:", "OK, source reproduces every byte" if ok else "FAILED")
    if a.write:
        if not ok:
            sys.exit(1)
        os.makedirs(os.path.join(ROOT, "src"), exist_ok=True)
        for b, s in enumerate(src):
            open(os.path.join(ROOT, "src", f"bank_{b:02x}.asm"), "w", newline="\n").write(s)
        os.makedirs(os.path.join(ROOT, "config"), exist_ok=True)
        with open(os.path.join(ROOT, "config", "functions.tsv"), "w", newline="\n") as f:
            f.write("bank\taddr\tsize\tname\n")
            for b, ad, sz in rom.functions():
                f.write(f"{b}\t{ad:04x}\t{sz}\t{rom.names.get((b, ad), f'L_{b:02x}_{ad:04x}')}\n")
        os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
        with open(os.path.join(ROOT, "build", "cross_bank_candidates.tsv"), "w") as f:
            for t in sorted(rom.cross):
                f.write(f"{t:04x}\n")
        print("wrote src/bank_*.asm, config/functions.tsv")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

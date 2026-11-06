#!/usr/bin/env python3
"""Trace-disassemble the ROM into RGBDS source (src/bank_NN.asm) and prove the source reproduces the ROM.

    python tools/gb_dis.py [--rom orig/painter_momopie.gb] [--write] [--check]

Code is found by recursive descent from the vectors and entry point plus every call/jump target; everything else is
emitted as `db`. Names come from labels.csv (bank,addr,name,comment; bank = ROM bank 0-3, addr = CPU address in hex).
Banks 1-3 are mapped at $4000: a jump/call from bank N to $4000+ stays in bank N; from bank 0 the target bank is
unknown, so those targets are listed in build/cross_bank_candidates.tsv and marked by hand (labels.csv `bank,addr,...`
with the entry in `seeds.csv`).
"""
import argparse, csv, hashlib, os, re, sys
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
        self.consts = {}     # name -> value from src/*.inc (DEF name EQU $xxxx)
        for inc in ("hardware.inc", "constants.inc"):
            pth = os.path.join(ROOT, "src", inc)
            if os.path.exists(pth):
                for ln in open(pth, encoding="utf-8"):
                    m = re.match(r"\s*DEF\s+(\w+)\s+EQU\s+\$([0-9a-fA-F]+)", ln)
                    if m:
                        self.consts[m[1]] = int(m[2], 16)
        self.by_value = {v: k for k, v in self.consts.items()}
        self.kind = {}       # (bank, addr) -> 'code' start map filled by trace
        self.insns = {}      # (bank, addr) -> (len, tpl_kind, target)
        self.code_bytes = set()
        self.targets = {}    # (bank, addr) -> 'code'|'data'
        self.cross = set()
        self.tables = set()  # rst-table vectors
        self.cross_bank = {}
        self.ptables = [(int(r[0]), int(r[1], 16), int(r[2]), int(r[3])) for r in read_csv(os.path.join(ROOT, "ptables.csv"))
                        if r[0] != "bank"]
        self.table_len = {(int(r[0]), int(r[1], 16)): int(r[2]) for r in read_csv(os.path.join(ROOT, "tables.csv"))
                          if r[0] != "bank"}
        self.dwords = {}     # (bank, addr) -> target of a table word

    def home(self, addr, bank):
        return 0 if addr < BANK else bank

    def trace(self):
        for b, a in self.seeds:
            self.targets[(b, a)] = "code"
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
            if new:
                self.trace_once(new)
                continue
            if not self.orphan_scan() and not self.imm_scan() and not self.table_scan():
                break
        self.data_labels()
        self.pointer_tables()

    TERM = ("retu", "jpu", "jru", "jpind")

    def plausible(self, b, start):
        """Does unclassified data at (b,start) look like a routine that ends in ret/jp/jr?"""
        pc, o, n_ins, nops = start, off(b, start), 0, 0
        while n_ins < 60:
            if o + 3 > len(self.data) or (b, pc) in self.code_bytes and (b, pc) not in self.insns:
                return False
            if (b, pc) in self.insns:
                return n_ins >= 3
            if self.data[o] == 0xFF:
                return False
            n, tx, k, tg = sm83.decode(self.data, pc, o)
            if tx is None:
                return False
            op = self.data[o]
            w = self.data[o + 1] | self.data[o + 2] << 8
            if op in (0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0x76):   # the game only uses rst $00; halt never appears
                return False
            if (op == 0xEA and w < 0x8000 and not 0x2000 <= w < 0x4000) or (op == 0xFA and w < 0x8000)                     or (op == 0x08 and w < 0xC000):
                return False
            nops = nops + 1 if self.data[o] == 0 else 0
            if nops > 1 or (n_ins == 0 and self.data[o] in (0x00,)):
                return False
            if k in ("jp", "jpu", "call"):
                if tg >= 0x8000 or tg < 0x150 and tg % 8:
                    return False
                tb = self.home(tg, b)
                if (tb, tg) in self.code_bytes and (tb, tg) not in self.insns:
                    return False          # lands inside another instruction
            if k in ("jr", "jru") and not (0 <= tg < 0x8000):
                return False
            pc += n
            o += n
            n_ins += 1
            if k in self.TERM:
                return n_ins >= 3
        return False

    def orphan_scan(self):
        """Find routines nothing calls directly (they follow a terminator or a table) and trace them."""
        cands = set()
        for (b, pc), (n, kind, tgt) in self.insns.items():
            if kind in self.TERM and (b, pc + n) not in self.code_bytes:
                if kind == "jpu" and tgt in (0x0AAA, 0x0AAF):     # tail call of a lookup: a table follows
                    continue
                cands.add((b, pc + n))
        for (b, a) in self.dwords:
            if (b, a + 2) not in self.code_bytes:
                cands.add((b, a + 2))
        found = 0
        for b, a in sorted(cands):
            if not ((a < BANK) if b == 0 else (BANK <= a < 2 * BANK)):
                continue
            if b >= 2:
                continue
            if self.plausible(b, a) and self.try_run(b, a):
                found += 1
        return found

    def imm_scan(self):
        """`ld bc/de/hl, imm16` whose value is the start of a plausible routine: a code pointer passed in a register."""
        found = 0
        for (b, pc), (n, kind, tgt) in sorted(self.insns.items()):
            o = off(b, pc)
            if self.data[o] not in (0x01, 0x11, 0x21):
                continue
            t = self.data[o + 1] | self.data[o + 2] << 8
            if t < 0x150 or t >= 0x8000:
                continue
            if t >= BANK and b == 0:
                continue
            tb = self.home(t, b)
            if tb >= 2 and b == 0:
                continue
            if (tb, t) in self.code_bytes:
                continue
            if self.used_as_data_pointer(b, pc + n):
                continue
            if self.plausible(tb, t) and self.try_run(tb, t):
                found += 1
        return found

    def used_as_data_pointer(self, b, pc):
        """After `ld rr, imm16`: a table lookup or an indexed read means the immediate points at data."""
        for _ in range(5):
            if (b, pc) not in self.insns:
                return False
            n, kind, tgt = self.insns[(b, pc)]
            op = self.data[off(b, pc)]
            if kind in ("call", "jpu", "jp") and tgt in (0x0AAA, 0x0AAF, 0x0627, 0x0505, 0x04F1):
                return True
            if op in (0x09, 0x19, 0x29, 0x7E, 0x2A, 0x46, 0x4E, 0x56, 0x5E, 0x66, 0x6E, 0x1A):
                return True
            if kind in ("jpu", "retu", "jru", "jpind"):
                return False
            pc += n
        return False

    def pointer_tables(self):
        """Tables listed in ptables.csv: emit as `dw label` and label what they point at as data."""
        for b, a, n, tbank in self.ptables:
            for i in range(n):
                q = a + 2 * i
                o = off(b, q)
                t = self.data[o] | self.data[o + 1] << 8
                self.dwords[(b, q)] = t
                self.code_bytes.update({(b, q), (b, q + 1)})
                tb = tbank if (tbank and t >= BANK) else self.home(t, b)
                if (tb, t) not in self.code_bytes and (tb, t) not in self.targets:
                    self.targets[(tb, t)] = "data"
                if b == 0 and t >= BANK:
                    self.cross_bank[t] = tb

    def data_labels(self):
        """Label ROM data that code points at with `ld bc/de/hl, imm16` (and `ld [x], imm` style loads of the same)."""
        n = 0
        for (b, pc) in sorted(self.insns):
            o = off(b, pc)
            if self.data[o] not in (0x11, 0x21):      # not BC: it usually holds a length
                continue
            t = self.data[o + 1] | self.data[o + 2] << 8
            if not (0x150 <= t < 0x8000) or (b == 0 and t >= BANK):
                continue
            tb = self.home(t, b)
            if (tb, t) in self.code_bytes or (tb, t) in self.targets:
                continue
            self.targets[(tb, t)] = "data"
            n += 1
        return n

    def table_scan(self):
        """Runs of >= 4 words that all point at code (known instruction starts or plausible routines): jump tables."""
        found = 0
        for b in (0, 1):
            lo, hi = (0x150, BANK) if b == 0 else (BANK, 2 * BANK)
            a = lo
            while a + 1 < hi:
                if (b, a) in self.code_bytes or (b, a + 1) in self.code_bytes:
                    a += 1
                    continue
                chain = []
                q = a
                while q + 1 < hi and (b, q) not in self.code_bytes and (b, q + 1) not in self.code_bytes:
                    o = off(b, q)
                    t = self.data[o] | self.data[o + 1] << 8
                    tb = self.home(t, b)
                    if not (0x150 <= t < 0x8000) or (b == 0 and t >= BANK) or tb >= 2:
                        break
                    if (tb, t) in self.insns and self.targets.get((tb, t)) == "code":
                        chain.append((q, t))
                    elif (tb, t) not in self.code_bytes and self.plausible(tb, t):
                        chain.append((q, t))
                    else:
                        break
                    q += 2
                if len(chain) >= 4:
                    snap = (dict(self.insns), set(self.code_bytes), dict(self.targets), dict(self.dwords), set(self.cross))
                    ok = True
                    for q, t in chain:
                        tb = self.home(t, b)
                        if (tb, t) not in self.insns and not self.try_run(tb, t):
                            ok = False
                            break
                    if ok:
                        for q, t in chain:
                            self.dwords[(b, q)] = t
                            self.code_bytes.update({(b, q), (b, q + 1)})
                            self.targets[(self.home(t, b), t)] = "code"
                        found += 1
                        a = chain[-1][0] + 2
                        continue
                    self.rollback(snap)
                a += 1
        return found

    def try_run(self, b, a):
        """Trace (b,a); keep it only if every branch lands on an instruction start."""
        snap = (dict(self.insns), set(self.code_bytes), dict(self.targets), dict(self.dwords), set(self.cross))
        self.targets[(b, a)] = "code"
        self.run([(b, a)])
        cb = dict(self.cross_bank)
        while True:
            pending = self.cross - set(self.cross_bank)
            if not pending:
                break
            for t in sorted(pending):
                # bank 1 is the only switchable code bank (banks 2-3 are graphics), so cross-bank calls enter it
                if (1, t) in self.insns:
                    self.cross_bank[t] = 1
                    self.targets[(1, t)] = "code"
                    continue
                if not self.plausible(1, t):
                    self.cross_bank = cb
                    return self.rollback(snap)
                self.cross_bank[t] = 1
                self.targets[(1, t)] = "code"
                self.run([(1, t)])
        for key in set(self.insns) - set(snap[0]):
            n, kind, tg = self.insns[key]
            if kind in ("jr", "jru", "jp", "jpu", "call"):
                if tg >= 0x8000:
                    return self.rollback(snap)
                if key[0] == 0 and tg >= BANK:
                    continue
                if (self.home(tg, key[0]), tg) not in self.insns:
                    return self.rollback(snap)
        return True

    def rollback(self, snap):
        self.insns, self.code_bytes, self.targets, self.dwords, self.cross = snap
        self.cross_bank = {k: v for k, v in self.cross_bank.items() if k in self.cross or (v, k) in self.targets}
        return False

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
        left = self.table_len.get((b, addr), 1 << 20)
        while left > 0 and addr + 1 < 0x8000 and (b, addr) not in self.code_bytes:
            left -= 1
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
            return self.names.get((b, t)) or (f"{'D' if self.targets.get((b, t)) == 'data' else 'L'}_{b:02x}_{t:04x}")
        return f

    def emit(self, bank):
        base = bank * BANK
        start = 0 if bank == 0 else BANK
        end = start + BANK
        lab = self.label(bank)
        out = ['INCLUDE "src/hardware.inc"', 'INCLUDE "src/constants.inc"', ""]
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
                if self.data[base + pc - start] in (0x11, 0x21) and not (bank == 0 and
                        (self.data[base + pc - start + 1] | self.data[base + pc - start + 2] << 8) >= BANK):
                    v = self.data[base + pc - start + 1] | self.data[base + pc - start + 2] << 8
                    if 0x150 <= v < 0x8000 and self.targets.get((self.home(v, bank), v)) == "data":
                        text = text.rsplit("$", 1)[0] + lab(v)
                if kind not in ("jr", "jru", "jp", "jpu", "call"):
                    text = re.sub(r"\$([0-9a-f]{4})", lambda m: self.by_value.get(int(m[1], 16), m[0]), text)
                out.append("    " + text)
                pc += n
                continue
            # data: one INCBIN of the user's own ROM up to the next label, instruction or table word
            q = pc + 1
            while (q < end and (bank, q) not in self.insns and (bank, q) not in self.targets
                   and (bank, q) not in self.names and (bank, q) not in self.dwords):
                q += 1
            out.append(f'    INCBIN "orig/painter_momopie.gb", ${base + pc - start:05x}, {q - pc}')
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


def unname(rom, s):
    if not rom.consts:
        return s
    return re.sub(r"[A-Za-z_]\w*", lambda m: f"${rom.consts[m[0]]:04x}" if m[0] in rom.consts else m[0], s)


def assemble(rom, sources):
    """Assemble the emitted text with the in-repo encoder and compare with the ROM bytes."""
    labels = {}
    def lookup(t):
        return int(t[1:], 16) if t.startswith("$") else labels.get(t, 0)
    for bank in range(rom.nbanks):             # pass 1: label addresses (labels are global)
        pc = 0 if bank == 0 else BANK
        for ln in sources[bank].splitlines():
            s = ln.split(";")[0].rstrip()
            if not s or s.startswith(("SECTION", "INCLUDE")):
                continue
            if s.endswith(":"):
                labels[s.rstrip(":")] = pc
            elif s.startswith("    db "):
                pc += s.count("$")
            elif s.startswith("    dw "):
                pc += 2
            elif s.startswith("    INCBIN"):
                pc += int(s.rsplit(",", 1)[1])
            else:
                pc += len(sm83.encode(unname(rom, s.strip()), pc, lookup))
    built = []
    for bank in range(rom.nbanks):
        pc = 0 if bank == 0 else BANK
        out = bytearray()
        for ln in sources[bank].splitlines():
            s = ln.split(";")[0].rstrip()
            if not s or s.startswith(("SECTION", "INCLUDE")) or s.endswith(":"):
                continue
            if s.startswith("    db "):
                v = bytes(int(x.strip()[1:], 16) for x in s[7:].split(","))
            elif s.startswith("    dw "):
                t = lookup(s[7:].strip())
                v = bytes([t & 0xFF, t >> 8])
            elif s.startswith("    INCBIN"):
                _, o, n = s.split(",")
                o = int(o.strip()[1:], 16)
                v = rom.data[o:o + int(n)]
            else:
                v = sm83.encode(unname(rom, s.strip()), pc, lookup)
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

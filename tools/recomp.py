#!/usr/bin/env python3
"""Static recompiler: turns the traced SM83 routines of the user's ROM into C (build/recomp/game.c).

    python tools/recomp.py [--out build/recomp/game.c]

One C function per routine (config/functions.tsv roots); branches inside a routine become `goto`; jumps between routines are tail
calls (the function returns the next function, `gb_run` trampolines); `call` runs a nested `gb_run`. Backward branches call
BACKEDGE() so waiting loops let the clock, PPU and interrupts run. The output contains code derived from the game, so it is
generated on the user's machine and never committed (build/ is ignored). Data is read from the user's ROM at run time.
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import gb_dis, sm83

ROOT = gb_dis.ROOT
BANK = gb_dis.BANK
GET = ["B", "C", "D", "E_", "H", "L", "rd(HL())", "A"]
COND = ["!ZF()", "ZF()", "!CF()", "CF()"]


def setr(i, v):
    if i == 6:
        return f"wr(HL(), {v});"
    return f"{GET[i]} = {v};"


def cyc(tpl):
    if tpl.startswith("call"):
        return 24
    if tpl == "jp hl":
        return 4
    if tpl.startswith("jp"):
        return 16
    if tpl.startswith("jr"):
        return 12
    if tpl.startswith("ret"):
        return 16
    if tpl.startswith("push"):
        return 16
    if tpl.startswith("pop"):
        return 12
    if tpl.startswith("rst"):
        return 16
    n = 4
    if "n8" in tpl or "a8" in tpl or "e8" in tpl:
        n = 8
    if "n16" in tpl:
        n = 12
    if "a16" in tpl:
        n = 16
    if "[hl" in tpl or "[bc]" in tpl or "[de]" in tpl or "[c]" in tpl:
        n += 4
    if "[a8]" in tpl or "a8" in tpl:
        n = 12
    return n


class Recomp:
    def __init__(self, rom):
        self.rom = rom
        self.funcs = {}          # (bank, addr) -> (size)
        roots = sorted((b, a) for b, a, sz in rom.functions())
        for i, (b, a) in enumerate(roots):
            nxt = roots[i + 1][1] if i + 1 < len(roots) and roots[i + 1][0] == b else (BANK if b == 0 else 2 * BANK)
            self.funcs[(b, a)] = nxt - a      # extent runs to the next routine; bytes that are not instructions are skipped
        self.errors = []
        ov = os.path.join(ROOT, "port", "overrides.txt")
        self.overrides = {ln.strip() for ln in open(ov)} if os.path.exists(ov) else set()

    def fname(self, b, a):
        return f"F_{b}_{a:04X}"

    def target_of(self, b, tgt):
        """Bank in which a branch target at CPU address tgt lives, for an instruction in bank b."""
        if b == 0 and tgt >= BANK:
            return self.rom.cross_bank.get(tgt, 1)
        return 0 if tgt < BANK else b

    def jump(self, b, pc, fb, fa, fsz, tgt, cond):
        """C for a jr/jp to CPU address tgt from a routine (fb, fa, fsz)."""
        tb = self.target_of(b, tgt)
        inside = tb == fb and fa <= tgt < fa + fsz and (tb, tgt) in self.rom.insns
        if inside:
            body = f"{{ {'BACKEDGE(); ' if tgt <= pc else ''}goto L_{tb}_{tgt:04X}; }}"
        elif (tb, tgt) in self.funcs:
            body = f"return (void *){self.fname(tb, tgt)};"
        else:
            self.errors.append((fb, fa, pc, tgt))
            body = f'gb_fatal("jump into the middle of a routine", 0x{tgt:04X});'
        return f"if ({cond}) {body}" if cond else body

    def insn(self, b, pc, fb, fa, fsz):
        rom = self.rom
        d = rom.data
        o = gb_dis.off(b, pc)
        op = d[o]
        n8 = d[o + 1] if o + 1 < len(d) else 0
        n16 = n8 | (d[o + 2] << 8 if o + 2 < len(d) else 0)
        out = []
        if op == 0xCB:
            x = n8
            r = x & 7
            grp = x >> 6
            k = (x >> 3) & 7
            if grp == 0:
                out.append(setr(r, f"cb_rot({k}, {GET[r]})"))
            elif grp == 1:
                out.append(f"cb_bit({k}, {GET[r]});")
            elif grp == 2:
                out.append(setr(r, f"{GET[r]} & 0x{(~(1 << k)) & 0xFF:02X}"))
            else:
                out.append(setr(r, f"{GET[r]} | 0x{1 << k:02X}"))
            return out, 16 if r == 6 and grp != 1 else (12 if r == 6 else 8), 2
        tpl = sm83.OPS.get(op)
        if tpl is None:
            return [f'gb_fatal("illegal opcode", 0x{op:02X});'], 4, 1
        length = sm83.length(tpl)
        cy = cyc(tpl)
        hi = op >> 6
        if hi == 1 and op != 0x76:
            out.append(setr((op >> 3) & 7, GET[op & 7]))
        elif op == 0x76:
            out.append('gb_fatal("halt", 0);')
        elif hi == 2 or (hi == 3 and (op & 7) == 6):
            v = GET[op & 7] if hi == 2 else f"0x{n8:02X}"
            k = (op >> 3) & 7
            out.append(["alu_add(%s, 0);", "alu_add(%s, CF() ? 1 : 0);", "alu_sub(%s, 0);", "alu_sub(%s, CF() ? 1 : 0);",
                        "alu_and(%s);", "alu_xor(%s);", "alu_or(%s);", "alu_cp(%s);"][k] % v)
        elif tpl.startswith("ld ") and tpl.endswith(", n8") and (op & 7) == 6:
            out.append(setr((op >> 3) & 7, f"0x{n8:02X}"))
        elif op in (0x01, 0x11, 0x21, 0x31):
            i = (op >> 4) & 3
            out.append((f"SET_{['BC', 'DE', 'HL'][i]}(0x{n16:04X});" if i < 3 else f"r.sp = 0x{n16:04X};"))
        elif tpl.startswith("add hl,"):
            i = (op >> 4) & 3
            out.append(f"add_hl({['BC()', 'DE()', 'HL()', 'r.sp'][i]});")
        elif tpl.startswith("inc ") and op & 7 == 3:
            i = (op >> 4) & 3
            out.append(f"SET_{['BC', 'DE', 'HL'][i]}({['BC', 'DE', 'HL'][i]}() + 1);" if i < 3 else "r.sp++;")
        elif tpl.startswith("dec ") and op & 7 == 3:
            i = (op >> 4) & 3
            out.append(f"SET_{['BC', 'DE', 'HL'][i]}({['BC', 'DE', 'HL'][i]}() - 1);" if i < 3 else "r.sp--;")
        elif op & 7 == 4 and hi == 0:
            i = (op >> 3) & 7
            out.append(setr(i, f"inc8({GET[i]})"))
        elif op & 7 == 5 and hi == 0:
            i = (op >> 3) & 7
            out.append(setr(i, f"dec8({GET[i]})"))
        elif op == 0x02: out.append("wr(BC(), A);")
        elif op == 0x12: out.append("wr(DE(), A);")
        elif op == 0x22: out.append("wr(HL(), A); SET_HL(HL() + 1);")
        elif op == 0x32: out.append("wr(HL(), A); SET_HL(HL() - 1);")
        elif op == 0x0A: out.append("A = rd(BC());")
        elif op == 0x1A: out.append("A = rd(DE());")
        elif op == 0x2A: out.append("A = rd(HL()); SET_HL(HL() + 1);")
        elif op == 0x3A: out.append("A = rd(HL()); SET_HL(HL() - 1);")
        elif op == 0x08: out.append(f"wr(0x{n16:04X}, r.sp & 255); wr(0x{n16 + 1:04X}, r.sp >> 8);")
        elif op == 0x07: out.append("op_rlca();")
        elif op == 0x0F: out.append("op_rrca();")
        elif op == 0x17: out.append("op_rla();")
        elif op == 0x1F: out.append("op_rra();")
        elif op == 0x27: out.append("op_daa();")
        elif op == 0x2F: out.append("A = ~A; F = (F & 0x90) | 0x60;")
        elif op == 0x37: out.append("F = (F & 0x80) | 0x10;")
        elif op == 0x3F: out.append("F = (F & 0x80) | (CF() ? 0 : 0x10);")
        elif op == 0x10: out.append('gb_fatal("stop", 0);')
        elif op == 0x00: pass
        elif op in (0x18, 0x20, 0x28, 0x30, 0x38):
            tgt = (pc + 2 + (n8 - 256 if n8 > 127 else n8)) & 0xFFFF
            out.append(self.jump(b, pc, fb, fa, fsz, tgt, None if op == 0x18 else COND[(op >> 3) & 3]))
        elif op in (0xC3, 0xC2, 0xCA, 0xD2, 0xDA):
            out.append(self.jump(b, pc, fb, fa, fsz, n16, None if op == 0xC3 else COND[(op >> 3) & 3]))
        elif op == 0xE9:
            out.append("return (void *)gb_dispatch(HL());")
        elif op in (0xCD, 0xC4, 0xCC, 0xD4, 0xDC):
            if n16 == 0xFF80:
                call = "gb_dma_routine(); r.sp += 0;"
            else:
                tb = self.target_of(b, n16)
                if (tb, n16) not in self.funcs:
                    self.errors.append((fb, fa, pc, n16))
                    call = f'gb_fatal("call into the middle of a routine", 0x{n16:04X});'
                else:
                    call = f"CALL({self.fname(tb, n16)});"
            out.append(call if op == 0xCD else f"if ({COND[(op >> 3) & 3]}) {{ {call} }}")
        elif op == 0xC9: out.append("r.sp += 2; return 0;")
        elif op == 0xD9: out.append("ime = 1; r.sp += 2; return 0;")
        elif op in (0xC0, 0xC8, 0xD0, 0xD8): out.append(f"if ({COND[(op >> 3) & 3]}) {{ r.sp += 2; return 0; }}")
        elif op == 0xC7:                       # rst $00: word jump table follows
            ents = []
            q = pc + 1
            while (b, q) in rom.dwords:
                ents.append(rom.dwords[(b, q)])
                q += 2
            names = ", ".join(f"(fn_t){self.fname(self.target_of(b, t), t)}" for t in ents)
            out.append(f"{{ static const fn_t tbl[] = {{ {names} }}; if (A >= {len(ents)}) gb_fatal(\"jump table index\", A); return (void *)tbl[A]; }}")
            length = 1 + 2 * len(ents)
        elif op & 0xC7 == 0xC7:
            out.append(f'gb_fatal("unsupported rst", 0x{op & 0x38:02X});')
        elif op == 0xE0: out.append(f"wr(0x{0xFF00 + n8:04X}, A);")
        elif op == 0xF0: out.append(f"A = rd(0x{0xFF00 + n8:04X});")
        elif op == 0xE2: out.append("wr(0xFF00 + C, A);")
        elif op == 0xF2: out.append("A = rd(0xFF00 + C);")
        elif op == 0xEA: out.append(f"wr(0x{n16:04X}, A);")
        elif op == 0xFA: out.append(f"A = rd(0x{n16:04X});")
        elif op == 0xE8: out.append(f"r.sp = sp_plus({n8 - 256 if n8 > 127 else n8});")
        elif op == 0xF8: out.append(f"SET_HL(sp_plus({n8 - 256 if n8 > 127 else n8}));")
        elif op == 0xF9: out.append("r.sp = HL();")
        elif op == 0xF3: out.append("ime = 0;")
        elif op == 0xFB: out.append("ime = 1;")
        elif op & 0xCF == 0xC1:
            i = (op >> 4) & 3
            out.append(f"SET_{['BC', 'DE', 'HL'][i]}(pop16());" if i < 3 else "{ uint16_t v_ = pop16(); A = v_ >> 8; F = v_ & 0xF0; }")
        elif op & 0xCF == 0xC5:
            i = (op >> 4) & 3
            out.append(f"push16({['BC()', 'DE()', 'HL()', '(uint16_t)(A << 8 | F)'][i]});")
        else:
            out.append(f'gb_fatal("untranslated opcode", 0x{op:02X});')
        return out, cy, length

    def function(self, b, a, sz):
        rom = self.rom
        nm = rom.names.get((b, a))
        if nm in self.overrides:                 # hardware dependent routine: replaced by native code (port/gb_native.c)
            return (f"void *gb_native_{nm}(void);\n"
                    f"void *{self.fname(b, a)}(void) {{ void *next_ = gb_native_{nm}(); if (next_) return next_; r.sp += 2; return 0; }}")
        L = [f"void *{self.fname(b, a)}(void) {{"]
        pc = a
        end = a + sz
        branch_targets = set()
        # labels for every instruction in the extent that some branch in this routine targets
        q = a
        while q < end:
            if (b, q) not in rom.insns:
                q += 1
                continue
            n, kind, tgt = rom.insns[(b, q)]
            if kind in ("jr", "jru", "jp", "jpu") and a <= tgt < end:
                branch_targets.add(tgt)
            q += n
        last_kind = None
        while pc < end:
            if (b, pc) not in rom.insns:
                pc += 1
                continue
            n, kind, tgt = rom.insns[(b, pc)]
            if pc in branch_targets:
                L.append(f"L_{b}_{pc:04X}:;")
            lines, cy, length = self.insn(b, pc, b, a, sz)
            for ln in lines:
                L.append("    " + ln)
            last_kind = kind
            pc += max(n, length)
        if last_kind not in ("jru", "jpu", "retu", "jpind", "rst"):
            nxt = (b, pc)
            if nxt in self.funcs:
                L.append(f"    return (void *){self.fname(*nxt)};")
            else:
                L.append('    gb_fatal("fell off the end of a routine", 0);')
        L.append("    return 0;")
        L.append("}")
        return "\n".join(L)

    def generate(self):
        out = ['/* Generated by tools/recomp.py from the user\'s ROM. Do not commit. */', '#include "gb_rt.h"', "",
               "#pragma GCC diagnostic ignored \"-Wunused-label\"", ""]
        for (b, a) in sorted(self.funcs):
            out.append(f"void *{self.fname(b, a)}(void);")
        out.append("")
        for (b, a), sz in sorted(self.funcs.items()):
            out.append(self.function(b, a, sz))
            out.append("")
        out.append("typedef struct { uint16_t addr; uint8_t bank; fn_t fn; } Entry;")
        out.append("const Entry gb_entries[] = {")
        for (b, a) in sorted(self.funcs):
            out.append(f"    {{ 0x{a:04X}, {b}, (fn_t){self.fname(b, a)} }},")
        out.append("};")
        out.append(f"const int gb_nentries = {len(self.funcs)};")
        vec = []
        for v in (0x40, 0x48, 0x50, 0x58, 0x60):
            vec.append(f"(fn_t){self.fname(0, v)}" if (0, v) in self.funcs else "0")
        out.append(f"fn_t gb_vectors[5] = {{ {', '.join(vec)} }};")
        out.append(f"void gb_game_main(void) {{ gb_reset_state(); gb_run((fn_t){self.fname(0, 0x100)}); }}")
        return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default=os.path.join(ROOT, "orig", "painter_momopie.gb"))
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "recomp", "game.c"))
    a = ap.parse_args()
    rom = gb_dis.Rom(a.rom)
    rom.trace()
    rc = Recomp(rom)
    text = rc.generate()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    open(a.out, "w", newline="\n").write(text)
    print(f"{len(rc.funcs)} routines -> {a.out}; {len(rc.errors)} jumps into the middle of a routine")
    for e in rc.errors[:20]:
        print("  routine %d:%04x  pc %04x -> %04x" % e)


if __name__ == "__main__":
    main()

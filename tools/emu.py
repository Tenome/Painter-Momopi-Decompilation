#!/usr/bin/env python3
"""Minimal headless Game Boy (DMG, MBC1) interpreter for reverse engineering. Not cycle exact.

    python tools/emu.py --frames 600 --press 120:start:5 --shot 300 --shot 600 [--rom ...]

Use it as a library: `from emu import GB`; gb.run_frame(); gb.mem[...]; gb.render() -> 160x144 list of shade ints.
--press FRAME:BUTTON:HOLD presses a button (a b select start right left up down) from FRAME for HOLD frames.
--shot N writes build/shots/frame_NNNN.png (needs Pillow). --trace-modes prints each change of the game-mode byte.
"""
import argparse, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BTN = {"right": 0x01, "left": 0x02, "up": 0x04, "down": 0x08, "a": 0x10, "b": 0x20, "select": 0x40, "start": 0x80}


class GB:
    def __init__(self, rom):
        self.rom = rom
        self.nb = len(rom) // 0x4000
        self.bank = 1
        self.vram = bytearray(0x2000)
        self.wram = bytearray(0x2000)
        self.oam = bytearray(0xA0)
        self.hram = bytearray(0x80)
        self.io = bytearray(0x80)
        self.a = 0x01
        self.f = 0xB0
        self.b, self.c, self.d, self.e, self.h, self.l = 0, 0x13, 0, 0xD8, 0x01, 0x4D
        self.sp, self.pc = 0xFFFE, 0x100
        self.ime = False
        self.halted = False
        self.ie = 0
        self.cyc = 0
        self.line_cyc = 0
        self.joy = 0           # pressed bits (BTN values)
        self.serial_t = 0
        self.frame = 0
        self.io[0x40] = 0x91
        self.io[0x47] = 0xFC
        self.io[0x00] = 0xCF
        self.writes = []       # optional (pc, addr, val) log
        self.watch = set()
        self.breaks = set()    # pcs to log
        self.hits = []         # (frame, pc, a)

    # ---- memory ----
    def rd(self, a):
        if a < 0x4000:
            return self.rom[a]
        if a < 0x8000:
            return self.rom[(self.bank % self.nb) * 0x4000 + a - 0x4000]
        if a < 0xA000:
            return self.vram[a - 0x8000]
        if a < 0xC000:
            return 0xFF
        if a < 0xE000:
            return self.wram[a - 0xC000]
        if a < 0xFE00:
            return self.wram[a - 0xE000]
        if a < 0xFEA0:
            return self.oam[a - 0xFE00]
        if a < 0xFF00:
            return 0xFF
        if a < 0xFF80:
            r = a - 0xFF00
            if r == 0:
                sel = self.io[0]
                v = 0xCF
                if not sel & 0x10:
                    v &= ~(self.joy & 0x0F) & 0xFF
                if not sel & 0x20:
                    v &= ~((self.joy >> 4) & 0x0F) & 0xFF
                return v
            if r == 0x44:
                return self.ly()
            if r == 0x41:
                ly = self.ly()
                mode = 1 if ly >= 144 else (2 if self.line_cyc < 80 else (3 if self.line_cyc < 252 else 0))
                return (self.io[0x41] & 0xF8) | mode | 0x80
            if r == 0x04:
                return (self.cyc >> 8) & 0xFF
            if r == 0x0F:
                return self.io[0x0F] | 0xE0
            return self.io[r]
        if a < 0xFFFF:
            return self.hram[a - 0xFF80]
        return self.ie

    def ly(self):
        return self.io[0x44]

    def wr(self, a, v):
        v &= 0xFF
        if a in self.watch:
            self.writes.append((self.pc, a, v))
        if a < 0x8000:
            if 0x2000 <= a < 0x4000:
                self.bank = (v & 0x1F) or 1
            return
        if a < 0xA000:
            self.vram[a - 0x8000] = v
        elif a < 0xC000:
            pass
        elif a < 0xE000:
            self.wram[a - 0xC000] = v
        elif a < 0xFE00:
            self.wram[a - 0xE000] = v
        elif a < 0xFEA0:
            self.oam[a - 0xFE00] = v
        elif a < 0xFF00:
            pass
        elif a < 0xFF80:
            r = a - 0xFF00
            if r == 0x46:
                src = v << 8
                for i in range(0xA0):
                    self.oam[i] = self.rd(src + i)
            elif r == 0x04:
                self.cyc = 0
            elif r == 0x02:
                self.io[2] = v
                if v & 0x81 == 0x81:
                    self.serial_t = 4096
            elif r == 0x44:
                pass
            elif r == 0x00:
                self.io[0] = v & 0x30
            else:
                self.io[r] = v
        elif a < 0xFFFF:
            self.hram[a - 0xFF80] = v
        else:
            self.ie = v

    def rd16(self, a):
        return self.rd(a) | self.rd((a + 1) & 0xFFFF) << 8

    def push(self, v):
        self.sp = (self.sp - 1) & 0xFFFF
        self.wr(self.sp, v >> 8)
        self.sp = (self.sp - 1) & 0xFFFF
        self.wr(self.sp, v & 0xFF)

    def pop(self):
        v = self.rd16(self.sp)
        self.sp = (self.sp + 2) & 0xFFFF
        return v

    # ---- registers ----
    def get8(self, i):
        if i == 0: return self.b
        if i == 1: return self.c
        if i == 2: return self.d
        if i == 3: return self.e
        if i == 4: return self.h
        if i == 5: return self.l
        if i == 6: return self.rd(self.h << 8 | self.l)
        return self.a

    def set8(self, i, v):
        v &= 0xFF
        if i == 0: self.b = v
        elif i == 1: self.c = v
        elif i == 2: self.d = v
        elif i == 3: self.e = v
        elif i == 4: self.h = v
        elif i == 5: self.l = v
        elif i == 6: self.wr(self.h << 8 | self.l, v)
        else: self.a = v

    def get16(self, i):
        if i == 0: return self.b << 8 | self.c
        if i == 1: return self.d << 8 | self.e
        if i == 2: return self.h << 8 | self.l
        return self.sp

    def set16(self, i, v):
        v &= 0xFFFF
        if i == 0: self.b, self.c = v >> 8, v & 0xFF
        elif i == 1: self.d, self.e = v >> 8, v & 0xFF
        elif i == 2: self.h, self.l = v >> 8, v & 0xFF
        else: self.sp = v

    def cond(self, i):
        f = self.f
        return (not f & 0x80, bool(f & 0x80), not f & 0x10, bool(f & 0x10))[i]

    def alu(self, op, v):
        a, f = self.a, 0
        if op == 0 or op == 1:       # add / adc
            c = 1 if op == 1 and self.f & 0x10 else 0
            r = a + v + c
            f = (0x20 if (a & 15) + (v & 15) + c > 15 else 0) | (0x10 if r > 255 else 0)
            self.a = r & 0xFF
            f |= 0x80 if self.a == 0 else 0
        elif op in (2, 3, 7):        # sub / sbc / cp
            c = 1 if op == 3 and self.f & 0x10 else 0
            r = a - v - c
            f = 0x40 | (0x20 if (a & 15) - (v & 15) - c < 0 else 0) | (0x10 if r < 0 else 0)
            if (r & 0xFF) == 0:
                f |= 0x80
            if op != 7:
                self.a = r & 0xFF
        elif op == 4:
            self.a = a & v
            f = 0x20 | (0x80 if self.a == 0 else 0)
        elif op == 5:
            self.a = a ^ v
            f = 0x80 if self.a == 0 else 0
        else:
            self.a = a | v
            f = 0x80 if self.a == 0 else 0
        self.f = f

    def cb(self, op):
        r = op & 7
        v = self.get8(r)
        grp = op >> 6
        if grp == 1:
            self.f = (self.f & 0x10) | 0x20 | (0x80 if not v & (1 << ((op >> 3) & 7)) else 0)
            return 12 if r == 6 else 8
        if grp == 2:
            self.set8(r, v & ~(1 << ((op >> 3) & 7)))
            return 16 if r == 6 else 8
        if grp == 3:
            self.set8(r, v | (1 << ((op >> 3) & 7)))
            return 16 if r == 6 else 8
        k = (op >> 3) & 7
        c = 1 if self.f & 0x10 else 0
        if k == 0: nc = v >> 7; v = ((v << 1) | nc) & 255
        elif k == 1: nc = v & 1; v = (v >> 1) | (nc << 7)
        elif k == 2: nc = v >> 7; v = ((v << 1) | c) & 255
        elif k == 3: nc = v & 1; v = (v >> 1) | (c << 7)
        elif k == 4: nc = v >> 7; v = (v << 1) & 255
        elif k == 5: nc = v & 1; v = (v >> 1) | (v & 0x80)
        elif k == 6: nc = 0; v = ((v << 4) | (v >> 4)) & 255
        else: nc = v & 1; v >>= 1
        self.set8(r, v)
        self.f = (0x80 if v == 0 else 0) | (0x10 if nc else 0)
        return 16 if r == 6 else 8

    def fetch(self):
        v = self.rd(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetch16(self):
        v = self.rd16(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        return v

    def step(self):
        iff = self.io[0x0F] & self.ie & 0x1F
        if iff:
            self.halted = False
            if self.ime:
                self.ime = False
                bit = (iff & -iff).bit_length() - 1
                self.io[0x0F] &= ~(1 << bit)
                self.push(self.pc)
                self.pc = 0x40 + 8 * bit
                return 20
        if self.halted:
            return 4
        op = self.fetch()
        if op == 0xCB:
            return self.cb(self.fetch())
        hi = op >> 6
        if hi == 1:
            if op == 0x76:
                self.halted = True
                return 4
            self.set8((op >> 3) & 7, self.get8(op & 7))
            return 8 if (op & 7) == 6 or ((op >> 3) & 7) == 6 else 4
        if hi == 2:
            self.alu((op >> 3) & 7, self.get8(op & 7))
            return 8 if (op & 7) == 6 else 4
        if hi == 0:
            lo = op & 7
            if lo == 0:
                if op == 0x00: return 4
                if op == 0x08:
                    a = self.fetch16(); self.wr(a, self.sp & 255); self.wr(a + 1, self.sp >> 8); return 20
                if op == 0x10: self.fetch(); return 4
                d = self.fetch()
                d = d - 256 if d > 127 else d
                if op == 0x18 or self.cond((op >> 3) & 3):
                    self.pc = (self.pc + d) & 0xFFFF
                    return 12
                return 8
            if lo == 1:
                i = (op >> 4) & 3
                if op & 8:
                    hl = self.get16(2); v = self.get16(i)
                    r = hl + v
                    self.f = (self.f & 0x80) | (0x20 if (hl & 0xFFF) + (v & 0xFFF) > 0xFFF else 0) | (0x10 if r > 0xFFFF else 0)
                    self.set16(2, r)
                    return 8
                self.set16(i, self.fetch16())
                return 12
            if lo == 2:
                i = (op >> 4) & 3
                if i == 0: a = self.get16(0)
                elif i == 1: a = self.get16(1)
                else:
                    a = self.get16(2)
                    self.set16(2, a + (1 if i == 2 else -1))
                if op & 8: self.a = self.rd(a)
                else: self.wr(a, self.a)
                return 8
            if lo == 3:
                i = (op >> 4) & 3
                self.set16(i, self.get16(i) + (-1 if op & 8 else 1))
                return 8
            if lo == 4 or lo == 5:
                i = (op >> 3) & 7
                v = self.get8(i)
                if lo == 4:
                    r = (v + 1) & 255
                    self.f = (self.f & 0x10) | (0x80 if r == 0 else 0) | (0x20 if (v & 15) == 15 else 0)
                else:
                    r = (v - 1) & 255
                    self.f = (self.f & 0x10) | 0x40 | (0x80 if r == 0 else 0) | (0x20 if (v & 15) == 0 else 0)
                self.set8(i, r)
                return 12 if i == 6 else 4
            if lo == 6:
                i = (op >> 3) & 7
                self.set8(i, self.fetch())
                return 12 if i == 6 else 8
            a = self.a                                # lo == 7
            k = (op >> 3) & 7
            if k == 0: c = a >> 7; self.a = ((a << 1) | c) & 255; self.f = 0x10 if c else 0
            elif k == 1: c = a & 1; self.a = (a >> 1) | (c << 7); self.f = 0x10 if c else 0
            elif k == 2: c = a >> 7; self.a = ((a << 1) | (1 if self.f & 0x10 else 0)) & 255; self.f = 0x10 if c else 0
            elif k == 3: c = a & 1; self.a = (a >> 1) | (0x80 if self.f & 0x10 else 0); self.f = 0x10 if c else 0
            elif k == 4:
                adj, c = 0, self.f & 0x10
                if self.f & 0x40:
                    if self.f & 0x20: adj |= 6
                    if c: adj |= 0x60
                    a = (a - adj) & 255
                else:
                    if self.f & 0x20 or (a & 15) > 9: adj |= 6
                    if c or a > 0x99: adj |= 0x60; c = 0x10
                    a = (a + adj) & 255
                self.a = a
                self.f = (self.f & 0x40) | (0x80 if a == 0 else 0) | c
            elif k == 5: self.a = a ^ 255; self.f = (self.f & 0x90) | 0x60
            elif k == 6: self.f = (self.f & 0x80) | 0x10
            else: self.f = (self.f & 0x80) | (0 if self.f & 0x10 else 0x10)
            return 4
        # hi == 3
        lo = op & 7
        if lo == 0:
            if op < 0xE0:
                if self.cond((op >> 3) & 3):
                    self.pc = self.pop(); return 20
                return 8
            if op == 0xE0: self.wr(0xFF00 + self.fetch(), self.a); return 12
            if op == 0xF0: self.a = self.rd(0xFF00 + self.fetch()); return 12
            d = self.fetch(); d = d - 256 if d > 127 else d
            sp = self.sp
            self.f = (0x20 if (sp & 15) + (d & 15) > 15 else 0) | (0x10 if (sp & 255) + (d & 255) > 255 else 0)
            if op == 0xE8: self.sp = (sp + d) & 0xFFFF; return 16
            self.set16(2, sp + d); return 12
        if lo == 1:
            if op & 8:
                if op == 0xC9: self.pc = self.pop(); return 16
                if op == 0xD9: self.pc = self.pop(); self.ime = True; return 16
                if op == 0xE9: self.pc = self.h << 8 | self.l; return 4
                self.sp = self.h << 8 | self.l; return 8
            i = (op >> 4) & 3
            v = self.pop()
            if i == 3: self.a, self.f = v >> 8, v & 0xF0
            else: self.set16(i, v)
            return 12
        if lo == 2:
            if op < 0xE0:
                a = self.fetch16()
                if self.cond((op >> 3) & 3): self.pc = a; return 16
                return 12
            if op == 0xE2: self.wr(0xFF00 + self.c, self.a); return 8
            if op == 0xF2: self.a = self.rd(0xFF00 + self.c); return 8
            a = self.fetch16()
            if op == 0xEA: self.wr(a, self.a)
            else: self.a = self.rd(a)
            return 16
        if lo == 3:
            if op == 0xC3: self.pc = self.fetch16(); return 16
            if op == 0xF3: self.ime = False; return 4
            if op == 0xFB: self.ime = True; return 4
            raise RuntimeError(f"illegal opcode {op:02x} at {self.pc - 1:04x}")
        if lo == 4:
            if op >= 0xE0:
                raise RuntimeError(f"illegal opcode {op:02x} at {self.pc - 1:04x}")
            a = self.fetch16()
            if self.cond((op >> 3) & 3): self.push(self.pc); self.pc = a; return 24
            return 12
        if lo == 5:
            if op & 8:
                if op == 0xCD:
                    a = self.fetch16(); self.push(self.pc); self.pc = a; return 24
                raise RuntimeError(f"illegal opcode {op:02x} at {self.pc - 1:04x}")
            i = (op >> 4) & 3
            self.push(self.a << 8 | self.f if i == 3 else self.get16(i))
            return 16
        if lo == 6:
            self.alu((op >> 3) & 7, self.fetch())
            return 8
        self.push(self.pc)                            # rst
        self.pc = op & 0x38
        return 16

    # ---- frame loop ----
    def run_frame(self):
        target = 70224
        t = 0
        while t < target:
            if self.pc in self.breaks:
                self.hits.append((self.frame, self.pc, self.a))
            c = self.step()
            t += c
            self.cyc += c
            self.line_cyc += c
            if self.serial_t:
                self.serial_t -= c
                if self.serial_t <= 0:
                    self.serial_t = 0
                    self.io[1] = 0xFF
                    self.io[2] &= 0x7F
                    self.io[0x0F] |= 0x08
            if self.line_cyc >= 456:
                self.line_cyc -= 456
                self.io[0x44] = (self.io[0x44] + 1) % 154
                if self.io[0x44] == 144:
                    self.io[0x0F] |= 0x01
        self.frame += 1

    # ---- rendering (end-of-frame state, no per-line effects) ----
    def render(self):
        lcdc = self.io[0x40]
        img = [[0] * 160 for _ in range(144)]
        if not lcdc & 0x80:
            return img
        bgp = self.io[0x47]
        pal = [(bgp >> (2 * i)) & 3 for i in range(4)]
        scx, scy = self.io[0x43], self.io[0x42]
        mapbase = 0x1C00 if lcdc & 8 else 0x1800
        signed = not lcdc & 0x10
        bgcol = [[0] * 160 for _ in range(144)]
        if lcdc & 1:
            for y in range(144):
                yy = (y + scy) & 255
                for x in range(160):
                    xx = (x + scx) & 255
                    t = self.vram[mapbase + (yy >> 3) * 32 + (xx >> 3)]
                    base = 0x1000 + ((t ^ 128) - 128) * 16 if signed else t * 16
                    lo = self.vram[base + (yy & 7) * 2]
                    hi = self.vram[base + (yy & 7) * 2 + 1]
                    bit = 7 - (xx & 7)
                    ci = ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
                    bgcol[y][x] = ci
                    img[y][x] = pal[ci]
        if lcdc & 0x20:                                    # window
            wy, wx = self.io[0x4A], self.io[0x4B] - 7
            wmap = 0x1C00 if lcdc & 0x40 else 0x1800
            for y in range(max(wy, 0), 144):
                for x in range(max(wx, 0), 160):
                    yy, xx = y - wy, x - wx
                    t = self.vram[wmap + (yy >> 3) * 32 + (xx >> 3)]
                    base = 0x1000 + ((t ^ 128) - 128) * 16 if signed else t * 16
                    lo = self.vram[base + (yy & 7) * 2]
                    hi = self.vram[base + (yy & 7) * 2 + 1]
                    bit = 7 - (xx & 7)
                    ci = ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
                    bgcol[y][x] = ci
                    img[y][x] = pal[ci]
        if lcdc & 2:
            h = 16 if lcdc & 4 else 8
            for i in range(39, -1, -1):
                sy, sx, tile, fl = self.oam[i * 4:i * 4 + 4]
                sy -= 16
                sx -= 8
                p = self.io[0x49] if fl & 0x10 else self.io[0x48]
                sp = [(p >> (2 * k)) & 3 for k in range(4)]
                if h == 16:
                    tile &= 0xFE
                for yy in range(h):
                    y = sy + yy
                    if not 0 <= y < 144:
                        continue
                    row = (h - 1 - yy) if fl & 0x40 else yy
                    base = (tile * 16) + row * 2
                    lo, hi = self.vram[base], self.vram[base + 1]
                    for xx in range(8):
                        x = sx + xx
                        if not 0 <= x < 160:
                            continue
                        bit = xx if fl & 0x20 else 7 - xx
                        ci = ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
                        if ci == 0 or (fl & 0x80 and bgcol[y][x]):
                            continue
                        img[y][x] = sp[ci]
        return img

    def save_png(self, path, scale=2):
        from PIL import Image
        img = self.render()
        shades = (255, 170, 85, 0)
        im = Image.new("L", (160, 144))
        im.putdata([shades[v] for row in img for v in row])
        if scale != 1:
            im = im.resize((160 * scale, 144 * scale), Image.NEAREST)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default=os.path.join(ROOT, "orig", "painter_momopie.gb"))
    ap.add_argument("--frames", type=int, default=300)
    ap.add_argument("--press", action="append", default=[], help="FRAME:BUTTON:HOLD")
    ap.add_argument("--shot", action="append", type=int, default=[])
    ap.add_argument("--watch-ram", action="append", default=[], help="hex address printed when it changes")
    ap.add_argument("--break", dest="brk", action="append", default=[], help="hex pc to log when executed")
    ap.add_argument("--outdir", default=os.path.join(ROOT, "build", "shots"))
    a = ap.parse_args()
    gb = GB(open(a.rom, "rb").read())
    presses = []
    for p in a.press:
        f, b, h = p.split(":")
        presses.append((int(f), BTN[b], int(h)))
    watch = {int(w, 16): None for w in a.watch_ram}
    gb.breaks = {int(x, 16) for x in a.brk}
    for fr in range(a.frames):
        gb.joy = 0
        for f, bit, h in presses:
            if f <= fr < f + h:
                gb.joy |= bit
        gb.run_frame()
        for w in watch:
            v = gb.rd(w)
            if v != watch[w]:
                print(f"frame {fr}: [{w:04x}] {watch[w]} -> {v:#04x} (pc={gb.pc:04x})")
                watch[w] = v
        if fr + 1 in a.shot:
            gb.save_png(os.path.join(a.outdir, f"frame_{fr + 1:04d}.png"))
    seen = None
    for fr, pc, ra in gb.hits:
        if (pc, ra) != seen:
            print(f"frame {fr}: pc={pc:04x} a={ra:02x}")
        seen = (pc, ra)
    print("done; pc=%04x bank=%d" % (gb.pc, gb.bank))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""List text strings found in the ROM. Charmap (from the BG map of the round intro): tile $80+n = letter A+n, $ab+n = digit n,
$ff = space, $b5 = '!', $b6 = 'x'. A string is a run of >= MIN such tiles. Output goes to stdout (nothing is written to the repo).

    python tools/dump_text.py [MIN]
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN = int(sys.argv[1]) if len(sys.argv) > 1 else 5
rom = open(os.path.join(ROOT, "orig", "painter_momopie.gb"), "rb").read()
cm = {0xFF: " ", 0xB5: "!", 0xB6: "x"}
for i in range(26):
    cm[0x80 + i] = chr(65 + i)
for i in range(10):
    cm[0xAB + i] = str(i)
i = 0
while i < len(rom):
    j = i
    while j < len(rom) and rom[j] in cm:
        j += 1
    s = "".join(cm[b] for b in rom[i:j])
    if j - i >= MIN and sum(c.isalpha() for c in s) >= 3 and s.strip(" ") and len(set(s)) > 3:
        bank = i // 0x4000
        addr = i if bank == 0 else 0x4000 + i % 0x4000
        print(f"{bank}:{addr:04x}  {s!r}")
    i = max(j, i + 1)

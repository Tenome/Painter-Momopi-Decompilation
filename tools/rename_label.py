#!/usr/bin/env python3
"""Rename a label everywhere: python tools/rename_label.py OLD NEW [OLD NEW ...]

Changes the name in labels.csv, the sources, the routine list, the lifted C code, the docs and the report (whole identifiers only, also inside gb_native_OLD and GAME_OLD),
then you check with `python tools/build.py` (byte identical) and `python tools/gb_dis.py --check`."""
import re, subprocess, sys

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
pairs = list(zip(sys.argv[1::2], sys.argv[2::2]))
if not pairs:
    sys.exit(__doc__)
files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, cwd=ROOT).stdout.split()
total = 0
for f in files:
    if not f.endswith((".asm", ".inc", ".csv", ".tsv", ".c", ".h", ".md", ".py", ".txt", ".json")):
        continue
    p = ROOT + "/" + f
    try:
        s = open(p, encoding="utf-8", newline="").read()
    except (UnicodeDecodeError, OSError):
        continue
    t = s
    for old, new in pairs:
        t = re.sub(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(old), new, t)
    if t != s:
        open(p, "w", encoding="utf-8", newline="").write(t)
        total += 1
        print("changed", f)
print(total, "files")

#!/usr/bin/env python3
"""Build the ROM with RGBDS (no make needed): python tools/build.py [--rgbds DIR]. RGBDS is taken from PATH or RGBDS_DIR."""
import glob, hashlib, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WANT = "193901223ffc89cf4f42a19e57447249affcc843"
d = os.environ.get("RGBDS_DIR", "")
if "--rgbds" in sys.argv:
    d = sys.argv[sys.argv.index("--rgbds") + 1]
exe = lambda n: os.path.join(d, n) if d else n
os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
objs = []
for src in sorted(glob.glob(os.path.join(ROOT, "src", "*.asm"))):
    o = os.path.join(ROOT, "build", os.path.basename(src)[:-4] + ".o")
    subprocess.run([exe("rgbasm"), "-o", o, src], check=True, cwd=ROOT)
    objs.append(o)
rom = os.path.join(ROOT, "build", "painter_momopie.gb")
subprocess.run([exe("rgblink"), "-p", "0xFF", "-n", rom[:-3] + ".sym", "-m", rom[:-3] + ".map", "-o", rom] + objs,
               check=True, cwd=ROOT)
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_rom.py"), rom, WANT]).returncode)

#!/usr/bin/env python3
"""Build the ROM with RGBDS (no make needed): python tools/build.py [--rgbds DIR] [--mod]. RGBDS is taken from PATH or RGBDS_DIR.
--mod skips the comparison with the original (use it after editing assets/)."""
import glob, hashlib, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WANT = "193901223ffc89cf4f42a19e57447249affcc843"
d = os.environ.get("RGBDS_DIR", "")
if "--rgbds" in sys.argv:
    d = sys.argv[sys.argv.index("--rgbds") + 1]
exe = lambda n: os.path.join(d, n) if d else n
os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
if os.path.isdir(os.path.join(ROOT, "assets", "gfx")):          # edited PNG sheets become the tile data
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gfx.py"), "bin"], check=True, cwd=ROOT)
objs = []
for src in sorted(glob.glob(os.path.join(ROOT, "src", "*.asm"))):
    o = os.path.join(ROOT, "build", os.path.basename(src)[:-4] + ".o")
    subprocess.run([exe("rgbasm"), "-o", o, src], check=True, cwd=ROOT)
    objs.append(o)
rom = os.path.join(ROOT, "build", "painter_momopie.gb")
subprocess.run([exe("rgblink"), "-p", "0xFF", "-n", rom[:-3] + ".sym", "-m", rom[:-3] + ".map", "-o", rom] + objs,
               check=True, cwd=ROOT)
if "--mod" in sys.argv:                      # modded build: no comparison with the original
    print("built", rom, "SHA-1", hashlib.sha1(open(rom, "rb").read()).hexdigest())
    sys.exit(0)
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_rom.py"), rom, WANT]).returncode)

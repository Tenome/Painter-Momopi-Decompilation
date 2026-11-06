#!/usr/bin/env python3
"""Recompile the ROM to C and build the headless runner: python tools/build_port.py [--cc PATH_TO_CLANG_OR_GCC]

Needs a C compiler (clang or gcc). Output: build/recomp/game_headless(.exe).
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cc = os.environ.get("CC", "")
if "--cc" in sys.argv:
    cc = sys.argv[sys.argv.index("--cc") + 1]
if not cc:
    for cand in ("clang", "gcc", "cc"):
        if subprocess.run(["where" if os.name == "nt" else "which", cand], capture_output=True).returncode == 0:
            cc = cand
            break
if not cc:
    sys.exit("no C compiler found (set CC or pass --cc)")
subprocess.run([sys.executable, os.path.join(ROOT, "tools", "recomp.py")], check=True)
out = os.path.join(ROOT, "build", "recomp", "game_headless" + (".exe" if os.name == "nt" else ""))
cmd = [cc, "-O2", "-w", "-I", os.path.join(ROOT, "port"), os.path.join(ROOT, "port", "gb_rt.c"), os.path.join(ROOT, "port", "apu.c"), os.path.join(ROOT, "port", "main_headless.c"),
       os.path.join(ROOT, "build", "recomp", "game.c"), "-o", out]
print(" ".join(cmd))
subprocess.run(cmd, check=True)
print("built", out)
if os.name == "nt":
    win = os.path.join(ROOT, "build", "recomp", "game_win.exe")
    cmd = [cc, "-O2", "-w", "-I", os.path.join(ROOT, "port"), os.path.join(ROOT, "port", "gb_rt.c"), os.path.join(ROOT, "port", "apu.c"),
           os.path.join(ROOT, "port", "main_win32.c"), os.path.join(ROOT, "build", "recomp", "game.c"), "-o", win,
           "-mwindows", "-luser32", "-lgdi32", "-lwinmm", "-lshell32"]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    print("built", win)

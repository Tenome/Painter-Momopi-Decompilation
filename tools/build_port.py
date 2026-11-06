#!/usr/bin/env python3
"""Recompile the ROM to C and build the headless runner (and on Windows the window player): python tools/build_port.py [--cc PATH_TO_CLANG_OR_GCC] [--sdl]

--sdl also builds the SDL2 player (needs sdl2-config; Linux/macOS).

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
if "--sdl" in sys.argv:
    sdl = os.path.join(ROOT, "build", "recomp", "game_sdl" + (".exe" if os.name == "nt" else ""))
    flags = subprocess.run(["sdl2-config", "--cflags", "--libs"], capture_output=True, text=True).stdout.split()
    cmd = [cc, "-O2", "-w", "-I", os.path.join(ROOT, "port")] + flags + [os.path.join(ROOT, "port", "gb_rt.c"), os.path.join(ROOT, "port", "apu.c"),
           os.path.join(ROOT, "port", "main_sdl.c"), os.path.join(ROOT, "build", "recomp", "game.c"), "-o", sdl] + flags + ["-lm"]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    print("built", sdl)
if os.name == "nt":
    win = os.path.join(ROOT, "build", "recomp", "game_win.exe")
    cmd = [cc, "-O2", "-w", "-I", os.path.join(ROOT, "port"), os.path.join(ROOT, "port", "gb_rt.c"), os.path.join(ROOT, "port", "apu.c"),
           os.path.join(ROOT, "port", "main_win32.c"), os.path.join(ROOT, "build", "recomp", "game.c"), "-o", win,
           "-mwindows", "-luser32", "-lgdi32", "-lwinmm", "-lshell32"]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    print("built", win)

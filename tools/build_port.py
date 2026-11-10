#!/usr/bin/env python3
"""Build the native port: python tools/build_port.py [--cc COMPILER] [--rgbds DIR] [--sdl]

1. builds the ROM from src/ and assets/ with RGBDS (tools/build.py --mod) if build/painter_momopie.gb is missing or --rebuild is given;
2. recompiles that ROM's routines to C (tools/recomp.py), writing build/recomp/game.c and the data image build/recomp/rom_image.c;
3. compiles the headless runner and, on Windows, the window player; --sdl also builds the SDL2 player (needs sdl2-config).

The original ROM is not needed here: only src/, assets/ and the compiler. The resulting programs contain the game data and need no ROM file.
Output: build/recomp/game_win.exe (window), build/recomp/game_headless(.exe) (tests), build/recomp/game_sdl (with --sdl).
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable


def arg(name, default=""):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


cc = arg("--cc", os.environ.get("CC", ""))
if not cc:
    for cand in ("clang", "gcc", "cc"):
        if subprocess.run(["where" if os.name == "nt" else "which", cand], capture_output=True).returncode == 0:
            cc = cand
            break
if not cc:
    sys.exit("no C compiler found (set CC or pass --cc)")

rom = os.path.join(ROOT, "build", "painter_momopie.gb")
if "--rebuild" in sys.argv or not os.path.exists(rom):
    cmd = [PY, os.path.join(ROOT, "tools", "build.py"), "--mod"]
    if arg("--rgbds"):
        cmd += ["--rgbds", arg("--rgbds")]
    subprocess.run(cmd, check=True, cwd=ROOT)

os.makedirs(os.path.join(ROOT, "build", "recomp"), exist_ok=True)
subprocess.run([PY, os.path.join(ROOT, "tools", "recomp.py"), "--rom", rom], check=True, cwd=ROOT)
subprocess.run([PY, os.path.join(ROOT, "tools", "make_tile_index.py")], check=True, cwd=ROOT)

data = open(rom, "rb").read()
with open(os.path.join(ROOT, "build", "recomp", "rom_image.c"), "w", newline="\n") as f:
    f.write("/* Generated from the built ROM by tools/build_port.py. Do not commit. */\n#include <stddef.h>\n")
    f.write("const unsigned char gb_rom_image[] = {\n")
    for i in range(0, len(data), 24):
        f.write(",".join(str(b) for b in data[i:i + 24]) + ",\n")
    f.write(f"}};\nconst size_t gb_rom_image_size = {len(data)};\n")

P = lambda *a: os.path.join(ROOT, *a)
common = [P("port", "gb_rt.c"), P("port", "gb_native.c"), P("port", "logic.c"), P("port", "apu.c"), P("port", "config.c"), P("port", "texture.c"), P("port", "png.c"), P("build", "recomp", "tile_index.c"), P("build", "recomp", "game.c"), P("build", "recomp", "rom_image.c")]
exe = ".exe" if os.name == "nt" else ""


def compile_(main, out, extra=()):
    cmd = [cc, "-O2", "-w", "-I", P("port"), "-I", P("build", "recomp")] + [P("port", main)] + common + ["-o", out] + list(extra)
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    print("built", out)


compile_("main_headless.c", P("build", "recomp", "game_headless" + exe))
if os.name == "nt":
    compile_("main_win32.c", P("build", "recomp", "game_win.exe"), ["-mwindows", "-luser32", "-lgdi32", "-lwinmm", "-lshell32"])
    gui = P("build", "recomp", "settings.exe")                    # the settings window (edits painter_momopie.ini)
    subprocess.run([cc, "-O2", "-w", P("port", "config_gui.c"), "-o", gui, "-mwindows", "-luser32", "-lgdi32", "-lcomctl32", "-lcomdlg32", "-lshell32", "-lole32"], check=True)
    print("built", gui)
    ini = P("build", "recomp", "painter_momopie.ini")
    if not os.path.exists(ini):
        import shutil
        shutil.copy(P("port", "painter_momopie.ini"), ini)
if "--sdl" in sys.argv:
    flags = subprocess.run(["sdl2-config", "--cflags", "--libs"], capture_output=True, text=True).stdout.split()
    compile_("main_sdl.c", P("build", "recomp", "game_sdl" + exe), flags + ["-lm"])

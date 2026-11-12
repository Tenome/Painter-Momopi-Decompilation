#!/usr/bin/env python3
"""Build level_editor.exe, the level editor as one program that needs no Python: python tools/build_editor.py [--out build/editor]

Uses PyInstaller (pip install pyinstaller pillow). The program contains none of the game's data: it reads data/painter_momopie.gb (for the room pictures) and the enemy pictures from the
folder it sits in, which tools/package.py fills for your own copy; without them it shows flat colours and numbered enemies. Needs Python and tkinter only to build, not to run."""
import argparse, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(ROOT, "build", "editor"))
a = ap.parse_args()
try:
    import PyInstaller  # noqa: F401
except ImportError:
    sys.exit("PyInstaller is not installed: pip install pyinstaller pillow")
work = os.path.join(a.out, "work")
sep = ";" if os.name == "nt" else ":"
cmd = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--windowed", "--name", "level_editor",
       "--distpath", a.out, "--workpath", work, "--specpath", work,
       "--paths", HERE, "--add-data", os.path.join(HERE, "original_levels.json") + sep + ".",
       "--hidden-import", "levelpack", "--hidden-import", "community", "--hidden-import", "enemy_icons",
       os.path.join(HERE, "level_editor.py")]
subprocess.run(cmd, check=True)
shutil.rmtree(work, ignore_errors=True)
exe = os.path.join(a.out, "level_editor" + (".exe" if os.name == "nt" else ""))
print("built", exe, "(%d KB)" % (os.path.getsize(exe) // 1024))

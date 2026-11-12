#!/usr/bin/env python3
"""Assemble a ready-to-use player folder from a finished build: python tools/package.py [--out dist/PainterMomopie] [--zip]

Copies build/recomp/game_win.exe, settings.exe, painter_momopie.ini, the exported textures folder, the example level pack, the tools for level
and music editing and the docs. The executables contain the game's data extracted from YOUR ROM: keep the folder (and the zip) for your own use;
do not publish it. A folder without the executables (--tools-only) is what the release workflow publishes."""
import argparse, os, shutil, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=P("dist", "PainterMomopie"))
ap.add_argument("--zip", action="store_true", help="also write <out>.zip")
ap.add_argument("--tools-only", action="store_true", help="no game executables (settings.exe is included when built): safe to publish")
a = ap.parse_args()

if os.path.isdir(a.out):
    shutil.rmtree(a.out)
os.makedirs(a.out)
rec = P("build", "recomp")
files = ["settings.exe"] if a.tools_only else ["game_win.exe", "settings.exe"]
for f in files:
    src = os.path.join(rec, f)
    if os.path.exists(src):
        shutil.copy(src, a.out)
    elif not a.tools_only or f != "settings.exe":
        sys.exit("missing " + src + ": run tools/build_port.py first")
for src, dst in ((P("port", "painter_momopie.ini"), "painter_momopie.ini"),):
    shutil.copy(src, os.path.join(a.out, dst))
tex = os.path.join(rec, "textures")
if os.path.isdir(tex) and not a.tools_only:                       # the exported sheets come from the ROM
    shutil.copytree(tex, os.path.join(a.out, "textures"))
shutil.copytree(P("packs"), os.path.join(a.out, "packs"), ignore=shutil.ignore_patterns("original.pmpack", "textures*", "*.zip"))
editor = P("build", "editor", "level_editor.exe" if os.name == "nt" else "level_editor")
if not os.path.exists(editor):
    subprocess.run([sys.executable, P("tools", "build_editor.py")], check=True)
shutil.copy(editor, a.out)
if not a.tools_only:                                              # the room pictures and enemy pictures of the editor come from your game
    data = os.path.join(a.out, "data")
    os.makedirs(data)
    for n in ("painter_momopie.gb", "painter_momopie.sym"):
        shutil.copy(P("build", n), data)
    for n in ("game_headless.exe", "game_headless"):                # lets the editor play your songs and the checks run
        if os.path.exists(os.path.join(rec, n)):
            shutil.copy(os.path.join(rec, n), a.out)
    sys.path.insert(0, P("tools"))
    import enemy_icons
    print("%d enemy pictures" % enemy_icons.make(os.path.join(data, "enemy_icons")))
shutil.copytree(P("docs"), os.path.join(a.out, "docs"), ignore=shutil.ignore_patterns("CALLGRAPH.md", "PSEUDOCODE.md", "RAM_MAP.md", "architecture_exe.md"))
shutil.copy(P("LICENSE"), a.out)
with open(os.path.join(a.out, "README.txt"), "w") as f:
    f.write("Painter Momopie native player\n\n"
            "game_win.exe   the game (no ROM file needed; the data is inside: for your own use only)\n"
            "settings.exe   every option in a window (it edits painter_momopie.ini)\n"
            "level_editor.exe  make your own levels (no Python needed); the Community menu browses and shares packs\n"
            "packs/         example and tutorial level packs\n"
            "textures/      full-colour sprite replacement sheets with a README.ini\n"
            "docs/          CONFIG.md, TEXTURES.md, LEVELS.md, MUSIC.md\n")
print("packaged", a.out)
if a.zip:
    z = a.out + ".zip"
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for d, _, fs in os.walk(a.out):
            for f in fs:
                full = os.path.join(d, f)
                zf.write(full, os.path.relpath(full, os.path.dirname(a.out)))
    print("wrote", z)

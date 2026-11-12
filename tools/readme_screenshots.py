#!/usr/bin/env python3
"""Make the pictures of the README: python tools/readme_screenshots.py

Starts the level editor on the tutorial pack and saves screenshots of its windows into docs/images/. With the game data next to it (build/painter_momopie.gb) the pictures
show the real room tiles and enemies; set PMEDITOR_FLAT=1 for flat colours. Windows only (it grabs the screen); needs Pillow."""
import os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import tkinter as tk
from tkinter import ttk
from PIL import ImageGrab
import community
import level_editor as le

OUT = os.path.join(ROOT, "docs", "images")
os.makedirs(OUT, exist_ok=True)
root = tk.Tk()
root.geometry("1180x700+40+40")
ed = le.Editor(root, os.path.join(ROOT, "packs", "tutorial.pmpack"))
ed.dirty = False


def pump(n=10):
    for _ in range(n):
        root.update()
        time.sleep(0.05)


def grab(win, name):
    """the window's own picture (PrintWindow): other windows on the screen, the desktop or anything in front of it can never end up in the screenshot"""
    import ctypes
    from ctypes import wintypes
    from PIL import Image
    pump(6)
    win.update()
    user32, gdi32 = ctypes.windll.user32, ctypes.windll.gdi32
    hwnd = user32.GetAncestor(win.winfo_id(), 2)                  # GA_ROOT: the top level window
    rc = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    hdc = user32.GetWindowDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    user32.PrintWindow(hwnd, mem, 2)                              # PW_RENDERFULLCONTENT
    class BIH(ctypes.Structure):
        _fields_ = [("size", wintypes.DWORD), ("w", wintypes.LONG), ("h", wintypes.LONG), ("planes", wintypes.WORD), ("bits", wintypes.WORD),
                    ("comp", wintypes.DWORD), ("img", wintypes.DWORD), ("x", wintypes.LONG), ("y", wintypes.LONG), ("used", wintypes.DWORD), ("imp", wintypes.DWORD)]
    bi = BIH(ctypes.sizeof(BIH), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(hwnd, hdc)
    full = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1).convert("RGB")
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(win.winfo_id(), ctypes.byref(pt))       # only the client area: the title bar and frame are left out
    cx, cy = pt.x - rc.left, pt.y - rc.top
    full.crop((cx, cy, cx + win.winfo_width(), cy + win.winfo_height())).save(os.path.join(OUT, name))
    print("wrote", name)


def find(widget, cls):
    out = []
    for c in widget.winfo_children():
        if isinstance(c, cls):
            out.append(c)
        out += find(c, cls)
    return out


def select_level(i):
    ed.cur = i
    ed.selected = None
    ed.refresh_all()


# 1. the map with its paths and enemies
ed.tool.set("paint1")
select_level(4)
ed.show_all.set(1)
pump(10)
grab(root, "editor_map.png")

# 2. the enemies tab
nb = find(root, ttk.Notebook)[0]
nb.select(1)
ed.wave.set(0)
ed.refresh_enemies()
if ed.level.waves[0]:
    ed.selected = (0, 0)
    ed.tree.selection_set("0")
    ed.load_enemy_fields()
ed.tool.set("enemy")
pump(10)
grab(root, "editor_enemies.png")

# 3. the community browser, read from a local test folder (made by tools/community.py)
import shutil, tempfile
community.PREVIEW_TILES = le.Tiles()                     # the previews use the real room tiles when the game data is there
tmp = tempfile.mkdtemp()
sub = os.path.join(tmp, "community", "packs")
os.makedirs(sub)
d, errs = community.make_submission(os.path.join(ROOT, "packs", "tutorial.pmpack"), "Tutorial", "The project", "Five short levels that teach one thing each: paths, a chaser, wanderers, statues and a shooter with two waves.", sub, ["tutorial", "easy"])
d2, errs2 = community.make_submission(os.path.join(ROOT, "packs", "example.pmpack"), "Crossroads and friends", "Example author", "Three small levels: a cross, a spiral and a grid, with an own song on the first one.", sub, ["example"])
community.build_index(os.path.join(tmp, "community"))
os.environ["PMCOMMUNITY_URL"] = "file:///" + os.path.join(tmp, "community").replace(os.sep, "/") + "/"
ed.community_browse()
pump(25)
top = [w for w in root.winfo_children() if isinstance(w, tk.Toplevel)][-1]
lb = find(top, tk.Listbox)[0]
lb.selection_set(0)
lb.event_generate("<<ListboxSelect>>")
pump(25)
top.geometry("+120+90")
grab(top, "community_browser.png")
top.destroy()

# 4. the submit dialog
ed.community_submit()
pump(5)
top = [w for w in root.winfo_children() if isinstance(w, tk.Toplevel)][-1]
top.geometry("+160+60")
entries = find(top, ttk.Entry)
entries[0].delete(0, "end"); entries[0].insert(0, "Tutorial")
entries[1].delete(0, "end"); entries[1].insert(0, "Your name")
txt = find(top, tk.Text)[0]
txt.insert("1.0", "Five short levels that teach one thing each.")
for cb in find(top, ttk.Checkbutton):
    cb.invoke()
for b in find(top, ttk.Button):
    if "Check and make" in str(b.cget("text")):
        b.invoke()
pump(10)
for lab in find(top, ttk.Label):                      # the picture must not show where the repository is on this computer
    t = str(lab.cget("text"))
    if ROOT in t:
        lab.config(text=t.replace(os.path.join(ROOT, "submissions"), "submissions"))
pump(4)
grab(top, "community_submit.png")
top.destroy()
shutil.rmtree(tmp, ignore_errors=True)
shutil.rmtree(os.path.join(ROOT, "submissions", "tutorial"), ignore_errors=True)
root.destroy()

#!/usr/bin/env python3
"""Make the pictures of the README: python tools/readme_screenshots.py

Starts the level editor with flat colours (no game graphics, so the pictures can be published) on the tutorial pack and saves screenshots of its windows into
docs/images/. Windows only (it grabs the screen); needs Pillow."""
import os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
os.environ["PMEDITOR_FLAT"] = "1"
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
    pump(6)
    win.lift()
    win.update()
    x, y, w, h = win.winfo_rootx(), win.winfo_rooty(), win.winfo_width(), win.winfo_height()
    ImageGrab.grab((x, y, x + w, y + h)).save(os.path.join(OUT, name))
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

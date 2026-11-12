#!/usr/bin/env python3
"""Painter Momopie level editor (tkinter + Pillow).

    python tools/level_editor.py [pack.pmpack]

Edit custom level packs (docs/LEVELS.md): the order of the levels, every map, the enemies of the six waves, the look, music, time and magic points of
each level, and the texture folders (full-colour tile replacements) of the whole pack or of a single level. "Play" starts the native player on the pack.
"""
import copy
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
import threading
import webbrowser
import zipfile
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import levelpack as lp
import community

try:
    from PIL import Image, ImageTk
except ImportError:                                                  # the editor works without pictures
    Image = ImageTk = None

ROOT = lp.ROOT
HOME = lp.HOME                                             # packs/, textures/ and the game program live here
CELL = 34
SETTINGS = os.path.join(ROOT, "level_editor_settings.json" if lp.FROZEN else os.path.join("tools", ".level_editor.json"))
FLAT = ["#1c1c28", "#e8c84a", "#d98a2b", "#6ab0e8"]
WAVE_COLORS = ["#e04040", "#e08030", "#d0c030", "#40b040", "#4080e0", "#a050d0"]
SONGS = {0x81: "$81 (title/jingle)", 0x82: "$82", 0x83: "$83", 0x84: "$84", 0x85: "$85", 0x86: "$86", 0x87: "$87", 0x88: "$88", 0x89: "$89", 0x8A: "$8a (round clear)", 0x8B: "$8b"}
SHADES = (255, 170, 85, 0)


class Tiles:
    """the real tiles of the rooms, read from the game data (needs build/painter_momopie.gb from tools/build.py); None when it is not there"""

    def __init__(self):
        self.ok = False
        self.cache = {}
        if Image is None or os.environ.get("PMEDITOR_FLAT"):          # PMEDITOR_FLAT=1: flat colours even when the game data is there (for screenshots)
            return
        rom_path = lp.data_path("painter_momopie.gb")
        sym_path = lp.data_path("painter_momopie.sym")
        if not (os.path.exists(rom_path) and os.path.exists(sym_path)):
            return
        self.rom = open(rom_path, "rb").read()
        self.sym = lp.sym_table(sym_path)
        self.ok = True

    def word(self, a):
        return self.rom[a] | self.rom[a + 1] << 8

    def tile(self, t, setbase):
        if t < 112:
            off = 2 * 0x4000 + t * 16
        else:
            off = 2 * 0x4000 + (setbase - 0x4000) + (t - 112) * 16
        d = self.rom[off:off + 16]
        im = Image.new("L", (8, 8))
        px = im.load()
        for y in range(8):
            for x in range(8):
                px[x, y] = SHADES[((d[y * 2 + 1] >> (7 - x)) & 1) << 1 | ((d[y * 2] >> (7 - x)) & 1)]
        return im

    def cell(self, theme, value, size):
        key = (theme, value, size)
        if key in self.cache:
            return self.cache[key]
        look = 16 if theme == 16 else theme & 15
        meta = self.word(self.sym["RoomMetatileTable"][1] + 2 * look)
        setbase = self.word(self.sym["RoomSpriteSetTable"][1] + 2 * look)
        ids = self.rom[meta + value * 4: meta + value * 4 + 4]
        im = Image.new("L", (16, 16))
        for i, t in enumerate(ids):
            im.paste(self.tile(t, setbase), ((i % 2) * 8, (i // 2) * 8))
        photo = ImageTk.PhotoImage(im.resize((size, size), Image.NEAREST).convert("RGB"))
        self.cache[key] = photo
        return photo


def load_settings():
    try:
        return json.load(open(SETTINGS))
    except (OSError, ValueError):
        return {}


def save_settings(s):
    try:
        json.dump(s, open(SETTINGS, "w"))
    except OSError:
        pass


def find_game():
    return lp.game_path() or ""


class Editor:
    def __init__(self, root, path=None):
        self.root = root
        self.settings = load_settings()
        self.tiles = Tiles()
        self.pack = lp.Pack()
        self.pack.levels.append(self.blank_level("Level 1"))
        self.path = None
        self.dirty = False
        self.cur = 0
        self.tool = tk.StringVar(value="paint1")
        self.wave = tk.IntVar(value=0)
        self.show_all = tk.IntVar(value=1)
        self.kind = tk.IntVar(value=1)
        self.delay = tk.IntVar(value=10)
        self.flag = tk.IntVar(value=0)
        self.selected = None                       # (wave, index) of the selected enemy
        self.fillbox_var = tk.StringVar(value="fill: 2")
        self.undo_stack = []
        self.redo_stack = []
        self.fillval = tk.IntVar(value=2)
        self.loading = False
        self.game_proc = None                      # the test window (game_win.exe) while it runs
        self.last_level = 1
        self.auto_restart = tk.IntVar(value=1)
        self.icons = self.load_icons()
        self.build_ui()
        if path:
            self.open_file(path)
        self.refresh_all()
        root.protocol("WM_DELETE_WINDOW", self.quit)

    @staticmethod
    def load_icons():
        """pictures of the enemy kinds (tools/enemy_icons.py cuts them out of the game; made on the first start when the native runner is built)"""
        if Image is None or os.environ.get("PMEDITOR_FLAT"):
            return {}
        import enemy_icons
        d = enemy_icons.DEFAULT_OUT
        try:
            if not os.path.exists(os.path.join(d, "1.png")):
                enemy_icons.make(d)
        except Exception:
            return {}
        icons = {}
        for k in lp.KINDS:
            p = os.path.join(d, "%d.png" % k)
            if os.path.exists(p):
                im = Image.open(p).convert("RGBA")
                icons[k] = ImageTk.PhotoImage(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
        return icons

    # ---------------------------------------------------------------- data helpers
    @staticmethod
    def blank_level(name):
        lv = lp.Level()
        lv.name = name
        for r in range(2, 14):                    # a plus shaped starting area around the player start (column 7, row 6)
            lv.map[r][7] = 2
        for c in range(3, 12):
            lv.map[6][c] = 2
        return lv

    @property
    def level(self):
        return self.pack.levels[self.cur]

    def theme_of(self, lv, index):
        if lv.theme is not None:
            return lv.theme
        return 16 if index == 32 else index & 15

    def touch(self):
        self.dirty = True
        self.update_title()

    # ---------------------------------------------------------------- UI
    def build_ui(self):
        r = self.root
        menu = tk.Menu(r)
        f = tk.Menu(menu, tearoff=0)
        f.add_command(label="New pack", command=self.new_pack)
        f.add_command(label="Open...", command=self.open_dialog, accelerator="Ctrl+O")
        f.add_command(label="Save", command=self.save, accelerator="Ctrl+S")
        f.add_command(label="Save as...", command=self.save_as)
        f.add_separator()
        f.add_command(label="Add the game's 33 original levels to this pack", command=self.import_original)
        f.add_command(label="Add levels from another pack...", command=self.import_levels)
        f.add_command(label="Export the current level...", command=self.export_level)
        f.add_command(label="Export the pack as a zip file (with its tiles and music)...", command=self.export_zip)
        f.add_separator()
        f.add_command(label="Quit", command=self.quit)
        menu.add_cascade(label="File", menu=f)
        e = tk.Menu(menu, tearoff=0)
        e.add_command(label="Undo", command=self.undo, accelerator="Ctrl+Z")
        e.add_command(label="Redo", command=self.redo, accelerator="Ctrl+Y")
        e.add_separator()
        e.add_command(label="Mirror the map left to right", command=lambda: self.transform("lr"))
        e.add_command(label="Mirror the map top to bottom", command=lambda: self.transform("tb"))
        e.add_command(label="Clear the map", command=lambda: self.transform("clear"))
        e.add_command(label="Make a random maze", command=lambda: self.transform("maze"))
        menu.add_cascade(label="Edit", menu=e)
        p = tk.Menu(menu, tearoff=0)
        p.add_command(label="Pack properties...", command=self.pack_properties)
        p.add_command(label="Check the pack", command=self.check_pack)
        p.add_separator()
        p.add_command(label="Play the pack from level 1", command=lambda: self.play(1), accelerator="F5")
        p.add_command(label="Play from the current level", command=lambda: self.play(self.cur + 1), accelerator="F6")
        p.add_checkbutton(label="Restart the test window when I save", variable=self.auto_restart)
        p.add_command(label="Choose the game program...", command=self.choose_game)
        menu.add_cascade(label="Pack", menu=p)
        c = tk.Menu(menu, tearoff=0)
        c.add_command(label="Browse and download community packs...", command=self.community_browse)
        c.add_command(label="Submit this pack to the community...", command=self.community_submit)
        menu.add_cascade(label="Community", menu=c)
        h = tk.Menu(menu, tearoff=0)
        h.add_command(label="How it works", command=self.help)
        menu.add_cascade(label="Help", menu=h)
        r.config(menu=menu)
        r.bind("<Control-s>", lambda e: self.save())
        r.bind("<Control-o>", lambda e: self.open_dialog())
        r.bind("<F5>", lambda e: self.play(1))
        r.bind("<Control-z>", lambda e: self.undo())
        r.bind("<Control-y>", lambda e: self.redo())
        r.bind("<F6>", lambda e: self.play(self.cur + 1))

        main = ttk.Frame(r, padding=6)
        main.pack(fill="both", expand=True)

        left = ttk.LabelFrame(main, text="Levels (play order)", padding=4)
        left.pack(side="left", fill="y")
        self.listbox = tk.Listbox(left, width=24, height=26, exportselection=False)
        self.listbox.pack(fill="y", expand=True)
        self.listbox.bind("<<ListboxSelect>>", self.on_select_level)
        row = ttk.Frame(left)
        row.pack(fill="x", pady=(4, 0))
        for text, cmd in (("Add", self.add_level), ("Copy", self.dup_level), ("Delete", self.del_level)):
            ttk.Button(row, text=text, width=6, command=cmd).pack(side="left", padx=1)
        row = ttk.Frame(left)
        row.pack(fill="x", pady=(2, 0))
        ttk.Button(row, text="Move up", width=9, command=lambda: self.move_level(-1)).pack(side="left", padx=1)
        ttk.Button(row, text="Move down", width=9, command=lambda: self.move_level(1)).pack(side="left", padx=1)

        mid = ttk.Frame(main, padding=(8, 0))
        mid.pack(side="left")
        tools = ttk.Frame(mid)
        tools.pack(fill="x")
        for text, val in (("Empty", "paint0"), ("Path 1", "paint1"), ("Path 2", "paint2"), ("Special", "paint3"), ("Fill", "fill"), ("Enemy", "enemy")):
            ttk.Radiobutton(tools, text=text, value=val, variable=self.tool, style="Toolbutton").pack(side="left", padx=1)
        ttk.Combobox(tools, width=7, state="readonly", values=["fill: 0", "fill: 1", "fill: 2", "fill: 3"], textvariable=self.fillbox_var).pack(side="left", padx=2)
        ttk.Label(tools, text="  Left click paints or places, right click erases").pack(side="left")
        self.canvas = tk.Canvas(mid, width=16 * CELL, height=16 * CELL, highlightthickness=1, highlightbackground="#555")
        self.canvas.pack(pady=4)
        self.canvas.bind("<Button-1>", self.on_click)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<Button-3>", self.on_erase)
        self.canvas.bind("<B3-Motion>", self.on_erase)
        self.info = ttk.Label(mid, text="")
        self.info.pack(anchor="w")

        right = ttk.Notebook(main)
        right.pack(side="left", fill="both", padx=(8, 0))
        self.build_level_tab(right)
        self.build_enemy_tab(right)
        self.build_texture_tab(right)

        self.status = ttk.Label(r, text="", relief="sunken", anchor="w")
        self.status.pack(fill="x", side="bottom")

    def field(self, parent, label, row, widget):
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", pady=2)
        widget.grid(row=row, column=1, sticky="we", pady=2, padx=(6, 0))
        return widget

    def build_level_tab(self, nb):
        t = ttk.Frame(nb, padding=8)
        nb.add(t, text="Level")
        t.columnconfigure(1, weight=1)
        self.v_name = tk.StringVar()
        self.field(t, "Name", 0, ttk.Entry(t, textvariable=self.v_name, width=26))
        self.v_theme = tk.StringVar()
        self.field(t, "Look", 1, ttk.Combobox(t, textvariable=self.v_theme, values=["auto"] + [str(i) for i in range(17)], width=8))
        ttk.Label(t, text="0-16: tile set, floor, walls and room name.\n'auto' = what the original has at this position.", foreground="#666").grid(row=2, column=0, columnspan=2, sticky="w")
        self.v_music = tk.StringVar()
        self.field(t, "Music", 3, ttk.Combobox(t, textvariable=self.v_music, values=["auto"] + [SONGS[k] for k in sorted(SONGS)], width=18))
        self.v_time = tk.StringVar()
        self.field(t, "Time (seconds)", 4, ttk.Entry(t, textvariable=self.v_time, width=10))
        self.v_magic = tk.StringVar()
        self.field(t, "Magic points", 5, ttk.Entry(t, textvariable=self.v_magic, width=10))
        self.v_bonus = tk.StringVar()
        self.field(t, "Bonus screens after", 6, ttk.Combobox(t, textvariable=self.v_bonus, values=["auto", "no", "yes"], width=8, state="readonly"))
        self.v_variant = tk.StringVar()
        self.field(t, "Enemy flag bit", 7, ttk.Combobox(t, textvariable=self.v_variant, values=["auto", "1", "2"], width=8, state="readonly"))
        ttk.Label(t, text="'auto' follows the original: bit 1 up to round 16, bit 2 from round 17.", foreground="#666").grid(row=8, column=0, columnspan=2, sticky="w")
        self.v_title = tk.StringVar()
        self.field(t, "Intro title (8 letters)", 14, ttk.Entry(t, textvariable=self.v_title, width=12))
        self.v_song = tk.StringVar()
        self.field(t, "Own song (music text)", 9, ttk.Entry(t, textvariable=self.v_song, width=26))
        srow = ttk.Frame(t)
        srow.grid(row=10, column=0, columnspan=2, sticky="w")
        ttk.Button(srow, text="New", width=6, command=self.new_song).pack(side="left")
        ttk.Button(srow, text="Browse", width=8, command=self.browse_song).pack(side="left", padx=2)
        ttk.Button(srow, text="Edit", width=6, command=self.edit_song).pack(side="left")
        ttk.Button(srow, text="Listen", width=7, command=self.listen_song).pack(side="left", padx=2)
        ttk.Label(t, text="Replaces the music above (docs/MUSIC.md).", foreground="#666").grid(row=11, column=0, columnspan=2, sticky="w")
        self.v_paint = ttk.Label(t, text="")
        self.v_paint.grid(row=12, column=0, columnspan=2, sticky="w", pady=(10, 0))
        self.theme_preview = tk.Canvas(t, width=4 * 36, height=36, highlightthickness=0)
        self.theme_preview.grid(row=13, column=0, columnspan=2, sticky="w", pady=6)
        for v in (self.v_name, self.v_theme, self.v_music, self.v_time, self.v_magic, self.v_bonus, self.v_variant, self.v_song, self.v_title):
            v.trace_add("write", lambda *a: self.apply_level_fields(quiet=True))

    def build_enemy_tab(self, nb):
        t = ttk.Frame(nb, padding=8)
        nb.add(t, text="Enemies")
        ttk.Label(t, text="Enemies appear wave by wave (six waves, then they repeat). At most three are alive at once.\nPick the Enemy tool and click a cell to place one.", foreground="#666").pack(anchor="w")
        row = ttk.Frame(t)
        row.pack(fill="x", pady=4)
        ttk.Label(row, text="Wave").pack(side="left")
        for w in range(6):
            tk.Radiobutton(row, text=str(w), value=w, variable=self.wave, indicatoron=False, width=3, command=self.refresh_enemies,
                           selectcolor=WAVE_COLORS[w]).pack(side="left", padx=1)
        ttk.Checkbutton(row, text="show all waves", variable=self.show_all, command=self.redraw).pack(side="left", padx=8)
        row = ttk.Frame(t)
        row.pack(fill="x", pady=2)
        ttk.Label(row, text="Kind").pack(side="left")
        self.kind_box = ttk.Combobox(row, width=34, state="readonly", values=["%d  %s" % (k, lp.KINDS[k]) for k in sorted(lp.KINDS)])
        self.kind_box.current(1)
        self.kind_box.pack(side="left", padx=4)
        self.kind_box.bind("<<ComboboxSelected>>", lambda e: self.on_kind())
        row = ttk.Frame(t)
        row.pack(fill="x", pady=2)
        ttk.Label(row, text="Appears after").pack(side="left")
        ttk.Spinbox(row, from_=0, to=255, width=5, textvariable=self.delay, command=self.on_delay).pack(side="left", padx=4)
        ttk.Label(row, text="seconds").pack(side="left")
        ttk.Checkbutton(row, text="variant flag", variable=self.flag, command=self.on_delay).pack(side="left", padx=12)
        self.tree = ttk.Treeview(t, columns=("kind", "col", "row", "delay"), show="headings", height=14, selectmode="browse")
        for c, w in (("kind", 150), ("col", 50), ("row", 50), ("delay", 60)):
            self.tree.heading(c, text=c)
            self.tree.column(c, width=w, anchor="w")
        self.tree.pack(fill="both", expand=True, pady=4)
        self.tree.bind("<<TreeviewSelect>>", self.on_tree_select)
        row = ttk.Frame(t)
        row.pack(fill="x")
        ttk.Button(row, text="Delete the selected enemy", command=self.del_enemy).pack(side="left")
        ttk.Button(row, text="Clear this wave", command=self.clear_wave).pack(side="left", padx=6)

    def build_texture_tab(self, nb):
        t = ttk.Frame(nb, padding=8)
        nb.add(t, text="Custom tiles")
        t.columnconfigure(1, weight=1)
        ttk.Label(t, text="Replace the Game Boy tiles with full-colour pictures: enemies, floors, buildings, fonts ...\n"
                          "Make a folder of sheets, paint over them, and point the pack or a single level at it.\n"
                          "A level's folder is used only while that level is played; the pack's folder applies to every level.",
                  foreground="#666").grid(row=0, column=0, columnspan=3, sticky="w")
        self.v_ptex = tk.StringVar()
        self.v_ltex = tk.StringVar()
        ttk.Label(t, text="This level's folder").grid(row=1, column=0, sticky="w", pady=(12, 2))
        ttk.Entry(t, textvariable=self.v_ltex, width=34).grid(row=1, column=1, sticky="we", padx=6, pady=(12, 2))
        ttk.Button(t, text="Browse", command=lambda: self.browse_folder(self.v_ltex)).grid(row=1, column=2, pady=(12, 2))
        row = ttk.Frame(t)
        row.grid(row=2, column=0, columnspan=3, sticky="w")
        ttk.Button(row, text="Create the sheets for this level", command=lambda: self.make_sheets(self.v_ltex, level=True)).pack(side="left")
        ttk.Button(row, text="Open the folder", command=lambda: self.open_folder(self.v_ltex)).pack(side="left", padx=6)
        ttk.Label(t, text="The pack's folder (every level)").grid(row=3, column=0, sticky="w", pady=(16, 2))
        ttk.Entry(t, textvariable=self.v_ptex, width=34).grid(row=3, column=1, sticky="we", padx=6, pady=(16, 2))
        ttk.Button(t, text="Browse", command=lambda: self.browse_folder(self.v_ptex)).grid(row=3, column=2, pady=(16, 2))
        row = ttk.Frame(t)
        row.grid(row=4, column=0, columnspan=3, sticky="w")
        ttk.Button(row, text="Create the sheets for the pack", command=lambda: self.make_sheets(self.v_ptex, level=False)).pack(side="left")
        ttk.Button(row, text="Open the folder", command=lambda: self.open_folder(self.v_ptex)).pack(side="left", padx=6)
        ttk.Label(t, text="Folders are stored relative to the pack file. Sheets are PNG files named like 2_4000_SpriteTiles.png; only the tiles you\n"
                          "change are replaced (see docs/TEXTURES.md). Sprites and floors that share a tile share its replacement.",
                  foreground="#666").grid(row=5, column=0, columnspan=3, sticky="w", pady=(16, 0))
        self.v_ltex.trace_add("write", lambda *a: self.apply_tex_fields())
        self.v_ptex.trace_add("write", lambda *a: self.apply_tex_fields())

    # ---------------------------------------------------------------- refresh
    def update_title(self):
        name = os.path.basename(self.path) if self.path else "(not saved)"
        self.root.title("Painter Momopie level editor - %s%s" % (name, " *" if self.dirty else ""))

    def refresh_all(self):
        self.refresh_list()
        self.refresh_fields()
        self.refresh_enemies()
        self.redraw()
        self.update_title()

    def refresh_list(self):
        self.listbox.delete(0, "end")
        for i, lv in enumerate(self.pack.levels):
            self.listbox.insert("end", "%2d  %s" % (i + 1, lv.name))
        self.listbox.selection_set(self.cur)
        self.listbox.see(self.cur)

    def refresh_fields(self):
        lv = self.level
        self.loading = True
        self.v_name.set(lv.name)
        self.v_theme.set("auto" if lv.theme is None else str(lv.theme))
        self.v_music.set("auto" if lv.music is None else SONGS.get(lv.music, "$%02x" % lv.music))
        self.v_time.set("" if lv.time is None else str(lv.time))
        self.v_magic.set("" if lv.magic is None else str(lv.magic))
        self.v_bonus.set("auto" if lv.bonus is None else ("yes" if lv.bonus else "no"))
        self.v_variant.set("auto" if lv.variant is None else str(lv.variant))
        self.v_ltex.set(lv.textures)
        self.v_ptex.set(self.pack.textures)
        self.v_song.set(lv.song)
        self.v_title.set(lv.title)
        self.loading = False
        self.update_paint_label()
        self.draw_theme_preview()

    def update_paint_label(self):
        n = self.level.paint_cells()
        self.v_paint.config(text="Cells to paint: %d" % n + ("   (too many: at most 255)" if n > 255 else "   (no path yet)" if n == 0 else ""))

    def draw_theme_preview(self):
        c = self.theme_preview
        c.delete("all")
        if not self.tiles.ok:
            return
        th = self.theme_of(self.level, self.cur)
        self.thumbs = [self.tiles.cell(th, v, 32) for v in range(4)]
        for i, ph in enumerate(self.thumbs):
            c.create_image(i * 36 + 2, 2, image=ph, anchor="nw")

    def refresh_enemies(self):
        self.tree.delete(*self.tree.get_children())
        w = self.wave.get()
        for i, (kind, x, y, delay) in enumerate(self.level.waves[w]):
            col, row = lp.cell_of(x, y)
            self.tree.insert("", "end", iid=str(i), values=("%d %s" % (kind, lp.KINDS.get(kind, "?")), col, row, delay))
        if self.selected and self.selected[0] == w and str(self.selected[1]) in self.tree.get_children():
            self.tree.selection_set(str(self.selected[1]))
        self.redraw()

    def redraw(self):
        c = self.canvas
        c.delete("all")
        lv = self.level
        th = self.theme_of(lv, self.cur)
        self.photos = []
        for r in range(16):
            for col in range(16):
                v = lv.map[r][col]
                x0, y0 = col * CELL, r * CELL
                if self.tiles.ok:
                    ph = self.tiles.cell(th, v, CELL)
                    c.create_image(x0, y0, image=ph, anchor="nw")
                else:
                    c.create_rectangle(x0, y0, x0 + CELL, y0 + CELL, fill=FLAT[v], outline="#404060")
                if v:
                    c.create_rectangle(x0, y0, x0 + CELL, y0 + CELL, outline="#ffffff" if (col, r) == (7, 6) else "", width=1)
        # the player start
        px, py = 7 * CELL + CELL // 2, 6 * CELL + CELL // 2
        c.create_text(px, py, text="P", fill="#ffffff", font=("TkDefaultFont", 12, "bold"))
        c.create_oval(px - 12, py - 12, px + 12, py + 12, outline="#40ff40", width=2)
        cur = self.wave.get()
        for w in range(6):
            if not self.show_all.get() and w != cur:
                continue
            for i, (kind, x, y, delay) in enumerate(lv.waves[w]):
                col, row = lp.cell_of(x, y)
                cx, cy = col * CELL + CELL // 2, row * CELL + CELL // 2
                rad = 12 if w == cur else 8
                sel = self.selected == (w, i)
                icon = self.icons.get(kind)
                if icon and w == cur:                       # the picture of the enemy on a ring in the colour of its wave
                    c.create_oval(cx - 17, cy - 17, cx + 17, cy + 17, fill=WAVE_COLORS[w], outline="#ffffff" if sel else "#000000", width=3 if sel else 1)
                    c.create_image(cx, cy, image=icon)
                    self.photos.append(icon)
                    continue
                c.create_oval(cx - rad, cy - rad, cx + rad, cy + rad, fill=WAVE_COLORS[w], outline="#ffffff" if sel else "#000000", width=3 if sel else 1,
                              stipple="" if w == cur else "gray50")
                c.create_text(cx, cy, text=str(kind), fill="#ffffff", font=("TkDefaultFont", 9, "bold"))
        self.info.config(text="%s - %d path cells - %d enemies in wave %d" % (lv.name, lv.paint_cells(), len(lv.waves[cur]), cur))
        self.update_paint_label()
        warn = lp.problems(self.pack)
        self.status.config(text=("%d warning%s - Pack > Check the pack" % (len(warn), "" if len(warn) == 1 else "s")) if warn else "Pack looks good")

    # ---------------------------------------------------------------- editing
    def apply_level_fields(self, quiet=False):
        if self.loading:
            return
        lv = self.level

        def num(s):
            s = s.strip()
            if not s or s == "auto":
                return None
            try:
                return int(s, 0)
            except ValueError:
                return None
        lv.name = self.v_name.get()
        th = num(self.v_theme.get())
        lv.theme = None if th is None else max(0, min(16, th))
        m = self.v_music.get().strip()
        lv.music = None
        if m and m != "auto":
            try:
                lv.music = int(m.split()[0].replace("$", "0x"), 16)
            except ValueError:
                lv.music = num(m)
        lv.time = num(self.v_time.get())
        lv.magic = num(self.v_magic.get())
        b = self.v_bonus.get()
        lv.bonus = None if b == "auto" else 1 if b == "yes" else 0
        v = self.v_variant.get()
        lv.variant = None if v == "auto" else int(v)
        lv.song = self.v_song.get().strip()
        lv.title = self.v_title.get().strip()[:8]
        self.touch()
        self.listbox.delete(self.cur)
        self.listbox.insert(self.cur, "%2d  %s" % (self.cur + 1, lv.name))
        self.listbox.selection_set(self.cur)
        self.draw_theme_preview()
        self.redraw()

    def apply_tex_fields(self):
        if self.loading:
            return
        self.level.textures = self.v_ltex.get().strip()
        self.pack.textures = self.v_ptex.get().strip()
        self.touch()

    # ---------------------------------------------------------------- undo and map tools
    def push_undo(self):
        self.undo_stack.append((self.cur, self.level.copy()))
        del self.undo_stack[:-100]
        self.redo_stack = []

    def undo(self):
        if not self.undo_stack:
            return
        idx, lv = self.undo_stack.pop()
        if idx < len(self.pack.levels):
            self.redo_stack.append((idx, self.pack.levels[idx].copy()))
            self.pack.levels[idx] = lv
            self.cur = idx
            self.selected = None
            self.touch()
            self.refresh_all()

    def redo(self):
        if not self.redo_stack:
            return
        idx, lv = self.redo_stack.pop()
        if idx < len(self.pack.levels):
            self.undo_stack.append((idx, self.pack.levels[idx].copy()))
            self.pack.levels[idx] = lv
            self.cur = idx
            self.selected = None
            self.touch()
            self.refresh_all()

    def transform(self, what):
        lv = self.level
        self.push_undo()
        if what == "lr":
            lv.map = [row[::-1] for row in lv.map]
            for w in lv.waves:
                for e in w:
                    col, row = lp.cell_of(e[1], e[2])
                    e[1], e[2] = lp.pos_of(15 - col, row, e[2] & 7)
        elif what == "tb":
            lv.map = lv.map[::-1]
            for w in lv.waves:
                for e in w:
                    col, row = lp.cell_of(e[1], e[2])
                    e[1], e[2] = lp.pos_of(col, 15 - row, e[2] & 7)
        elif what == "clear":
            lv.map = [[0] * 16 for _ in range(16)]
            lv.map[6][7] = 2
        elif what == "maze":
            lv.map = self.make_maze()
        self.touch()
        self.redraw()

    @staticmethod
    def make_maze():
        """a random maze of one cell wide corridors that includes the player start (column 7, row 6)"""
        cols = list(range(1, 14, 2))
        rows = list(range(2, 13, 2))
        m = [[0] * 16 for _ in range(16)]
        seen = set()
        start = (7, 6)
        stack = [start]
        seen.add(start)
        m[start[1]][start[0]] = 2
        while stack:
            c, r = stack[-1]
            nb = [(c + dx, r + dy) for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)) if (c + dx) in cols and (r + dy) in rows and (c + dx, r + dy) not in seen]
            if not nb:
                stack.pop()
                continue
            nc, nr = random.choice(nb)
            m[(r + nr) // 2][(c + nc) // 2] = 2
            m[nr][nc] = 2
            seen.add((nc, nr))
            stack.append((nc, nr))
        for _ in range(8):                                          # a few extra openings make loops
            c, r = random.choice(cols), random.choice(rows)
            dx, dy = random.choice(((2, 0), (0, 2)))
            if (c + dx) in cols and (r + dy) in rows:
                m[r + dy // 2][c + dx // 2] = 2
        return m

    def flood(self, c, value):
        col, row = c
        m = self.level.map
        old = m[row][col]
        if old == value:
            return
        self.push_undo()
        todo = [(col, row)]
        while todo:
            x, y = todo.pop()
            if 0 <= x < 16 and 0 <= y < 16 and m[y][x] == old:
                m[y][x] = value
                todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        self.touch()
        self.redraw()

    # ---------------------------------------------------------------- music files
    def song_path(self):
        return self.resolve(self.v_song.get().strip())

    def new_song(self):
        if not self.path:
            messagebox.showinfo("Music", "Save the pack first: songs are stored next to the pack file.")
            return
        name = "".join(ch if ch.isalnum() else "_" for ch in self.level.name).lower() or "song"
        rel = self.v_song.get().strip() or "%s.mml" % name
        target = self.resolve(rel)
        if not os.path.exists(target):
            example = os.path.join(HOME, "packs", "example_song.mml")
            if os.path.exists(example):
                shutil.copy(example, target)
            else:
                open(target, "w").write("title %s\ntempo 120\n\npulse1 duty=2 volume=12\n  L o4 c4 e4 g4 >c4 <g4 e4 c2 r2\n" % self.level.name)
        self.v_song.set(rel)
        self.edit_song()

    def browse_song(self):
        d = filedialog.askopenfilename(initialdir=self.pack_dir() or ROOT, filetypes=[("music text", "*.mml *.txt"), ("all", "*.*")])
        if d:
            base = self.pack_dir()
            try:
                self.v_song.set(os.path.relpath(d, base) if base else d)
            except ValueError:
                self.v_song.set(d)

    def edit_song(self):
        p = self.song_path()
        if not p or not os.path.exists(p):
            messagebox.showinfo("Music", "Choose or create a song first.")
            return
        if sys.platform == "win32":
            os.startfile(p)
        else:
            subprocess.Popen(["xdg-open", p])

    def listen_song(self):
        p = self.song_path()
        if not p or not os.path.exists(p):
            messagebox.showinfo("Music", "Choose or create a song first.")
            return
        head = lp.runner_path()
        if not head:
            messagebox.showinfo("Music", "game_headless was not found (build it with tools/build_port.py; the packaged folder has it next to the editor).")
            return
        wav = os.path.join(tempfile.gettempdir(), "pm_preview.wav")
        r = subprocess.run([head, "-", "900", "--song", p, "--wav", wav], capture_output=True, text=True)
        if "music:" in r.stderr:
            messagebox.showerror("Music", r.stderr.strip().splitlines()[-2] if len(r.stderr.strip().splitlines()) > 1 else r.stderr)
            return
        if sys.platform == "win32":
            import winsound
            winsound.PlaySound(wav, winsound.SND_FILENAME | winsound.SND_ASYNC)
        else:
            subprocess.Popen(["xdg-open", wav])

    def export_zip(self):
        if not self.path and not self.save():
            return
        self.save()
        out = filedialog.asksaveasfilename(defaultextension=".zip", filetypes=[("zip file", "*.zip")], initialfile=os.path.splitext(os.path.basename(self.path))[0] + ".zip")
        if not out:
            return
        base = self.pack_dir()
        files = {os.path.basename(self.path): self.path}
        refs = [self.pack.textures] + [lv.textures for lv in self.pack.levels]
        for rel in refs:
            d = self.resolve(rel) if rel else None
            if d and os.path.isdir(d):
                for root, _, names in os.walk(d):
                    for n in names:
                        full = os.path.join(root, n)
                        files[os.path.relpath(full, base)] = full
        for lv in self.pack.levels:
            if lv.song:
                full = self.resolve(lv.song)
                if full and os.path.exists(full):
                    files[os.path.relpath(full, base)] = full
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            for arc, full in files.items():
                z.write(full, arc.replace(os.sep, "/"))
        messagebox.showinfo("Export", "%d files written to %s" % (len(files), out))

    def cell_at(self, e):
        col, row = e.x // CELL, e.y // CELL
        return (col, row) if 0 <= col < 16 and 0 <= row < 16 else None

    def on_click(self, e):
        c = self.cell_at(e)
        if not c:
            return
        tool = self.tool.get()
        if tool == "fill":
            self.flood(c, int(self.fillbox_var.get()[-1]))
        elif tool.startswith("paint"):
            self.push_undo()
            self.set_cell(c, int(tool[-1]))
        else:
            hit = self.enemy_at(c)
            if hit:
                self.selected = hit
                self.wave.set(hit[0])
                self.load_enemy_fields()
                self.refresh_enemies()
            else:
                self.place_enemy(c)

    def on_drag(self, e):
        c = self.cell_at(e)
        tool = self.tool.get()
        if c and tool.startswith("paint"):
            self.set_cell(c, int(tool[-1]))

    def on_erase(self, e):
        c = self.cell_at(e)
        if not c:
            return
        if self.tool.get() == "enemy":
            hit = self.enemy_at(c)
            if hit:
                self.push_undo()
                del self.level.waves[hit[0]][hit[1]]
                self.selected = None
                self.touch()
                self.refresh_enemies()
        else:
            if e.type == tk.EventType.ButtonPress:
                self.push_undo()
            self.set_cell(c, 0)

    def set_cell(self, c, v):
        col, row = c
        if self.level.map[row][col] != v:
            self.level.map[row][col] = v
            self.touch()
            self.redraw()

    def enemy_at(self, c):
        cur = self.wave.get()
        order = [cur] + [w for w in range(6) if w != cur] if self.show_all.get() else [cur]
        for w in order:
            for i, (kind, x, y, delay) in enumerate(self.level.waves[w]):
                if lp.cell_of(x, y) == c:
                    return (w, i)
        return None

    def kind_value(self):
        try:
            return int(self.kind_box.get().split()[0])
        except (ValueError, IndexError):
            return 1

    def place_enemy(self, c):
        w = self.wave.get()
        if len(self.level.waves[w]) >= 60:
            messagebox.showinfo("Enemies", "A wave holds at most 60 enemies.")
            return
        self.push_undo()
        x, y = lp.pos_of(c[0], c[1], 1 if self.flag.get() else 0)
        self.level.waves[w].append([self.kind_value(), x, y, int(self.delay.get() or 0)])
        self.selected = (w, len(self.level.waves[w]) - 1)
        self.touch()
        self.refresh_enemies()

    def load_enemy_fields(self):
        if not self.selected:
            return
        w, i = self.selected
        kind, x, y, delay = self.level.waves[w][i]
        if kind in lp.KINDS:
            self.kind_box.current(sorted(lp.KINDS).index(kind))
        self.delay.set(delay)
        self.flag.set(1 if y & 7 else 0)

    def on_tree_select(self, e):
        sel = self.tree.selection()
        if sel:
            self.selected = (self.wave.get(), int(sel[0]))
            self.load_enemy_fields()
            self.redraw()

    def on_kind(self):
        if self.selected:
            w, i = self.selected
            self.level.waves[w][i][0] = self.kind_value()
            self.touch()
            self.refresh_enemies()

    def on_delay(self):
        if self.selected:
            w, i = self.selected
            en = self.level.waves[w][i]
            try:
                en[3] = max(0, min(255, int(self.delay.get())))
            except (ValueError, tk.TclError):
                return
            en[2] = (en[2] & ~7) | (1 if self.flag.get() else 0)
            self.touch()
            self.refresh_enemies()

    def del_enemy(self):
        if self.selected:
            self.push_undo()
            w, i = self.selected
            del self.level.waves[w][i]
            self.selected = None
            self.touch()
            self.refresh_enemies()

    def clear_wave(self):
        self.push_undo()
        self.level.waves[self.wave.get()] = []
        self.selected = None
        self.touch()
        self.refresh_enemies()

    # ---------------------------------------------------------------- levels
    def on_select_level(self, e):
        sel = self.listbox.curselection()
        if sel and sel[0] != self.cur:
            self.cur = sel[0]
            self.selected = None
            self.refresh_fields()
            self.refresh_enemies()

    def add_level(self):
        if len(self.pack.levels) >= lp.MAX_LEVELS:
            return
        self.pack.levels.insert(self.cur + 1, self.blank_level("Level %d" % (len(self.pack.levels) + 1)))
        self.cur += 1
        self.touch()
        self.refresh_all()

    def dup_level(self):
        if len(self.pack.levels) >= lp.MAX_LEVELS:
            return
        n = self.level.copy()
        n.name += " copy"
        self.pack.levels.insert(self.cur + 1, n)
        self.cur += 1
        self.touch()
        self.refresh_all()

    def del_level(self):
        if len(self.pack.levels) <= 1:
            messagebox.showinfo("Levels", "A pack needs at least one level.")
            return
        if messagebox.askyesno("Delete", "Delete level %d (%s)?" % (self.cur + 1, self.level.name)):
            del self.pack.levels[self.cur]
            self.cur = max(0, min(self.cur, len(self.pack.levels) - 1))
            self.touch()
            self.refresh_all()

    def move_level(self, d):
        j = self.cur + d
        if 0 <= j < len(self.pack.levels):
            L = self.pack.levels
            L[self.cur], L[j] = L[j], L[self.cur]
            self.cur = j
            self.touch()
            self.refresh_all()

    # ---------------------------------------------------------------- files
    def confirm_discard(self):
        if not self.dirty:
            return True
        a = messagebox.askyesnocancel("Unsaved changes", "Save the changes to the pack first?")
        if a is None:
            return False
        if a:
            return self.save()
        return True

    def new_pack(self):
        if not self.confirm_discard():
            return
        self.pack = lp.Pack()
        self.pack.levels.append(self.blank_level("Level 1"))
        self.path = None
        self.cur = 0
        self.dirty = False
        self.refresh_all()

    def open_dialog(self):
        if not self.confirm_discard():
            return
        p = filedialog.askopenfilename(initialdir=os.path.join(HOME, "packs") if os.path.isdir(os.path.join(HOME, "packs")) else HOME,
                                       filetypes=[("level packs", "*.pmpack *.zip"), ("all", "*.*")])
        if p:
            self.open_file(p)

    def open_file(self, p):
        try:
            if p.lower().endswith(".zip"):                 # a zipped pack is unpacked next to the zip (the editor then works on the unpacked copy)
                p = community.extract_zip(p, p + ".unpacked")
            self.pack = lp.load(p)
        except (OSError, ValueError, zipfile.BadZipFile) as ex:
            messagebox.showerror("Open", str(ex))
            return
        if not self.pack.levels:
            self.pack.levels.append(self.blank_level("Level 1"))
        self.path = p
        self.cur = 0
        self.dirty = False
        self.selected = None
        self.refresh_all()

    def save(self):
        if not self.path:
            return self.save_as()
        try:
            lp.save(self.pack, self.path)
        except OSError as ex:
            messagebox.showerror("Save", str(ex))
            return False
        self.dirty = False
        self.update_title()
        if self.auto_restart.get() and self.game_proc and self.game_proc.poll() is None:      # the test window is open: it restarts with the saved level
            self.launch(self.last_level)
        return True

    def save_as(self):
        p = filedialog.asksaveasfilename(defaultextension=".pmpack", filetypes=[("level packs", "*.pmpack")],
                                         initialdir=os.path.join(HOME, "packs") if os.path.isdir(os.path.join(HOME, "packs")) else HOME)
        if not p:
            return False
        self.path = p
        return self.save()

    def import_original(self):
        try:
            orig = lp.original()
        except (OSError, KeyError) as ex:
            messagebox.showerror("Original levels", "The original levels are read from the game data: %s" % ex + chr(10)*2 + "The editor looked for %s (and build/painter_momopie.gb in the folders above it)." % lp.data_path("painter_momopie.gb") + chr(10) + "Run tools/build.py, or put level_editor.exe in the folder made by tools/package.py.")
            return
        self.pack.levels.extend(orig.levels[:lp.MAX_LEVELS - len(self.pack.levels)])
        self.touch()
        self.refresh_all()

    def import_levels(self):
        p = filedialog.askopenfilename(filetypes=[("level packs", "*.pmpack"), ("all", "*.*")])
        if not p:
            return
        try:
            other = lp.load(p)
        except (OSError, ValueError) as ex:
            messagebox.showerror("Open", str(ex))
            return
        names = ["%d  %s" % (i + 1, lv.name) for i, lv in enumerate(other.levels)]
        dlg = tk.Toplevel(self.root)
        dlg.title("Choose the levels to add")
        lb = tk.Listbox(dlg, selectmode="extended", width=40, height=min(24, len(names)))
        for n in names:
            lb.insert("end", n)
        lb.pack(padx=8, pady=8)

        def ok():
            for i in lb.curselection():
                if len(self.pack.levels) < lp.MAX_LEVELS:
                    self.pack.levels.append(other.levels[i].copy())
            dlg.destroy()
            self.touch()
            self.refresh_all()
        ttk.Button(dlg, text="Add", command=ok).pack(pady=(0, 8))

    def export_level(self):
        p = filedialog.asksaveasfilename(defaultextension=".pmpack", filetypes=[("level packs", "*.pmpack")])
        if p:
            one = lp.Pack()
            one.title = self.level.name
            one.levels.append(self.level.copy())
            lp.save(one, p)

    def pack_properties(self):
        t = simpledialog.askstring("Pack", "Pack title:", initialvalue=self.pack.title, parent=self.root)
        if t is not None:
            self.pack.title = t
            a = simpledialog.askstring("Pack", "Author:", initialvalue=self.pack.author, parent=self.root)
            if a is not None:
                self.pack.author = a
            self.touch()

    def check_pack(self):
        warn = lp.problems(self.pack)
        messagebox.showinfo("Check the pack", "No problems found." if not warn else "\n".join(warn[:30]) + ("\n..." if len(warn) > 30 else ""))

    # ---------------------------------------------------------------- textures
    def pack_dir(self):
        return os.path.dirname(os.path.abspath(self.path)) if self.path else None

    def resolve(self, rel):
        if not rel:
            return None
        if os.path.isabs(rel):
            return rel
        d = self.pack_dir()
        return os.path.join(d, rel) if d else None

    def browse_folder(self, var):
        d = filedialog.askdirectory(initialdir=self.pack_dir() or ROOT)
        if d:
            base = self.pack_dir()
            try:
                var.set(os.path.relpath(d, base) if base else d)
            except ValueError:
                var.set(d)

    def make_sheets(self, var, level):
        if not self.path:
            messagebox.showinfo("Custom tiles", "Save the pack first: texture folders are stored relative to the pack file.")
            return
        rel = var.get().strip()
        if not rel:
            rel = "textures" if not level else "textures_%s" % "".join(ch if ch.isalnum() else "_" for ch in self.level.name).lower()
            var.set(rel)
        target = self.resolve(rel)
        scale = simpledialog.askinteger("Sheets", "Enlargement of the sheets (1-8; 4 gives 32x32 pixels per tile):", initialvalue=4, minvalue=1, maxvalue=8, parent=self.root)
        if not scale:
            return
        try:
            if lp.FROZEN:                                           # the packaged folder has the exported sheets in textures/: copy them
                src = os.path.join(HOME, "textures")
                if not os.path.isdir(src):
                    raise OSError("the textures folder next to the editor is missing")
                os.makedirs(target, exist_ok=True)
                for name in os.listdir(src):
                    if name.lower().endswith(".png") or name.lower() == "readme.ini":
                        shutil.copy(os.path.join(src, name), target)
            else:
                subprocess.run([sys.executable, os.path.join(ROOT, "tools", "export_textures.py"), "--scale", str(scale), "--out", target], check=True)
        except (subprocess.CalledProcessError, OSError) as ex:
            messagebox.showerror("Sheets", "Could not create the sheets (needs assets/gfx from tools/gb_dis.py --write): %s" % ex)
            return
        self.open_folder(var)

    def open_folder(self, var):
        d = self.resolve(var.get().strip())
        if not d:
            messagebox.showinfo("Folder", "Save the pack and choose a folder first.")
            return
        os.makedirs(d, exist_ok=True)
        if sys.platform == "win32":
            os.startfile(d)
        else:
            subprocess.Popen(["xdg-open", d])

    # ---------------------------------------------------------------- play
    def choose_game(self):
        p = filedialog.askopenfilename(title="game_win.exe", filetypes=[("program", "*.exe"), ("all", "*.*")])
        if p:
            self.settings["game"] = p
            save_settings(self.settings)

    def play(self, level):
        game = self.settings.get("game") or find_game()
        if not game or not os.path.exists(game):
            messagebox.showinfo("Play", "game_win.exe was not found. Build it with tools/build_port.py or choose it in Pack > Choose the game program.")
            self.choose_game()
            game = self.settings.get("game")
            if not game:
                return
        bad = lp.problems(self.pack)
        if bad and not messagebox.askyesno("Play", "The pack has %d warnings (for example %s).\nPlay anyway?" % (len(bad), bad[0])):
            return
        if not self.path and not self.save():
            return
        self.save()
        self.launch(level)

    def launch(self, level):
        """starts (or restarts) the test window on the saved pack at a level; the window of an earlier test is closed first"""
        game = self.settings.get("game") or find_game()
        if not game or not os.path.exists(game) or not self.path:
            return
        if self.game_proc and self.game_proc.poll() is None:
            self.game_proc.terminate()
            try:
                self.game_proc.wait(3)
            except subprocess.TimeoutExpired:
                self.game_proc.kill()
        self.last_level = level
        self.game_proc = subprocess.Popen([game, "--pack", os.path.abspath(self.path), "--round", str(level)], cwd=os.path.dirname(game))

    # ---------------------------------------------------------------- community packs (docs/COMMUNITY.md)
    def community_browse(self):
        """list of the community's packs from the repository, with preview, description and a download button"""
        win = tk.Toplevel(self.root)
        win.title("Community level packs")
        win.geometry("760x460")
        left = ttk.Frame(win)
        left.pack(side="left", fill="y", padx=8, pady=8)
        lb = tk.Listbox(left, width=34, height=20, exportselection=False)
        lb.pack(side="top", fill="y", expand=True)
        status = ttk.Label(left, text="Loading...", wraplength=240)
        status.pack(side="bottom", anchor="w", pady=4)
        right = ttk.Frame(win)
        right.pack(side="left", fill="both", expand=True, padx=8, pady=8)
        title = ttk.Label(right, text="", font=("TkDefaultFont", 12, "bold"), wraplength=440)
        title.pack(anchor="w")
        meta = ttk.Label(right, text="", wraplength=440)
        meta.pack(anchor="w")
        pic = ttk.Label(right)
        pic.pack(anchor="w", pady=6)
        desc = tk.Text(right, height=6, width=54, wrap="word", state="disabled")
        desc.pack(fill="x")
        btn = ttk.Button(right, text="Download and open", state="disabled")
        btn.pack(anchor="w", pady=8)
        ttk.Label(right, text="Packs are made by other players. They contain only maps, enemy lists, songs and pictures; the player checks every zip.", wraplength=440).pack(anchor="w")
        state = {"entries": [], "photo": None}
        results = []                                    # filled by the worker threads, read by the main thread

        def work(fn, then):
            def run():
                try:
                    results.append((then, fn(), None))
                except Exception as ex:                  # network errors and bad data are shown, not raised
                    results.append((then, None, ex))
            threading.Thread(target=run, daemon=True).start()

        def poll():
            while results:
                then, value, err = results.pop(0)
                if win.winfo_exists():
                    then(value, err)
            if win.winfo_exists():
                win.after(150, poll)

        def got_index(entries, err):
            if err:
                status.config(text="Could not load the list: %s" % err)
                return
            state["entries"] = entries
            for e in entries:
                lb.insert("end", "%s  (%s, %d level%s)" % (e["title"], e["author"], e["levels"], "" if e["levels"] == 1 else "s"))
            status.config(text="%d pack%s" % (len(entries), "" if len(entries) == 1 else "s") if entries else "No community packs yet. Be the first: Community > Submit.")

        def show(e):
            title.config(text=e["title"])
            meta.config(text="by %s - %d level%s - %d KB%s" % (e["author"], e["levels"], "" if e["levels"] == 1 else "s", (e.get("size", 0) + 1023) // 1024,
                                                               (" - " + ", ".join(e["tags"])) if e.get("tags") else ""))
            desc.config(state="normal")
            desc.delete("1.0", "end")
            desc.insert("1.0", e["description"])
            desc.config(state="disabled")
            btn.config(state="normal", command=lambda: download(e))
            pic.config(image="")
            if Image is not None:
                def got_pic(data, err):
                    if err or not data:
                        return
                    import io
                    im = Image.open(io.BytesIO(data))
                    state["photo"] = ImageTk.PhotoImage(im)
                    pic.config(image=state["photo"])
                work(lambda: community.fetch_preview(e), got_pic)

        def on_select(_):
            sel = lb.curselection()
            if sel:
                show(state["entries"][sel[0]])

        def download(e):
            if not self.confirm_discard():
                return
            btn.config(state="disabled")
            status.config(text="Downloading...")

            def fetch():
                dest = os.path.join(HOME, "packs", "community")
                zp = community.download(e, dest)
                return community.extract_zip(zp, os.path.join(dest, e["id"]))

            def done(path, err):
                btn.config(state="normal")
                if err:
                    status.config(text="Download failed: %s" % err)
                    return
                status.config(text="Saved in packs/community/%s" % e["id"])
                self.open_file(path)
                win.destroy()
            work(fetch, done)

        lb.bind("<<ListboxSelect>>", on_select)
        work(community.fetch_index, got_index)
        poll()

    def community_submit(self):
        """checks the pack and makes the folder to add to the community/packs folder of the repository; the editor itself sends nothing anywhere"""
        if not self.path and not self.save():
            return
        self.save()
        win = tk.Toplevel(self.root)
        win.title("Submit to the community")
        win.geometry("560x560")
        frm = ttk.Frame(win, padding=10)
        frm.pack(fill="both", expand=True)
        ttk.Label(frm, text="Share your pack with everybody: the level editor shows community packs under Community > Browse.\n"
                            "A submission is a folder (the pack as a zip, a description and a preview picture) that you add to the repository with a pull request.",
                  wraplength=520).pack(anchor="w")
        v_title, v_author, v_tags = tk.StringVar(value=self.pack.title), tk.StringVar(value=self.pack.author), tk.StringVar()
        for label, var in (("Title (60 characters)", v_title), ("Author name shown to everybody", v_author), ("Tags, separated by commas (optional)", v_tags)):
            ttk.Label(frm, text=label).pack(anchor="w", pady=(8, 0))
            ttk.Entry(frm, textvariable=var, width=60).pack(anchor="w")
        ttk.Label(frm, text="Description (what is special about the levels)").pack(anchor="w", pady=(8, 0))
        desc = tk.Text(frm, height=6, width=62, wrap="word")
        desc.pack(anchor="w")
        v_ok = tk.IntVar()
        ttk.Checkbutton(frm, variable=v_ok, text="I made these levels (no copies of the game's own levels, no pictures taken from the game),\n"
                                                 "and I agree that they are shared under the repository's MIT licence.").pack(anchor="w", pady=8)
        out = ttk.Label(frm, text="", wraplength=520, justify="left")
        out.pack(anchor="w", pady=4)
        btns = ttk.Frame(frm)
        btns.pack(anchor="w", pady=4)
        made = {}

        def make():
            if not v_ok.get():
                out.config(text="Please confirm that the levels are yours.")
                return
            title, author, text = v_title.get().strip(), v_author.get().strip(), desc.get("1.0", "end").strip()
            if not title or not author or not text:
                out.config(text="Title, author and description are needed.")
                return
            self.save()
            folder, errs = community.make_submission(self.path, title, author, text, os.path.join(HOME, "submissions"), v_tags.get().split(","))
            made["folder"] = folder
            if errs:
                out.config(text="Fix these first:\n- " + "\n- ".join(errs[:8]))
                return
            out.config(text="The submission folder is ready:\n%s\n\nNext: open the GitHub page, sign in, drag the three files of that folder in (the page asks you to put them in "
                            "community/packs/%s), and press \"Propose changes\". GitHub then makes the pull request for you; it is only sent when you do that."
                            % (folder, os.path.basename(folder)))
            open_btn.config(state="normal")
            web_btn.config(state="normal")

        def open_folder():
            if made.get("folder"):
                path = made["folder"]
                if sys.platform.startswith("win"):
                    os.startfile(path)
                else:
                    subprocess.Popen(["xdg-open", path])

        def open_web():
            if messagebox.askyesno("GitHub", "This opens the GitHub upload page in your browser. Nothing is sent from here.\nContinue?", parent=win):
                webbrowser.open(community.UPLOAD_URL)

        ttk.Button(btns, text="Check and make the submission folder", command=make).pack(side="left", padx=2)
        open_btn = ttk.Button(btns, text="Open the folder", command=open_folder, state="disabled")
        open_btn.pack(side="left", padx=2)
        web_btn = ttk.Button(btns, text="Open the GitHub upload page", command=open_web, state="disabled")
        web_btn.pack(side="left", padx=2)

    def help(self):
        messagebox.showinfo("How it works", "A pack is an ordered list of levels. Each level has a map (16 x 16 cells), up to six waves of enemies, a look,\n"
                            "music, a time and starting magic points. Fields left on 'auto' behave like the original game at that position.\n\n"
                            "The player starts on the circled cell and paints the path cells (everything that is not empty). Custom tiles replace the\n"
                            "graphics of one level or of the whole pack. Save the pack and press F5 (or Pack > Play) to try it in the game.\n\n"
                            "More: docs/LEVELS.md and docs/TEXTURES.md.")

    def quit(self):
        if self.confirm_discard():
            self.root.destroy()


def main():
    root = tk.Tk()
    root.minsize(900, 640)
    Editor(root, sys.argv[1] if len(sys.argv) > 1 else None)
    root.mainloop()


if __name__ == "__main__":
    main()

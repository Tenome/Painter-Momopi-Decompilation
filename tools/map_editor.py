#!/usr/bin/env python3
"""Room map editor for Painter Momopie mods (tkinter, standard library only).

    python tools/map_editor.py [assets/typed/round01.txt]

Opens one of the room maps in assets/typed/roundNN.txt (16 lines of 16 digits: 0 = wall/empty, 1 and 2 = path pieces, 3 = special).
Left click paints the selected brush, right click erases (0). The title shows the number of path cells (cells that are not 0): that is the number
the game paints to clear the round, so it has to match the entry of the round in assets/typed/paint_cells_per_round.txt. "Set paint count" writes
the count there for the round you pick. Save, then rebuild with `python tools/build.py --rgbds E:/rgbds --mod`.
"""
import os
import sys
import tkinter as tk
from tkinter import filedialog, messagebox

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TYPED = os.path.join(ROOT, "assets", "typed")
COLORS = {"0": "#202030", "1": "#e8c84a", "2": "#d98a2b", "3": "#6ab0e8"}
CELL = 30


class Editor:
    def __init__(self, master, path):
        self.master = master
        self.path = None
        self.grid = [["0"] * 16 for _ in range(16)]
        self.brush = "1"
        self.dirty = False
        bar = tk.Frame(master)
        bar.pack(fill="x")
        tk.Button(bar, text="Open", command=self.open).pack(side="left")
        tk.Button(bar, text="Save", command=self.save).pack(side="left")
        self.brush_var = tk.StringVar(value="1")
        for b in "0123":
            tk.Radiobutton(bar, text="brush " + b, variable=self.brush_var, value=b, command=self.pick, indicatoron=False,
                           bg=COLORS[b], fg="white" if b == "0" else "black", selectcolor=COLORS[b]).pack(side="left", padx=2)
        tk.Label(bar, text="  round").pack(side="left")
        self.round_var = tk.IntVar(value=1)
        tk.Spinbox(bar, from_=1, to=34, width=3, textvariable=self.round_var).pack(side="left")
        tk.Button(bar, text="Set paint count", command=self.set_paint_count).pack(side="left")
        self.canvas = tk.Canvas(master, width=16 * CELL, height=16 * CELL, highlightthickness=0)
        self.canvas.pack()
        self.canvas.bind("<Button-1>", lambda e: self.paint(e, self.brush))
        self.canvas.bind("<B1-Motion>", lambda e: self.paint(e, self.brush))
        self.canvas.bind("<Button-3>", lambda e: self.paint(e, "0"))
        self.canvas.bind("<B3-Motion>", lambda e: self.paint(e, "0"))
        if path:
            self.load(path)
        self.redraw()

    def pick(self):
        self.brush = self.brush_var.get()

    def load(self, path):
        lines = [l.strip() for l in open(path) if l.strip()]
        if len(lines) != 16 or any(len(l) != 16 or set(l) - set("0123") for l in lines):
            messagebox.showerror("Map", "%s is not a 16x16 map of digits 0-3" % path)
            return
        self.grid = [list(l) for l in lines]
        self.path = path
        self.dirty = False
        self.redraw()

    def open(self):
        path = filedialog.askopenfilename(initialdir=TYPED, filetypes=[("room maps", "round*.txt"), ("all", "*.*")])
        if path:
            self.load(path)

    def save(self):
        if not self.path:
            return
        with open(self.path, "w", newline="\n") as f:
            for row in self.grid:
                f.write("".join(row) + "\n")
        self.dirty = False
        self.redraw()

    def count(self):
        return sum(c != "0" for row in self.grid for c in row)

    def paint(self, event, value):
        x, y = event.x // CELL, event.y // CELL
        if 0 <= x < 16 and 0 <= y < 16 and self.grid[y][x] != value:
            self.grid[y][x] = value
            self.dirty = True
            self.redraw()

    def set_paint_count(self):
        path = os.path.join(TYPED, "paint_cells_per_round.txt")
        try:
            values = open(path).read().split()
            index = self.round_var.get() - 1
            values[index] = str(self.count())
            open(path, "w", newline="\n").write(" ".join(values) + "\n")
        except (OSError, IndexError) as e:
            messagebox.showerror("Paint count", str(e))
            return
        messagebox.showinfo("Paint count", "round %d: %d cells" % (index + 1, self.count()))

    def redraw(self):
        self.canvas.delete("all")
        for y in range(16):
            for x in range(16):
                self.canvas.create_rectangle(x * CELL, y * CELL, x * CELL + CELL, y * CELL + CELL, fill=COLORS[self.grid[y][x]], outline="#404060")
        name = os.path.basename(self.path) if self.path else "(no file)"
        self.master.title("Painter Momopie map editor - %s%s - %d path cells" % (name, " *" if self.dirty else "", self.count()))


def main():
    root = tk.Tk()
    Editor(root, sys.argv[1] if len(sys.argv) > 1 else os.path.join(TYPED, "round01.txt"))
    root.mainloop()


if __name__ == "__main__":
    main()

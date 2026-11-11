# Tutorial: your first level

`packs/tutorial.pmpack` is a small pack that introduces the mechanics one at a time; play it (`game_win.exe --pack packs/tutorial.pmpack`, or choose it in `settings.exe`) and open it
in the editor to see how it is made.

| Level | Teaches |
|---|---|
| 1 First steps | the plus shaped room: paint every path cell by walking over it; no enemies |
| 2 One chaser | a single chasing enemy (kind 1) that appears 6 seconds in |
| 3 Wanderers | wandering enemies (kind 2) on a grid of paths |
| 4 Statues | statues (kind 0) that stand on the path, and a chaser to dodge |
| 5 Gauntlet | two waves, a shooter (kind 10) and chasers |

## Make your own level in ten minutes

1. `python tools/level_editor.py` (needs Python 3 with tkinter and Pillow; the real room tiles are shown when you have built `build/painter_momopie.gb` with `tools/build.py`).
2. *File > New pack*. The pack starts with one empty level. Click the **Path 1** tool and drag across the map to paint the path the player walks on. Cells that are not a path are walls.
   The player starts on the cell marked **P** (column 7, row 6), which must be a path.
3. Every path cell must be joined to the start. The status bar warns about problems; *Pack > Check the pack* lists them.
4. Switch to the **Enemy** tool, pick a kind on the *Enemies* tab and the second at which it appears (the *delay*), and click a path cell. Click an enemy to select it, right click to delete it.
   Wave 0 starts with the round; when its enemies are gone, the next wave comes.
5. On the *Level* tab give the level a name, a *look* (the tile set: 0-16), a time limit, and an intro title of up to 8 letters.
6. Press **F6**: the game opens on your level. Paint, press Ctrl+S, and the test window restarts at once on the new version.
7. Add more levels with *Add* in the level list, reorder with *Move up/down*, and play them all with F5.
8. Share it: *File > Export the pack as a zip file*, or *Community > Submit this pack to the community...* (`docs/COMMUNITY.md`).

More: `docs/LEVELS.md` (everything the editor can do and the pack file format), `docs/MUSIC.md` (your own songs), `docs/TEXTURES.md` and `docs/SPRITES.md` (your own pictures).

# Modding

The build never needs the original ROM: it assembles `src/*.asm` and includes the data files in `assets/`, which are extracted from your own ROM and
are not stored in git. Edit the assets or the source, rebuild, and play the result.

```
python tools/gb_dis.py --write              # once: extract assets/ and PNG sheets from orig/painter_momopie.gb (resets any edits!)
... edit assets/gfx/*.png, assets/bank_NN/*.bin or src/*.asm ...
python tools/build.py --rgbds E:/rgbds --mod   # writes build/painter_momopie.gb (without --mod it compares with the original)
```

## What is editable now

| Asset | Where | Format |
|---|---|---|
| Sprite and background tiles (title logo, fonts, icons, characters, enemies, castle) | `assets/gfx/<bank>_<addr>_<name>.png` | 128 pixels wide sheets, 16 tiles per row, four greys (255, 170, 85, 0) |
| Room maps (15 distinct) | `assets/typed/roundNN.txt` | 16 lines of 16 digits, 0 = empty, 1 and 2 = path pieces |
| Enemy spawns per round | `assets/typed/spawn_roundNN.txt` | `wave N`, then `kind x y delay`; the low 3 bits of `y` are variant flags; keep the number of spawns per wave |
| Sprite shapes (positions of the 8x8 parts) | `assets/typed/object_shapes.txt` | `shape @addr N` then N lines `x y`; size must stay the same |
| Animation frames (36 regions) | `assets/typed/anim_BB_AAAA.txt` | `frame S t t ...` (shape id, then one tile id per part of that shape, hex); size must stay the same |
| Music and sound effects (11 songs, 7 effects) | `assets/typed/song_*.txt`, `sfx_*.txt` | `head` lines (channel, envelope, tempo, stream label), `:label` lines, then `N xx` notes, `L xx` lengths, `C xx ...` commands (format in `tools/song_fmt.py`); the size of each song must stay the same |
| Balance tables | `assets/typed/magic_cost_by_card.txt` (MP per card id), `magic_points_by_round.txt` (starting MP per round, 34 values), `seconds_per_round_block.txt` (time per 4 rounds), `paint_cells_per_round.txt` (cells to paint; must match the number of path cells of the map) | decimal values |
| Everything else (room maps, enemy spawn lists, text jobs, animations, shapes, sound streams, tables) | `assets/bank_NN/<addr>_<label>.bin` | raw bytes; formats are described in `REVERSE.md` (room maps are 2 bits per cell, spawn lists 4 bytes per entry, animations `shape id + tile ids`, text uses the charmap) |
| Game logic | `src/bank_NN.asm`, `src/constants.inc` | RGBDS assembly with named routines and RAM variables |

Sizes must stay the same for files that sit between code (a longer file moves everything after it and breaks the fixed bank layout); data-only
regions with padding after them (`Bank2Padding`, `Bank3Padding`, the end of bank 1) can use the spare bytes if you shrink the file after it.

## Native builds with mods

`python tools/build_port.py` recompiles the traced routines to C and reads the ROM at run time, so a modded ROM (`build/painter_momopie.gb`) can be
played natively as is: `build\recomp\game_win.exe build\painter_momopie.gb`. Code changes need `tools/gb_dis.py` to be re-run only if you want the
disassembler to trace your new code (it works from the original ROM); edit `src/*.asm` directly for code mods and rebuild with `tools/build.py --mod`.

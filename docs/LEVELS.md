# Custom level packs

The native player (`game_win.exe`) can play a **level pack** instead of the game's 33 built-in rounds: any number of levels (1-99), in any order, each with its
own map, enemies, look, music, time and starting magic points, and optionally its own full-colour tiles. A pack is one text file (`*.pmpack`).
The original game is unchanged, and with no pack selected nothing differs from it (the frame-by-frame checks run without a pack; a pack made from the original
33 rounds plays identically to the built-in rounds).

## Making a pack: the level editor

```
python tools/level_editor.py [packs/example.pmpack]
```

Needs Python with tkinter and Pillow. If `build/painter_momopie.gb` exists (run `python tools/build.py --rgbds E:/rgbds --mod`) the editor draws the real room tiles,
otherwise flat colours.

* **Levels** (left): add, copy, delete, move up and down. The order of the list is the play order; the pack ends after the last level (the ending plays).
* **Map** (middle): choose a tool and click. *Path 1/2* and *Special* paint cells, *Empty* erases, right click erases. Everything that is not *Empty* is a path
  cell the player must paint; the round is won when all of them are painted. The circled cell is where the player starts (column 7, row 6): keep it a path.
* **Level tab:** name, *look* (0-16: the tile set, floor and wall tiles and room name of one of the game's 17 rooms), music, time, starting magic points,
  whether the bonus screens follow, and the enemy flag bit. *auto* means "like the original game at this position of the list".
* **Enemies tab:** six waves. Pick the *Enemy* tool, choose the kind and when it appears (seconds into the round) and click a cell. Click an enemy to select it,
  right click to delete it. At most three enemies are alive at once; when a wave is finished the next one starts; after wave 5 they repeat.
* **Own song** (Level tab): a music text file for the level (New / Edit / Browse / Listen), see docs/MUSIC.md.
* **Custom tiles tab:** texture folders for the whole pack and for the current level (see below).
* **Edit** menu: undo and redo (Ctrl+Z, Ctrl+Y), mirror the map, clear it, or make a random maze. The *Fill* tool fills a region.
* **File** menu: save/load, *Add the game's 33 original levels* (read from your ROM build), *Add levels from another pack* (pick which), *Export the current level*, *Export the pack as a zip file* (with its tiles and songs, to share).
* **Pack** menu: check the pack for problems, *Play the pack* (F5) or *Play from the current level* (F6) in `game_win.exe`.

## Checking a pack

`python tools/pack_check.py pack.pmpack [--play]` runs the editor's checks (map, enemies, sizes, and that every path cell can be reached from the player's start,
so the level can be cleared) and, with `--play` (needs `game_headless` from `tools/build_port.py`), starts every level in the native runner with random buttons
to see that it runs and whether the random walk clears it. The editor shows the enemy pictures taken from your game (`tools/enemy_icons.py` makes them on the
first start and keeps them in `tools/.enemy_icons/`, which is not committed).

## Playing a pack

`level_pack` can also be a `.zip` file (the editor's *Export the pack as a zip file* makes one: the pack file, its texture folders and songs). The player
unpacks it to a folder next to it (`<name>.zip.unpacked`) and plays the pack from there.

Set `level_pack=path\to\file.pmpack` in `painter_momopie.ini` (or choose it in `settings.exe`), or start `game_win.exe --pack file.pmpack [--round N]`.

## Custom tiles for a pack or a single level

Replace tiles with full-colour PNG pictures (see `docs/TEXTURES.md` for the sheets and rules):

* `textures folder` before the first level: the folder used by every level of the pack.
* `textures folder` inside a level: used only while that level is played (it is loaded when the level starts and replaces the previous level's folder).
* The player's own `texture_pack` of `painter_momopie.ini` is the base layer; the pack's folder is on top of it and the level's folder on top of that.

Folders are relative to the `.pmpack` file. In the editor the *Custom tiles* tab creates the template sheets (`tools/export_textures.py`) and opens the folder. A
Halloween level, for example, repaints the floor, wall and enemy tiles in a folder used by that level alone. Tiles are matched by content: the floor of every room that
uses the same 8 x 8 picture changes together (which is what you want inside one level's folder).

## File format

```
pack Pack title
author Somebody
textures folder             (optional, every level)

level Level name
theme 3                     0-16 (default: as the original at this position)
title NIGHT                 up to 8 letters (A-Z, 0-9) shown as the room name on the round intro screen (default: the look's own name)
music 0x86                  song id $81-$8b (default: original)
song tune.mml               (optional) a song of your own instead (docs/MUSIC.md), relative to the pack file
time 90                     seconds (default: original)
magic 100                   starting magic points (default: original)
bonus 0                     1 = the bonus screens follow this level (default: after levels 3, 7, 11, 19, 23 and 27)
variant 1                   spawn flag bit, 1 or 2 (default: 1 up to level 16, 2 from level 17)
textures folder             (optional, only this level)
map
0000000000000000            16 rows of 16 digits: 0 empty, 1 and 2 paths, 3 special
...
wave 0                      waves 0-5
1 136 138 4                 kind x y delay
end
```

`x = column * 16 + 24` and `y = row * 16 + 24` (the low 3 bits of `y` are the variant flag of the enemy). Enemy kinds are 0-13 (0, 6 and 8 stand still, 1 chases,
4 is the time-up enemy that paint cannot hurt, 7 walks a fixed path, 10 and 12 shoot, 11 hides under a tile, 13 is the last round's chaser).
A pack holds at most 255 path cells per level and about 16 KB of enemy data in total.

`python tools/levelpack.py check pack.pmpack` lists problems; `python tools/levelpack.py original` writes the game's own 33 rounds as `packs/original.pmpack`
(made from your ROM build, so it is not part of the repository).

## How it works in the game

`port/levelpack.c` reads the file; `port/logic.c` asks the pack instead of the game's tables at the places where a round starts (map, look, number of cells, time,
music, magic points, enemy waves, bonus screens and the end of the game). The enemy waves are stored in the game's own wave list format and read through a
window at `$4000` (`gb_pack_view`), so the lifted spawn routine is the original one.

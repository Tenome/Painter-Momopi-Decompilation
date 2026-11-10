# Full-colour textures

The Game Boy has four grey shades per tile; the native player (`game_win.exe`) can replace tiles with full-colour (and transparent) pictures from a folder of PNG
files, so anyone can restyle the sprites, floors and fonts without touching the ROM data. The replacement happens in the renderer only: the game logic,
the ROM and the save of graphics in `assets/gfx` are not changed.

## Making a pack

```
python tools/gb_dis.py --write            # once, needs your ROM: extracts assets/gfx
python tools/export_textures.py --scale 4 # writes textures/<bank>_<addr>_<name>.png, every tile sheet enlarged 4 times
```

Paint over the sheets in any editor (Aseprite, GIMP, Krita, Photoshop ...). Rules:

* Keep the file names and the size: 128 x N pixels wide (16 tiles per row), N = 1 to 8. Each tile is 8 * N pixels square. Different sheets may use different N.
* Any colours, and transparency (alpha) for sprites. A tile you do not change keeps the Game Boy look and palette behaviour; only tiles that differ from the
  plain greyscale tile are replaced.
* Sprites: an untouched background pixel stays transparent. To make a pixel solid, paint it (it then counts as changed). To cut a hole in an opaque
  sprite pixel, make it fully transparent.
* The picture is a 160-pixel-wide screen scaled up to N times (the largest N of the pack), so a 4x pack gives 640 x 576. Tiles without a replacement are drawn flat
  at that scale with the selected palette (F2 / `palette`).
* The Game Boy fades (screen transitions) lighten replaced tiles towards white as well.

Tiles are found by their content, not by their place: if the same 8x8 picture appears in two sheets, one replacement covers both (the first sheet wins). Tiles
that use the same graphics in different places (for example the floor) therefore stay consistent.

Painting a whole character instead of single tiles: see `docs/SPRITES.md`.

## Using a pack

In `game_win.exe` F5 reloads the texture folders while the game runs: paint, save the PNG, press F5.

Put the folder next to `game_win.exe` (default name `textures`) or set `texture_pack` in `painter_momopie.ini` (or the folder in `settings.exe`), then start the game.
The loader reports what it replaced on the console of `game_headless` (`game_headless - 600 --ini painter_momopie.ini --shot 500` writes `rc_0500.ppm`).

## What the sheets contain

| Sheet | Contents |
|---|---|
| `2_4000_SpriteTiles` | player, enemies, effects, the common sprites |
| `2_4700_SpriteSet0` ... `2_6b00_SpriteSet4` | the tile sets of the rooms (floor, walls, props), chosen by the round |
| `3_4000_TilesTitle`, `3_5000_TilesIcons`, `3_6000_TilesEnding`, `3_6e10_TilesFont2` | title screen, magic screen and HUD, ending, the second font |

Code: `port/texture.c` (loader), `port/png.c` (PNG reader), `tools/make_tile_index.py` (the original tile bytes), `render` in `port/gb_rt.c`.

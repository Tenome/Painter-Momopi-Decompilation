# Text, fonts and translating

The game has no text rendering. Every letter is an 8x8 tile in a tile sheet, and a message is a list of tile numbers copied into the background map. So the words of the game are
**pictures**: repaint the tiles in a texture pack (`docs/TEXTURES.md`) and the words change, in full colour and with any lettering you like.

Tile number = row * 16 + column in the sheet, for example `$c3` is row C, column 3. The sheets are loaded at tile 0 of video memory when a screen starts, so the numbers below are
the numbers the game uses.

## Which sheet is on which screen

| Sheet (`textures/`) | Screens |
|---|---|
| `3_4000_TilesTitle` | the title screen, the round intro ("ROUND 01", room name, lives), game over, continue |
| `3_5000_TilesIcons` | the magic screen (card pictures and names, magic points, time, score) |
| `3_6000_TilesEnding` | the bonus screens and the ending scenery (castle, trees) |
| `3_6e10_TilesFont2` | the ending credits (lower case font) |

## `3_4000_TilesTitle`

| Tiles | Contents |
|---|---|
| $00-$7f | the title logo (the katakana ペインター モモピー) cut into tiles, and the player and enemy pictures of the title; the logo is drawn from a list that places each tile |
| $80-$99 | the capital letters A to Z |
| $9a | the copyright mark |
| $9b-$ab | "1990. Sigma Enterprises, Inc" (a small proportional font, a few letters per tile) |
| $ab-$af, $bb-$bf | the digits 0-4 and 5-9 (also used for the score, time and lives) |
| $b0-$b3 | "!" and "?" and the small cursor picture |
| $c0-$df | pictures of the player and enemies for the intro screens |

The round intro writes the room's name as eight tiles (letters A-Z and spaces) from one of the 17 name lists in the game data; a level pack's *intro title* (docs/LEVELS.md) uses the same letters.

## `3_5000_TilesIcons`

| Tiles | Contents |
|---|---|
| $00-$8f | the nine magic card pictures, 4x4 tiles each |
| $98-$bf (right part) | the card frame, the clock, the digits |
| $c0-$ff | the card names as 8-tile words: S.UP, SEALED, CLEAR, W.IN, FRIEND, T.STOP, PYON, GHOST, B.O.M, and MOMOPIE'S MAGIC |

## `3_6e10_TilesFont2`

| Tiles | Contents |
|---|---|
| $80-$99 | lower case a to z |
| $9a-$a3 | digits 0 to 9 |
| $a4-$af | punctuation |
| $b4-$b8 | "SIGMA" |

## Translating

To translate or restyle:

1. Export the sheets (`python tools/build_port.py` writes `build/recomp/textures/`; `python tools/export_textures.py --scale 4 --out textures`).
2. Repaint the lettering tiles in an image editor. Each tile is 32x32 pixels at 4x, so a 4x4-tile card name is a 128x32 picture; paint across tile borders freely, the game only cares about the 8x8 pieces.
3. Press F5 in the player to see the result.

Limits: the arrangement of tiles on a screen (which tile goes where, and how many) is fixed by the game's data, so a word can only be as long as the slot it fills (a name list is 8 tiles;
a card name is 8 tiles). Tiles with the same picture share one replacement, so two screens cannot use the same letter tile differently. Very long text would need the game's tile lists patched; the
lists are in `assets/typed/` as text (see `docs/MODDING.md`), and the native player can load a modified ROM image.

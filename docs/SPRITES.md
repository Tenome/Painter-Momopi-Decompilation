# Painting the player (and other characters)

Texture packs (`docs/TEXTURES.md`) replace 8x8 tiles. A character is built from several tiles, so there are two ways to work:

* **Whole character** (easiest): `python tools/sprite_sheet.py assemble --sheet textures/2_4000_SpriteTiles.png --out player.png` puts all nine frames of the player into one picture
  (three rows: down, side, up; three frames each). Paint it in any editor with any colours, then
  `python tools/sprite_sheet.py split --sheet textures/2_4000_SpriteTiles.png --edited player.png` cuts it back into the sheet. Keep the picture's size. Press F5 in the player to see it.
  (Needs `build/painter_momopie.gb` and Pillow; the pictures come from your game, keep them out of git.)
* **Tile by tile**: edit `2_4000_SpriteTiles.png` directly, using the table below.

A quick example: `python tools/make_example_player.py` writes `textures_example/` with a purple player; set `texture_pack=textures_example` in `painter_momopie.ini`.

## Transparency

In the exported sheets the white of a sprite tile is the Game Boy's transparent shade. A white pixel you leave alone stays transparent; to make a pixel a solid light colour, paint
it with a colour that is not exactly white (for example 254,254,254). Black and the two greys are solid shades; replace them with whatever you like.

## The frames of the player

The player is six tiles per frame: two wide, three high, drawn around the position with the offsets -8/0 across and -16/-8/0 down (shape 0 of the shape table at `$06a4`).
Every frame has its own six tiles, but the top two tiles of each *up* frame ($40-$45) have the same picture as the top two of the *down* frames ($10-$15) in the game's graphics. Tiles with the same picture share one replacement, so paint the hats of the down and up frames the same (the split tool warns when you do not). The walk cycle plays frame 1, 2, 3, 2.

| Frame | Record (bank 1) | Tiles, top left to bottom right |
|---|---|---|
| down, frame 1 | $48dc | $10 $11 $20 $21 $30 $31 |
| down, frame 2 | $48e3 | $12 $13 $22 $23 $32 $33 |
| down, frame 3 | $48ea | $14 $15 $24 $25 $34 $35 |
| side, frame 1 (facing left) | $48f1 | $16 $17 $26 $27 $36 $37 |
| side, frame 2 | $48f8 | $18 $19 $28 $29 $38 $39 |
| side, frame 3 | $48ff | $1a $1b $2a $2b $3a $3b |
| up, frame 1 | $4906 | $40 $41 $50 $51 $60 $61 |
| up, frame 2 | $490d | $42 $43 $52 $53 $62 $63 |
| up, frame 3 | $4914 | $44 $45 $54 $55 $64 $65 |

Where a tile is in the sheet: the sheet has 16 tiles per row, so tile `$10` is row 1, column 0 and tile `$31` is row 3, column 1; at 4x enlargement a tile is 32 pixels square and tile *t*
starts at x = (*t* mod 16) * 32, y = (*t* div 16) * 32.

Walking right shows the side frames mirrored (the game flips the sprite), so paint the side row facing left.

Tiles are found by their content: if the same 8x8 picture is used by another sprite, your replacement changes that one as well. A plain empty tile (all transparent) is shared by many sprites; do not paint on those.

## Other characters

Every object is a record of a shape number followed by the tile numbers of its parts (the player's are in the table above). `tools/sprite_sheet.py` takes any list of such records:
`--frames 0x48dc,0x48e3 --columns 2` assembles those frames (the shape's part offsets decide where each tile goes). The enemies' records are listed through the animation pointer tables in
`src/bank_01.asm` (labels `*Anim*`); `tools/enemy_icons.py` shows what each enemy kind looks like.

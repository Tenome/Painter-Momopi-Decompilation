# Painter Momopie (Game Boy) — Reverse Engineering Notes

## Binary Identification

| Field | Value |
|-------|-------|
| File | `orig/painter_momopie.gb` (user's copy of `Painter Momopie.gb`) |
| Format | Game Boy ROM, Nintendo logo at $104 (valid), header checksum $E9 (valid), global checksum $F43B (valid) |
| Platform | Game Boy (DMG only, no CGB/SGB flags) |
| CPU | SM83 (LR35902) |
| ROM/File size | 65,536 bytes = 4 banks x 16 KiB; SHA-1 `193901223ffc89cf4f42a19e57447249affcc843` |
| Cartridge | type $01 = MBC1, ROM size code 1 (64 KiB), no RAM, no battery, destination Japan, old licensee $D3 |
| Title | `PAINTERMOMOPIE` |
| Entry point | $0100: `nop; jp $0150`; `Start` at $0150 sets SP=$DFFF, switches bank via `ld [$3fff],a`, clears WRAM ($C000, $1FEF bytes) and HRAM, sets palettes $E4, enables VBlank, LCDC=$93 |

---

## Memory Map

| Address Range | Purpose |
|---------------|---------|
| $0000-$3FFF | ROM bank 0 (fixed). Vectors: $00 `jp $04C9` (rst $00 = word jump table dispatcher), $40 `jp $02C0` (VBlank), $58 `jp $0221` (serial), $48/$50/$60 `reti` |
| $4000-$7FFF | ROM banks 1-3 (MBC1, selected by writing $2000-$3FFF; this game writes $3FFF) |
| $8000-$9FFF | VRAM |
| $C000-$DFFF | WRAM (SP starts at $DFFF) |
| $FE00-$FE9F | OAM |
| $FF00-$FF7F | I/O registers |
| $FF80-$FFFE | HRAM |

---

## Data-Range Map

Traced by `tools/gb_dis.py` (21% code) and confirmed with tile sheets (`tools/tilesheet.py`) and the emulator.

| Start | End | Classification | Notes |
|-------|-----|----------------|-------|
| bank 0 $0000-$00ff | | vectors, $ff padding | VBlank at $40, serial at $58, `rst $00` dispatcher |
| bank 0 $0100-$014f | | cartridge header | |
| bank 0 $0150-$3fff | | code (about 7 KB) and data tables | mode handlers, VBlank, VRAM copy queues, DrawObject, text/room data |
| bank 1 $4000-$4156 | | sound tables (frequencies, song offsets) | `SoundFrequencyTable` $4048 |
| bank 1 $4157-$487a | | sound engine | `SoundUpdate` |
| bank 1 $487b-$7f54 | | game logic code and data (animations, rooms, maps) | `PlayFrame` $4bde |
| bank 1 $7f55-$7fff | | $ff padding | |
| bank 2 $4000-$73ff | | 2bpp sprite tiles (characters, enemies) | `SpriteTiles` |
| bank 2 $7400-$7fff | | $ff padding | |
| bank 3 $4000-$7e0f | | 2bpp background tiles: title logo, fonts, icons, castle | `TilesTitle`, `TilesIcons`, `TilesEnding`, `TilesFont2` |
| bank 3 $7e10-$7fff | | $ff padding | |

-------|-----|------|----------------|-------|
| bank 0 $0000 | $00FF | 256 | vectors + $FF padding | |
| bank 0 $0100 | $014F | 80 | cartridge header | `db` |
| bank 0 $0150 | ... | ~12 KB | code (291 routines) + data | |
| bank 1 $4000 | $4156 | 343 | data (starts $CD $CD $CD $CD ... then word table at $4048) | |
| bank 1 $4157 | ... | ~3.9 KB | code (119 routines, entered from bank 0) | |
| banks 1-3 rest, bank 2, bank 3 | | ~48 KB | unclassified (graphics, maps, text, music likely) | |

Traced as code: 9,379 bytes (14.3 %). Everything else is `db` in `src/bank_NN.asm`.

---

## Key Findings

### Architecture

- `rst $00` is a table dispatcher: `RstJumpTable` at $04C9 (`add a,a; pop hl; ...; jp hl`); the words after each `rst $00` are
  jump targets (the tracer follows them while they point at plausible code).
- Bank 1 is a code bank (game logic using RAM variables at $C3xx/$C5xx); eight entry points are called from bank 0 and listed in
  `seeds.csv`. Banks 2 and 3 are mostly data so far (large $FF/$00 runs).
- `$FF` bytes are padding in this ROM, never `rst $38`.

- Frame model: `VBlankHandler` ($02c0) does the work flagged in `hVBlankTasks` ($ffb3): bit0 `VramCopyList`, bit1 OAM DMA
  (`OamDmaRoutine` copied to HRAM $ff80 by `CopyOamDmaRoutine`), bit2 `VramCopyRows`; then writes SCX/SCY from `wScrollX/Y`,
  calls the bank 1 per-frame routine at $4157, bumps `hFrameCounter` and sets `hVBlankFlag`. Main code waits with
  `WaitVBlankFlag`/`DelayFrames`. `hJoyHeld` = $0f (all four dpad bits) is the soft-reset combo that jumps back to `Entry`.
- Game modes (`GameModeDispatch` $01ad, `rst $00`, 8 entries; `tables.csv` pins the length). Confirmed by running the ROM in `tools/emu.py`
  and rendering each mode (jump to $01ad with A = mode):

  | Mode | Handler | Screen |
  |---|---|---|
  | 0 | `Mode0_Title` | title: "Painter Momopie" logo, 1 PLAYER / 2 PLAYER, (c)1990 Sigma Enterprises, LICENSED BY NINTENDO; boot-time serial handshake |
  | 1 | `Mode1_Play` | gameplay: the painter (witch hat) walks the path cells of a room and paints them white; enemy sprites roam the room |
  | 2 | `Mode2_BonusSelect` | after a cleared round: "CONGRATURATION!! BONUS : 10000P / I WANT TO GIVE YOU GOOD PRESENT" (the king with the painter), then "SELECT JUST ONE!" with three doors A, B, C and a bouncing ball as cursor |
  | 3 | `Mode3_RoundIntro` | "ROUND 01 / KITCHEN ROOM / lives x 03 / READY !!" |
  | 4 | `Mode4_GameOver` | GAME OVER |
  | 5 | `Mode5_Continue` | CONTINUE ? countdown, YES / NO |
  | 6 | `Mode6_Ending` | castle scene (after the last round) |
  | 7 | `Mode7_LinkLose` | "SORRY YOU LOSE / TRY AGAIN !" (2 player link game, loser) |

  Flow seen in the emulator: Start on the title goes to mode 3 then mode 1. Bank 1 code switches modes with `ld a,N; jp GameModeDispatch`
  (7 on a link-cable event, 2 after a round is cleared).
- Bank 1: $4000-$4156 sound tables, $4157-$487a sound engine (`SoundUpdate`, `PlaySound` queue at `wSoundQueue`, 8 channel records of $20 bytes at
  `wSoundChannels`), the rest is game logic (per-frame object updates for the play mode). Bank 0 `PlaySound` (A = sound id, $80+ for music/effects).
- Sound engine detail: `SoundUpdateChannel` handles each of the 8 channel records ($20 bytes at `wSoundChannels`); record byte +1 selects the hardware channel and a
  `jp hl` goes to `SoundWriteChannel1..4` (pulse 1, pulse 2, wave, noise), which write NR1x-NR4x and the shared pan register NR51. `SoundReadNextNote` reads
  note data from the pointer at +3/+4 of the record (bytes $e0 and up are commands). Field layout is listed at the end of `src/constants.inc`.
- Sound ids: `PlaySound` takes $81-$93. Table `SoundCommandDataTable` ($40f4, indexed by id-$80) holds the start of each song or effect stream; `SoundCommandHandlerTable`
  ($411a) holds the routine that starts it: $4263 for ids $81 and $84-$8c (music), $4292 for $82, $83 and $8d-$93 (effects). Music streams sit at $5e72-$7f55 (id $8c points at
  padding, an empty slot); effect streams are at $5c48-$5cba. Verified by queueing every id in `tools/emu.py` (no code outside the trace runs, except the unused id $8c).
- Emulator: `tools/emu.py` is a small non-cycle-exact interpreter (DMG, MBC1, serial with no partner returns $FF) with an end-of-frame renderer.
- Graphics loading: bank 2 `$4000` 0x700 bytes and bank 3 `$4000/$5000/$6000/$6e10` blocks are copied to VRAM $8000 (2bpp tiles).
- Joypad: `ReadJoypad` stores the D-pad in the high nibble and the buttons in the low nibble of `hJoyHeld` (down $80, up $40, left $20, right $10,
  start $08, select $04, B $02, A $01). Button codes on the title screen (checked in the title loop, `TitleLoop` $2a27): Down+Right+A+B ($93) jumps to mode 6
  (the ending scene; confirmed in the emulator), Up+Select+A+B ($47) sets bit 0 of `wCheatFlags` ($c49c), which gives unlimited continues (`wContinues` = $ff instead of 5; the death handler in bank 1 and the continue mode test it).
- Serial: `SerialHandler` ($0221) and `WaitSerialByte` ($0356): the game has a link-cable mode (`hSerialByte`).

- **Play rules seen in the emulator**: the room map (`wRoomMap`) marks the path cells; walking over an unpainted path cell paints it and decrements `wPaintRemaining`
  ($c520, 80 at the start of round 1); when it reaches 0 `RoundCleared` runs (sound $8a), and `wGameFlags` bit 0 makes `PlayFrame` finish the clear
  sequence. `PlayerDeath` (sound $8b) runs when `wPlayerDir` bit 5 is set: by `CheckEnemyTouchesPlayer` (an enemy overlapping the player, tested with `ObjectsOverlap`) or by `L_01_4c4e` (stepping off the path). The paint blob object at `$c4fe` is tested against enemies by `CheckPaintHitsEnemy`.

- **Enemies**: 16 slots of $20 bytes at `wEnemySlots` ($c542-$c741), addressed through `EnemySlotTable` ($37af). `UpdateEnemyLoop` copies each active slot
  into the HRAM record `hObject2` ($ffb5-$ffd4, `LoadEnemySlot`), runs `UpdateEnemy`, and copies it back (`StoreEnemySlot`). Record +1/+2 is the animation
  pointer (`SetObjectAnimation`), so the many `ld bc, $3abf; jp L_00_3649` sequences select animation data. Writers of `hObject2` flags were found with
  write watches in `tools/emu.py` ($38a0, $99c, $3b79, $3b87 flip bit 5 = facing).

- **Enemy kinds** (seen by forcing each round in `tools/emu.py`; kind = `hEnemyKind`): round 1 = kind 1 (`EnemyKind1`, the chaser); rounds 2-4, 12, 18-20 = kind 2;
  rounds 5-7 add kinds 7 and 11; round 8 = kind 8 (stationary); round 9 and 11 = kind 11; rounds 13-15 = kinds 0 and 10; round 16 = kinds 3, 5 and 8; rounds 17-32
  repeat 1-16. `EnemyBehaviorTable` has 12 entries (kinds 0-11).

- **Magic screen** (found by pressing B in play with `tools/emu.py`): MOMOPIE'S MAGIC shows SCR (8 BCD score digits at `wScoreDigits`), Rn (`wRound`), MP (`wMagicPoints`,
  16 bit, initial value from `MagicPointsTable` by round: 50 in round 1), TIME (`hTimeSeconds`, counted down once per `hTimeFrames` = 60 frames) and three magic cards
  (card ids and costs read from the screen: 1 S.UP 10MP, 2 W.IN 50, 3 T.STOP 40, 4 GHOST 90, 5 FRIEND 60, 6 SEALED 30, 7 B.O.M 80, 8 CLEAR 70, 9 PYON 20; a new game starts with S.UP, round 2 adds PYON, the link game starts with 1 2 3 5 6). `ShowMagicScreen` ($121c) builds it from `TilesIcons`.

- **Animation and shape data** (decoded from `DrawObject` $0866 and checked against the data): the animation pointer of an object (record +1/+2) points at frames of
  `shape id, tile id x count` where `count` is the first byte of the shape; `ObjectShapeTable` ($06a4) maps the shape id to `count, (y offset, x offset) x count` with signed
  pixel offsets (for example shape 1 = four parts at (-8,-8) (0,-8) (-8,0) (0,0), a 16x16 sprite, with tile ids such as $bc $bd $cc $cd). Record flags bit 5 and 6 mirror the offsets.
  `SetAnimationVariant` picks between the two pointers of each animation pair depending on bit 3 of `$ffd0`.

- **Casting a card** is two steps. On the magic screen (`MagicScreenInput` $1770) A *selects* a card: its id goes to `wActiveMagic` (formerly misnamed wRoomType), cost >= MP is refused, `SND_SFX_90` plays,
  and B closes the screen. Back in play, A (`PlayerAction` $4c6f) *casts* it while `wPlayerStatus` bit 0 is set: `wMagicState` bit 0 = running, `PayMagicCost` subtracts the cost from `wMagicPoints`, and each frame
  `RunMagicEffect` jumps through `MagicEffectTable` ($4cd7) to the card's routine, which starts `BeginMagicCast` and a countdown in `hMagicTimer` (`MagicTimerTick`). Enemy routines test `wActiveMagic`
  (T.STOP and others) and `wMagicState` bit 0 to change behaviour.

- **Enemy spawning** (`StepEnemySpawnScript` $31f1): `RoundDataTable[wRound-1]` points to 6 wave lists; a wave list is `count` then `count` entries of 4 bytes: kind (`hEnemyKind`), X, Y (`and $f8`; the low bits 0/1 or 2 are variant flags stored in `$ffcf`, bit 1 from round 17 on) and a delay (compared with `hTimeSeconds`). An enemy is created when the delay has
  elapsed and fewer than 3 are alive (`wEnemyCount`); `wSpawnIndex` advances, then `wSpawnWave` when the list is exhausted.

- **Link cable (2 player)**, partly decoded: the title screen handshake sends `$ee` and treats `$ff` (no partner) as a single player game; Start sends `wRound | $80` (`SerialSendByte`).
  `SerialHandler` ($0221) decodes the received byte `rSB`: bit 7 set = round number from the other side (`$c7bf`, `hSerialByte` bit 4); `$04` sets `hLinkFlags` bit 1 and `hSerialByte` bits 6 and 7
  (the other player lost: `GotoLinkLose` runs from `PlayFrame`); `$08` sets `hLinkFlags` bit 2; a transfer started with the internal clock sets `hSerialByte` bits 0 and 2.
  **Tested with two emulated machines** (`tools/link_test.py`, `emu.GB.partner`): choosing 2 PLAYER on both and pressing Start on one starts the same random round (here 26, Rouya room) on both with
  one life each and `hLinkFlags` bit 0 set; the master ends with `hSerialByte` $05, the other machine $16.
  `LinkSyncFrame` ($4cf3) sends `$02` every frame while `wMagicPoints` high byte is 0 and reacts to the answer. Not testable in `tools/emu.py` (no partner).

- **Card effects measured in the emulator** (cast each card at MP 128, hold right/down for 240 frames): MP drops by the cost exactly. S.UP: the painter moves about twice as fast for $f0 frames.
  W.IN: the painter passes through walls for $d0 frames. T.STOP ($d0 frames), GHOST ($b0), FRIEND ($b0) and SEALED ($a0) leave the painter's own movement unchanged and act on enemies and
  projectiles (T.STOP freezes enemies, FRIEND and T.STOP remove the projectile). B.O.M ends in one frame (immediate explosion), CLEAR runs a short sequence and PYON has no timer.

- **Sound stream format** (`SoundParseStream` $461f): one byte at a time from the channel's pointer (record +3/+4). `$e0-$f1` = command (see `SoundCommandTable`; operands follow).
  `$80-$df` = note: index into `SoundFrequencyTable` ($4048, words) plus the transpose in record +5 (`$80` itself = rest, no transpose); if the channel flag bit 5 is set one extra byte
  (duty/length NRx1) follows the note; then a byte below `$80` is the note length (record +$b); a byte of `$80` or more means "keep the previous length". `$00-$7f` alone = a new length.

### Text and VRAM jobs

- **Charmap** (read from the BG map of the round intro screen): tile `$80+n` = letter `A+n`, `$ab+n` = digit `n`, `$ff` = space, `$b5` = `!`, `$b6` = `x`,
  `$b7`/`$b8` = other punctuation. `tools/dump_text.py` lists the strings in your ROM.
- **VRAM copy data** (`VramCopyRows` $0618): a job is `DE` = source stream, `HL` = destination; the stream is repeated `count, rows, tile...` records where
  `count` bit 7 means "repeat the single tile" instead of reading `count` tiles, `rows` = number of rows (the destination advances by $20 per row), terminated by
  the caller's job count. `VramCopyList` ($0663) runs a list of such jobs `{dstLo?, dstHi?, srcLo, srcHi}`.
  Exact list format (`RunVramCopyList` $066b / `VramCopyList` $0663): `count` byte, then `count` entries of 4 bytes `{dest word (VRAM address), source word (a stream as above)}`.
  `VramCopyRows` ($0618) runs one such pair (dest $c0a5/6, source $c0a3/4) and `QueueVramCopyRows` / `QueueVramCopyList` set them for the next VBlank.
  Pointer tables to these lists: `RoomVramJobTable` $14f9, `RoomNameJobTable` $1d39, `BonusSelectJobTable` $2709, `CreditsPageTable` $2e0f, `RoundDataTable` $0d3d.
  Examples in bank 0: room names KITCHEN / BED(ROOM) / ROUYA / TAKARA / ROUKA / KING at $1d5d-$1d8a, `READY !!` $1db0, `GAME OVER` $1f12, `CONTINUE ?` $2094,
  title strings $2c54-$2c70, staff credits (PLANNER, DESIGNER, PROGRAMMER, PRESENTED...) $2e38-$2f1x for the ending.

### Data Structures

- **Room map**: 16 columns x 16 rows of 2 bit cells (0 = empty, 1/2 = path pieces; $11 seen at the start tile), stored packed in 64 bytes
  per room; `UnpackRoomMap` expands it to `wRoomMap` ($c0a7, 256 bytes). `RoomMapTable` ($171e) has 17 pointers (rounds 1-16 repeat; 17th = bonus).
  `PixelXToColumn` + `LookupMapTile` convert a pixel position to a cell (rows start at pixel Y $18, columns at X $10).
- **Per-round tables** (index = (round-1)&15, 16 for round 32): `RoomMetatileTable` $16da, `RoomSpriteSetTable` $16fc (sprite tile sets in bank 2 at
  $4700 $5000 $5900 $6200 $6b00, $900 bytes each), `RoomMapTable` $171e, `RoomVramJobTable` $14f9. Listed in `ptables.csv`.
- **Object record** (see `src/constants.inc`): flags, animation pointer, frame, 16 bit X at +7, 16 bit Y at +$a, velocities at +$d and +$f.

(none recovered yet)

### State Machine

(not mapped yet)

---

## Intermediate Output Files

| File | Contents |
|------|----------|
| `src/bank_NN.asm` | generated RGBDS source, one per bank; reproduces the ROM byte for byte |
| `config/functions.tsv` | routines found (bank, addr, size, name) |
| `labels.csv`, `seeds.csv` | names and entry points fed back into the disassembler |
| `progress/jp/report.json` | objdiff-format report for ByteMatch |

---

## Verification Checklist

- [x] Ph3: all 4 banks emitted as RGBDS source and rebuilt byte-for-byte by the reference assembler (`gb_dis.py --check`)
- [x] Ph3: RGBDS 1.0.4 build (`python tools/build.py --rgbds E:/rgbds`) reproduces the SHA-1
- [ ] Ph3: 3+ functions traced and cross-checked against an emulator trace
- [ ] Ph4: 5+ tile sets extracted and visually compared to an emulator
- [ ] Ph5: key data struct confirmed in an emulator memory dump
- [ ] Ph6: full playthrough, no logic gaps

---

## Reference Resources

- Pan Docs (https://gbdev.io/pandocs/), RGBDS docs (https://rgbds.gbdev.io/), gbdev hardware.inc
- Ghidra has no SM83 module by default; use `tools/gb_dis.py` first, and a Game Boy Ghidra processor (e.g. GhidraBoy) if wanted.

---

## Next Tasks

### RE Investigation

- [x] Hardware register names, VBlank/serial handlers, joypad, OAM DMA, fades, VRAM copy queues
- [x] The 8 game-mode handlers, the sound engine (ids, commands, channel writers), the enemy slot system and its 12 kinds, the room map format
- [x] Headless interpreter `tools/emu.py`; dynamic coverage (`tools/coverage.py`) shows every executed instruction is in the static trace
- [ ] Name the remaining WRAM variables ($c4xx/$c5xx/$c7xx; see docs/RAM_MAP.md for the most used unnamed addresses)
- [ ] Name the rest of the play logic: `PlayFrame` sub-steps in bank 1, `L_01_4a9d`/`L_01_4e06` (paint blob), special room types (`wActiveMagic` values 1-9: bonus, boss, ...)
- [x] Magic cards: ids, costs, casting and the effect table are decoded; still to do: what each effect changes in the player and enemy routines
- [ ] Decode the animation stream format (`SetObjectAnimation` data: frame ids and durations) and the `ObjectShapeTable` records into structured `db`/`dw`
- [x] Data is extracted into `assets/` (no ROM needed to build); tile sets are PNG sheets; room maps, enemy spawn waves and the balance tables have text forms (`typed.csv`, `docs/MODDING.md`)
- [ ] More editable forms: sound streams (header and note format), text/VRAM job streams, animation and shape data, the remaining bank 0/1 `.bin` regions (see the `assets/bank_NN` file names)
- [ ] Remove the last raw `.bin` data from the source tree by converting each region to `db`/`dw` records or a typed text form, then drop `assets/bank_*` for regions that have a complete typed form
- [x] 2 player link mode: tested with two linked emulated machines (tools/link_test.py); protocol details beyond the start handshake still to document

### Web Port Fixes

(not planned: the target is a native Windows/Linux port, see docs/PORTING.md)

### Documentation

- [x] `docs/architecture_exe.md`, `docs/CALLGRAPH.md`, `docs/RAM_MAP.md`

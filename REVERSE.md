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
| bank 1 $4000-$4156 | | sound tables (frequencies, song offsets) | `SoundSongTable` $4048 |
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
  | 1 | `Mode1_Play` | gameplay: a painter walks around a room (kitchen room) with a tiled floor |
  | 2 | `Mode2_BonusSelect` | "SELECT JUST ONE!" with three choices A, B, C |
  | 3 | `Mode3_RoundIntro` | "ROUND 01 / KITCHEN ROOM / lives x 03 / READY !!" |
  | 4 | `Mode4_GameOver` | GAME OVER |
  | 5 | `Mode5_Continue` | CONTINUE ? countdown, YES / NO |
  | 6 | `Mode6_Ending` | castle scene (after the last round) |
  | 7 | `Mode7_LinkLose` | "SORRY YOU LOSE / TRY AGAIN !" (2 player link game, loser) |

  Flow seen in the emulator: Start on the title goes to mode 3 then mode 1. Bank 1 code switches modes with `ld a,N; jp GameModeDispatch`
  (7 on a link-cable event, 2 after a round is cleared).
- Bank 1: $4000-$4156 sound tables, $4157-$487a sound engine (`SoundUpdate`, `PlaySound` queue at `wSoundQueue`, 8 channel records of $20 bytes at
  `wSoundChannels`), the rest is game logic (per-frame object updates for the play mode). Bank 0 `PlaySound` (A = sound id, $80+ for music/effects).
- Emulator: `tools/emu.py` is a small non-cycle-exact interpreter (DMG, MBC1, serial with no partner returns $FF) with an end-of-frame renderer.
- Graphics loading: bank 2 `$4000` 0x700 bytes and bank 3 `$4000/$5000/$6000/$6e10` blocks are copied to VRAM $8000 (2bpp tiles).
- Serial: `SerialHandler` ($0221) and `WaitSerialByte` ($0356): the game has a link-cable mode (`hSerialByte`).

### Data Structures

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

- [x] `src/hardware.inc` register names used in the generated source (`DEF` constants, 1:1 verified by the round trip)
- [x] VBlank handler, serial handler, joypad, OAM DMA, fade, VRAM copy queues named (labels.csv); main loop = the 8 game modes still to name
- [x] Name the 8 game-mode handlers (done, see Key Findings)
- [ ] Map the HRAM variables ($FF80-$FFFE) and the WRAM variables referenced from bank 1 ($C3xx/$C5xx) into `src/constants.inc`
- [ ] Classify banks 1-3 data: tile data (2bpp), tilemaps, palettes, text, music/sfx; add `D_` labels and structured `db`/`dw` records
- [ ] Find the bank-switch helper and every `ld [$3fff],a` site; mark which bank each cross-bank call enters (extend `seeds.csv`)
- [ ] Find unreferenced code (pointer tables, `jp hl` dispatchers) so the 14 % code figure rises
- [x] Headless interpreter `tools/emu.py` with screenshots (Ph5.5); next: trace per-mode RAM use

### Web Port Fixes

(not planned: the target is a native Windows/Linux port, see docs/PORTING.md)

### Documentation

- [ ] `docs/architecture_exe.md`: bank layout, call graph, data flow

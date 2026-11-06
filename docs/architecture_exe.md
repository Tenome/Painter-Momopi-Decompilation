# Painter Momopie: ROM architecture

Findings are in `REVERSE.md` (with evidence); this page is the map.

## Banks

| Bank | CPU range | Contents |
|---|---|---|
| 0 (fixed) | `$0000-$3fff` | vectors, boot, VBlank and serial handlers, joypad, VRAM copy queues, `DrawObject`, the eight game modes, enemy update system, room tables, text/VRAM job data |
| 1 | `$4000-$7fff` | `$4000-$4156` sound tables, `$4157-$487a` sound engine, `$487b-$7f54` play logic (player, camera, tile collisions) and animation/room data |
| 2 | `$4000-$73ff` | 2bpp sprite tiles (five tile sets of `$900` bytes selected per room) |
| 3 | `$4000-$7e0f` | 2bpp background tiles: title logo, fonts, icons, castle scene |

MBC1: `ld [$3fff],a` selects the switchable bank (always done with interrupts off, except the sound code that expects bank 1).

## Frame flow

```
Entry -> Start -> GameModeDispatch (rst $00, 8 modes) -> ModeN handler (loops on WaitFrameAndSyncOam)
VBlank interrupt -> VBlankHandler: OAM DMA, VramCopyList/VramCopyRows (queued by the main code), scroll registers,
                    bank 1 SoundUpdate, frame counters
Serial interrupt -> SerialHandler (2 player link mode)
```

Modes: 0 title, 1 play, 2 bonus select, 3 round intro, 4 game over, 5 continue, 6 ending, 7 link lose.

## Play mode

`Mode1_Play` loads tiles (banks 2 and 3), unpacks the room map (`UnpackRoomMap`, 2 bits per cell, 16x16, `wRoomMap`), draws it with `DrawMetatileMap`,
then loops: `PlayFrame` (bank 1) handles the player (D-pad via `hJoyHeld`, grid alignment, collision with map cells, painting cells), `UpdateAllEnemies`
(bank 0) runs the 16 enemy slots, `DrawObject` builds the OAM entries. `wPaintRemaining` reaching 0 runs `RoundCleared`.

## Sound

`PlaySound` queues a command (`$80+` music/effects). `SoundUpdate` runs once per frame from the VBlank handler: 8 channel records of `$20` bytes, a note stream
per record, command bytes `$e0+` dispatched through a table at `$467b`; `SoundWriteChannel1..4` write the APU registers.

## Where things are

`labels.csv` (names), `src/constants.inc` (RAM names), `ptables.csv` and `tables.csv` (table lengths), `seeds.csv` (extra entry points), `docs/CALLGRAPH.md`
(generated call graph), `tools/emu.py` (headless interpreter), `tools/recomp.py` (recompiler to C) and `port/` (native runtime).

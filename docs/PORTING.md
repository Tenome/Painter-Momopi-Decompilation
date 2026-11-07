# Porting plan (native Windows and Linux)

Goal: run the game natively, with no emulator core in the shipped program. This follows the `native-platform-porting` skill.

## Status: static recompilation works (headless)

`tools/recomp.py` translates every traced routine of your ROM to C (`build/recomp/game.c`, git-ignored: it is derived from the game), and
`port/gb_rt.c` provides the hardware layer (memory bus, MBC1 banking, clock driven VBlank and serial interrupts, joypad, a software PPU).
`python tools/build_port.py --cc <clang|gcc>` builds `build/recomp/game_headless(.exe)`:

```
game_headless orig/painter_momopie.gb 1500 --press 250:start:3 --shot 650 --outdir build/rc
```

Branches inside a routine are `goto`s, jumps between routines are tail calls through a trampoline, `call` is a nested run, backward branches
call `gb_service()` so waiting loops let interrupts run, and indirect jumps (`jp hl`, enemy behaviour table) resolve through a table of
known routines. Verified: the recompiled game reaches the same screens as `tools/emu.py` (identical frames at 650 and 1400 in a play session).
`port/main_win32.c` is a Windows front end (window scaled by integer factors, keyboard, waveOut audio that also paces the game; F11 fullscreen,
Esc quits; arrows = D-pad, Z = A, X = B, Enter = Start, Right Shift or Backspace = Select) and `port/apu.c` is a small APU (two pulse channels with
sweep, wave, noise). `python tools/build_port.py` builds `build/recomp/game_win.exe` on Windows; run it with the path of your ROM.
Verified on this machine: title screen, Enter starts a game, the kitchen room plays with the painter, enemy and music.
Return addresses are modelled on the GB stack only as reserved slots: a routine that discards its return address (`pop hl` before a jump, used by the sound command table) is handled by `CALL`, which makes the caller return too when the stack ends up above where it started. Random-input stress runs (`game_headless ROM 12000 --press 250:start:3 --random SEED`) run clean.

`port/main_sdl.c` is the same player on SDL2 for Linux and macOS (`python tools/build_port.py --sdl`; written but not run yet on this Windows machine).
Next: save-less options (scaling filters, key mapping file), the HAL clean-up below.

## Current state of the native build

- **ROM only for extraction**: `python tools/gb_dis.py --write` reads your ROM once and produces `src/` and `assets/`. `python tools/build_port.py --rgbds E:/rgbds --cc <clang>` then builds the ROM data from those, recompiles
  the routines and links everything, with the game data compiled into the program. `game_win.exe` runs from an empty folder (tested: no ROM anywhere on disk).
- **No timing emulation**: the program is driven one frame at a time. The routines that waited for hardware timing (`WaitVBlankFlag`, `DelayFrames`, `WaitFrameAndSyncOam`, `LcdOff`, `ReadJoypad`,
  the serial routines, `WaitVramCopyDone`) are replaced by native C in `port/gb_native.c` (list in `port/overrides.txt`). There is no cycle counter, no scanline timing, no interrupt controller and no serial
  timing; once per frame `gb_host_vblank()` renders, mixes sound, presents the frame and runs the game's own `VBlankHandler`. A spin watchdog (60000 backward branches) covers loops that wait for the handler.
- **Still hardware-shaped**: the game's tile, map and sprite data lives in arrays laid out like VRAM and OAM and a small software renderer draws them (`render()` in `port/gb_rt.c`); sound is produced by a register driven
  synth (`port/apu.c`) fed by the original sound engine; ROM banks are a variable. These are the pieces the staged plan below replaces.

## Hand written C (stage 4 under way)

`port/logic.c` holds readable C versions of about 130 routines: the memory and table helpers, the object movement, drawing and collision code, the player's
direction and painting code, the enemy loop and eleven enemy behaviours, the spawn script, scoring, the magic screen and all card effects, the sound engine (queue, commands,
stream interpreter, pitch and register writers) and the play mode (`Mode1_Play`, `PlayFrame`).
It includes two generated headers: `game_symbols.h` (the names of `src/constants.inc`, such as `wPlayerX`) and `game_labels.h` (`GAME_<Label>` for the generated routine of a
label and `DATA_<Label>` for the ROM address of a data label), so hand written code reads like the source. Each routine keeps the registers and flags the original leaves, because callers may use them. A label is
replaced by adding it to `port/overrides.txt` and writing `gb_native_<Label>` in `port/logic.c`. A routine that ends in a tail jump returns the routine to continue with
(`gb_dispatch(address)`), like the generated code does; a routine that just returns gives 0. `python tools/lift_check.py --cc <clang> --rgbds E:/rgbds`
builds the runner with and without the hand written routines and compares a hash of work RAM, high RAM, video RAM and OAM after every frame of
random play (several seeds), forced rounds, a run with all nine cards and one run per selected card (`--poke` writes bytes at a frame); the hash covers the I/O registers, so sound writes are checked too;
a routine is accepted only when every frame matches. The check only covers paths the random play reaches (a deliberate change in the main path of `ByteToBCD`
is caught; the branch for a nonzero C is never taken in play and is not verified).

## Is a native exe with no emulation possible?

Yes, in stages. Today's `game_win.exe` already runs the game's own code natively (no CPU interpreter), but it still reimplements the Game Boy hardware
around it (memory map, picture unit, sound chip) and reads the ROM file for its data. The staged path to a port without that layer:

1. **Data without the ROM** (done, the exe has the data built in): `assets/` holds the extracted data; `tools/build.py` rebuilds the ROM from `src/` and `assets/`. A packaged exe can embed or load these files instead of a ROM.
2. **Native renderer**: replace the software picture unit by drawing straight from the game's object records (`DrawObject` already turns each object into OAM entries from the shape and animation data),
   the room map (`wRoomMap`, `DrawMetatileMap`) and the VRAM job streams, at any resolution. Needs: all VRAM writers identified (VRAM copy queues and `DrawObject` are known).
3. **Native audio**: replace the APU emulation by a player for the sound stream format (documented in `REVERSE.md`: notes, lengths, 18 commands, 4 channels) with a software synth.
4. **Native logic**: lift the generated C into readable hand-written C routine by routine (the pseudocode in `docs/PSEUDOCODE.md` and the names in `labels.csv` are the specification), verifying each against the recompiled routine
   with the frame comparison tools. At the end the exe is a normal game with its own renderer, mixer, input and save files.
5. **Linux**: the same code with the SDL2 front end (`port/main_sdl.c`).

## Plan

1. **Byte-matching source first.** Finish naming and structuring the RGBDS source so the hardware use is understood
   (LCD, OAM DMA, VBlank, joypad, serial, sound registers, MBC1 banking).
2. **Hardware abstraction layer.** Replace each hardware access with a call into a HAL (`hal_lcd_*`, `hal_joypad`, `hal_sound_*`,
   `hal_bank_select`). The tile/tilemap/OAM data model stays the same, rendered by a small software PPU to an SDL/OpenGL texture.
3. **Lift the code.** Convert the SM83 routines to C (one routine at a time, each verified against the original by running both
   on recorded input and comparing RAM/VRAM/OAM per frame). Keep the ROM-resident data as generated tables extracted from the
   user's own ROM at build time (no game data in the repository).
4. **Platform layer.** SDL2 window, input mapping, audio output, saves (the cartridge has no battery RAM).
5. **Verification.** Frame-by-frame state comparison against an emulator running the original ROM.

## Wishlist for the native Windows port (not started)

- **No Game Boy limits in the port.** Data is read from files (maps, spawn lists, songs, text) instead of fixed ROM regions, so sizes and table lengths are free,
  and rooms, rounds and cards could be added. The generated C still carries the original index and size assumptions (8 bit indexes, 16 rooms, 32 rounds, 10 cards),
  so this needs the logic lifted to hand written C first (see the section above) and a data loader that replaces the ROM tables.
- **Widescreen and larger views.** Needs the native renderer (stage 2): draw from object records and the room map instead of the 160x144 picture unit.
- **Map editor** as a separate executable that reads and writes the same text forms (`assets/typed/`) and shows the room with the real tiles.
- **README progress bar** like the one on the ByteMatch page of this project (badge or generated SVG from `progress/jp/report.json`).

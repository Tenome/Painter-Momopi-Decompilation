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

## Is a native exe with no emulation possible?

Yes, in stages. Today's `game_win.exe` already runs the game's own code natively (no CPU interpreter), but it still reimplements the Game Boy hardware
around it (memory map, picture unit, sound chip) and reads the ROM file for its data. The staged path to a port without that layer:

1. **Data without the ROM** (done): `assets/` holds the extracted data; `tools/build.py` rebuilds the ROM from `src/` and `assets/`. A packaged exe can embed or load these files instead of a ROM.
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

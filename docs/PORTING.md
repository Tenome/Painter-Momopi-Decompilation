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
Next: a Win32/SDL window with input, an APU for sound, then the HAL clean-up below.

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

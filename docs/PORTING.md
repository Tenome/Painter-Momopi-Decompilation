# Porting plan (native Windows and Linux)

Goal: run the game natively, with no emulator core in the shipped program. This follows the `native-platform-porting` skill.

1. **Byte-matching source first.** Finish naming and structuring the RGBDS source so the hardware use is understood
   (LCD, OAM DMA, VBlank, joypad, serial, sound registers, MBC1 banking).
2. **Hardware abstraction layer.** Replace each hardware access with a call into a HAL (`hal_lcd_*`, `hal_joypad`, `hal_sound_*`,
   `hal_bank_select`). The tile/tilemap/OAM data model stays the same, rendered by a small software PPU to an SDL/OpenGL texture.
3. **Lift the code.** Convert the SM83 routines to C (one routine at a time, each verified against the original by running both
   on recorded input and comparing RAM/VRAM/OAM per frame). Keep the ROM-resident data as generated tables extracted from the
   user's own ROM at build time (no game data in the repository).
4. **Platform layer.** SDL2 window, input mapping, audio output, saves (the cartridge has no battery RAM).
5. **Verification.** Frame-by-frame state comparison against an emulator running the original ROM.

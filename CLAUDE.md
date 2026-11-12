# Painter Momopie (Game Boy) matching decompilation

Platform: Game Boy (SM83), MBC1, 4 x 16 KiB banks. Toolchain: RGBDS (rgbasm/rgblink). ROM: `orig/painter_momopie.gb`
(git-ignored; SHA-1 in `orig/README.md`). Working folder with Ghidra/REA/other tools: `E:\Claude Typing of the Dead\`.
Read `AGENTS.md` first, then `REVERSE.md`.

- RGBDS 1.0.4 lives in `E:/rgbds`: `python tools/build.py --rgbds E:/rgbds` (or set `RGBDS_DIR`). Passing build = byte-identical ROM.
- `python tools/emu.py --frames N --press F:button:HOLD --shot N --break ADDR` runs the ROM headless (Pillow screenshots in `build/shots/`); also usable as a library (`from emu import GB`) to jump into a routine and render it.
- Tool prefix: `python tools/` (stdlib only). `python tools/gb_dis.py --check` proves the sources reproduce the ROM;
  `--write` regenerates `src/bank_NN.asm` from the ROM + `labels.csv` + `seeds.csv` (do not use it once a bank file is hand-edited).
- `labels.csv` is banked: `bank,addr,name,comment` (addr = CPU address in hex, names start with an uppercase letter, no commas in comments).
- Never commit the ROM or anything extracted from it (`assets/` is git-ignored). `python tools/build.py --mod` builds from `src/` + `assets/` without the ROM; see `docs/MODDING.md`.
- Exception: screenshots (game and level editor, in `docs/images/` and the README) are allowed and encouraged. A screenshot is a picture of the running program, not an extracted game asset (no tile data, sprite sheets, ROM bytes or sound files), and publishing screenshots of a game is fair use. Do not use flat-colour fallbacks to avoid showing the game. Still never include personal desktop content in a capture (crop to the window, check the image before committing).
- Skills: `re` (task loop), `matcher`, `decomp-code-rules`, `helper-recovery`, `native-platform-porting`, `reverse-engineer-anything`.
- Publishing: `progress/jp/report.json` (objdiff format) is committed; `.github/workflows/report.yml` uploads it for https://bytematch.dev/.
- Native port: `python tools/build_port.py --rgbds E:/rgbds --cc <clang|gcc>` builds the ROM from `src/`+`assets/`, recompiles its routines to C (`build/recomp/game.c`, git-ignored) and builds `game_win.exe` / `game_headless` with the data built in (no ROM file at run time; `game_headless - FRAMES` uses the built-in data). A compiler: `C:/Users/Michael/.local/share/retcomm/toolchains/cmake-clang-v1/latest/bin/clang.exe`.

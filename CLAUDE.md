# Painter Momopie (Game Boy) matching decompilation

Platform: Game Boy (SM83), MBC1, 4 x 16 KiB banks. Toolchain: RGBDS (rgbasm/rgblink). ROM: `orig/painter_momopie.gb`
(git-ignored; SHA-1 in `orig/README.md`). Working folder with Ghidra/REA/other tools: `E:\Claude Typing of the Dead\`.
Read `AGENTS.md` first, then `REVERSE.md`.

- RGBDS 1.0.4 lives in `E:/rgbds`: `python tools/build.py --rgbds E:/rgbds` (or set `RGBDS_DIR`). Passing build = byte-identical ROM.
- `python tools/emu.py --frames N --press F:button:HOLD --shot N --break ADDR` runs the ROM headless (Pillow screenshots in `build/shots/`); also usable as a library (`from emu import GB`) to jump into a routine and render it.
- Tool prefix: `python tools/` (stdlib only). `python tools/gb_dis.py --check` proves the sources reproduce the ROM;
  `--write` regenerates `src/bank_NN.asm` from the ROM + `labels.csv` + `seeds.csv` (do not use it once a bank file is hand-edited).
- `labels.csv` is banked: `bank,addr,name,comment` (addr = CPU address in hex, names start with an uppercase letter, no commas in comments).
- Never commit the ROM or anything extracted from it.
- Skills: `re` (task loop), `matcher`, `decomp-code-rules`, `helper-recovery`, `native-platform-porting`, `reverse-engineer-anything`.
- Publishing: `progress/jp/report.json` (objdiff format) is committed; `.github/workflows/report.yml` uploads it for https://bytematch.dev/.
- Native port: `python tools/build_port.py --cc <clang|gcc>` recompiles the traced routines to C (`build/recomp/game.c`, git-ignored) and builds `build/recomp/game_headless`. A compiler: `C:/Users/Michael/.local/share/retcomm/toolchains/cmake-clang-v1/latest/bin/clang.exe`.

# AGENTS.md: project guide for contributors (human or AI)

Goal: RGBDS source that assembles into the same 65,536 bytes as the original `Painter Momopie.gb`, written so that a reader
would accept it as the original author's source (named labels, constants, structured data tables, commented routines).
Longer term: a native Windows/Linux port built from the recovered source (see `docs/PORTING.md`).

## Rules of the repo
- **No game files.** Never commit the ROM, extracted graphics/audio/text, or Ghidra exports. `orig/*` and `*.gb` are ignored.
- **Match honestly.** `db` blobs are placeholders, not a result: turn them into typed data (`dw` pointer tables, structured
  records, text, tile data as commented rows) as they are understood. Do not hide bytes in macros that exist only to make the
  build pass.
- **Names.** Generated placeholders are `L_<bank>_<addr>` (code) and `D_<bank>_<addr>` (data). Replace them through
  `labels.csv` (`bank,addr,name,comment`; names start with an uppercase letter) and regenerate with
  `python tools/gb_dis.py --write`. RAM names (`wFoo` WRAM, `hFoo` HRAM, `rFoo` I/O) go in `src/constants.inc` once an address is
  understood from at least two uses.
- **Verification.** Every change keeps `python tools/gb_dis.py --check` OK (reference assembler) and, where RGBDS is installed,
  `make` OK (SHA-1 equal to the original). Refresh `progress/jp/report.json` with `python tools/report.py`.

## Layout
- `src/bank_NN.asm`: instruction source, committed. Data is not stored in git: each data region is `INCBIN "assets/bank_NN/AAAA_Label.bin"`;
  `python tools/gb_dis.py --write` extracts those files (and PNG/text forms, see `docs/MODDING.md`) from your own ROM into the git-ignored `assets/`.
  Regenerate with `--write` until a bank file is edited by hand; it overwrites `src/` and `assets/`.
- `labels.csv`, `seeds.csv`: names and code entry points (bank 1-3 entries reached through the MBC1 bank switch).
- `config/functions.tsv`: routine list used by the report.
- `tools/`: `sm83.py` (instruction table + encoder), `gb_dis.py` (tracing disassembler + round-trip proof), `report.py`
  (objdiff-format report for ByteMatch), `check_rom.py`.
- `REVERSE.md`: findings and task list (the `re` skill drives it); `dead_ends.md`: failed approaches; `docs/`: notes.

## Build
```
python tools/build.py              # RGBDS 0.9+ (PATH, RGBDS_DIR or --rgbds DIR); prints OK when byte-identical
python tools/gb_dis.py --check
python tools/report.py
```

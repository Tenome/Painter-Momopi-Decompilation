# Community level packs

Level packs made by players. The level editor (`tools/level_editor.py`, menu *Community*) lists them from `index.json` and downloads them; the native player plays them like any pack.

Each pack is a folder in `packs/<id>/` with exactly three files: `pack.zip` (the pack file, its songs and textures), `meta.json` and `preview.png`.
**Do not write these by hand and do not edit `index.json`**: the editor's *Community > Submit* (or `python tools/community.py submit ...`) makes the folder, and the repository's
Action rebuilds `index.json` after a pull request is merged. See `docs/COMMUNITY.md` for the rules.

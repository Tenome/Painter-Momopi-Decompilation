# Community level packs

Share your levels, or play other people's, from the level editor.

## Browsing and downloading

*Community > Browse and download community packs...* lists the packs in the repository's `community/` folder with a preview picture of the maps (flat colours drawn from the
map data), the author, a description and the size. *Download and open* saves the pack in `packs/community/<id>/` (and the zip next to it) and opens it in the editor. From
there you can play it (F5), change it, or take single levels with *File > Add levels from another pack*.

The list is read from `https://raw.githubusercontent.com/Tenome/Painter-Momopi-Decompilation/master/community/index.json`. It needs an internet connection; everything else works offline.
Set the environment variable `PMCOMMUNITY_URL` to read another address (a fork, or a local folder as a `file:///` URL ending in `/`).

Every download is checked against the checksum in the list, zips with unsafe file names or more than 24 MB unpacked are refused, and a pack can only contain maps, enemy lists, songs
(`.mml`), PNG pictures and text. A pack cannot contain programs.

`python tools/community.py list` and `python tools/community.py download ID` do the same from the command line.

## Submitting a pack

1. Save your pack and choose *Community > Submit this pack to the community...* (or run `python tools/community.py submit pack.pmpack --title ... --author ... --description ...`).
2. Fill in the title, the author name everybody will see, a description and optional tags, and confirm that the levels are yours.
3. *Check and make the submission folder* runs the same checks as the repository and writes `submissions/<id>/` with `pack.zip`, `meta.json` and `preview.png`.
4. *Open the GitHub upload page*: sign in to GitHub, drag the three files in (GitHub asks for the folder `community/packs/<id>`), and press *Propose changes*. GitHub makes the fork and the pull request for
   you. The editor itself sends nothing anywhere; the pull request exists only when you finish step 4.
5. A check runs on the pull request. After a maintainer merges it, an Action rebuilds `community/index.json` and your pack appears in everybody's list.

Another way: fork the repository, add `community/packs/<id>/` yourself and open a pull request in the usual way.

### Rules

* The levels must be yours: no copies of the game's own 33 levels (more than half of the levels equal to original maps is refused) and no pictures taken from the game.
  Texture folders must be pictures you painted; the exported grey sheets, untouched, are refused.
* Pack zips hold exactly one `.pmpack` file plus songs (`.mml`), PNG pictures and text files; at most 8 MB zipped, 6 MB per file.
* The pack must pass the pack check (`tools/pack_check.py`): a reachable path, enemies on the path, and so on.
* Submitting means you agree that the pack is shared under the repository's MIT licence (`meta.json` says so). Pick a title, author name and description you are happy to show publicly:
  they appear in the list and in the repository history.
* Be kind: no hateful, sexual or otherwise harmful content in titles, descriptions, level names or pictures. Maintainers may decline or remove a pack.

## For maintainers

* `.github/workflows/community.yml` validates pull requests that touch `community/` and refuses changes to `community/index.json`; after a merge it rebuilds the index and commits it.
* `python tools/community.py validate` checks every pack folder, `python tools/community.py index` rebuilds the index locally.
* `tools/original_levels.json` holds hashes of the game's own maps (hashes only, no map data) so that copies can be refused.

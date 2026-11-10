# Player options

`settings.exe` (built next to `game_win.exe`) is a small window for all of these options: it reads and writes `painter_momopie.ini`, and *Save and play*
starts the game. The file can still be edited by hand.

`game_win.exe` reads `painter_momopie.ini` (a template is `port/painter_momopie.ini`; `tools/build_port.py` copies it next to the exe if none is there).
`game_headless` takes `--ini FILE`. A missing file or key means the default.

| Key | Values | Effect |
|---|---|---|
| `scale` | 1-16 | window size |
| `fullscreen` | 0/1 | start in full screen |
| `integer_scale` | 0/1 | whole-number scaling or fill the window |
| `palette` | 0-2 | green, grey, sepia |
| `widescreen` | 0-40 | extra pixels of the room on each side during play. The room is 256 pixels wide and the Game Boy only shows 160, so the camera view is widened (the picture becomes `160 + 2 * n` pixels wide). The magic screen and the other screens stay 160 pixels wide with black bars. Sprites near the edges are kept (the part culling and the OAM X coordinate are widened); the renderer draws the margin. |
| `no_sprite_limit` | 0/1 | the 40 entry OAM limit (and the flicker it causes) is gone: every sprite the game asks for is kept in a longer list that the renderer uses |
| `texture_pack` | folder name | full-colour replacement sheets (docs/TEXTURES.md) |
| `start_lives` | 1-99 | lives at the start of a game (the continue screen also gives this many) |
| `volume`, `mute` | 0-100, 0/1 | sound |
| `speed` | 50-400 | percent of normal speed (no sound unless 100) |
| `infinite_lives` | 0/1 | the player never loses a life |
| `all_cards` | 0/1 | all nine magic cards from the first round |
| `infinite_magic` | 0/1 | casting costs no magic points |
| `no_time_limit` | 0/1 | the round clock stops (so the time-up enemy never comes) |
| `level_pack` | file | a level pack (docs/LEVELS.md) |
| `start_round` | 0-33 | first round of a one player game |

All of these default to the original game's behaviour, and the byte-exact checks (`tools/lift_check.py`, `tools/verify_all.py`) run with the defaults.
The options live in `port/config.c`; the widescreen and sprite code is in `port/gb_rt.c` (`render`) and `port/logic.c` (`DrawObject`, `AddOamSprite`).

## Controls

Keyboard: arrows, Z = A, X = B, Enter = Start, Right Shift or Backspace = Select, Esc quit, P pause, M mute, F2 palette, F11 full screen, F12 saves a screenshot (PNG, in the `screenshots` folder next to the program), hold Tab to fast forward.
A gamepad (first joystick known to Windows) works too: D-pad or left stick, button 1 = A, button 2 = B, buttons 7/8 or 9/10 = Select/Start.

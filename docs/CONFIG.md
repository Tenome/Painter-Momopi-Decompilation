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
| `palette` | 0-4 | green, grey, sepia, blue and yellow (colour blind friendly), your own `palette_colors` |
| `widescreen` | 0-40 | extra pixels of the room on each side during play. The room is 256 pixels wide and the Game Boy only shows 160, so the camera view is widened (the picture becomes `160 + 2 * n` pixels wide). The magic screen and the other screens stay 160 pixels wide with black bars. Sprites near the edges are kept (the part culling and the OAM X coordinate are widened); the renderer draws the margin. |
| `no_sprite_limit` | 0/1 | the 40 entry OAM limit (and the flicker it causes) is gone: every sprite the game asks for is kept in a longer list that the renderer uses |
| `texture_pack` | folder name | full-colour replacement sheets (docs/TEXTURES.md) |
| `start_lives` | 1-99 | lives at the start of a game (the continue screen also gives this many) |
| `volume`, `mute` | 0-100, 0/1 | sound |
| `speed` | 50-400 | percent of normal speed (no sound unless 100) |
| `infinite_lives` | 0/1 | the player never loses a life |
| `palette_colors` | 4 hex colours | Your own palette: four `RRGGBB` values from lightest to darkest, for example `FFF6D6,E3C04A,3F6FB5,0B1D3A`. Select it with `palette=4` or F2. `palette=3` is a ready-made blue and yellow one that is easy to tell apart with most kinds of colour blindness. |
| `filter` | 0-2 | 0 = none, 1 = scanlines, 2 = LCD grid (Windows player; the picture is enlarged at least 3 times and the gaps darkened). Edit by hand; the settings window keeps it. |
| `pause_on_focus_loss` | 0/1 | The game pauses when its window loses the focus; P resumes. Edit by hand. |
| `quick_magic` | 0/1 | Q and E (or the gamepad shoulder buttons 5 and 6) cycle the selected magic card during play and show its name and cost; A then casts it as usual. Cards the magic points cannot pay for are skipped, and nothing changes while a cast is running. The original B-button magic screen still works. |
| `high_score` | 0/1 | The best score (and the round it was reached in) is kept in `painter_momopie.sav` next to the ini and shown at the top of the title screen. |
| `resume` | 0/1 | The state at the start of each round (round, lives, score, magic cards, continues) is saved in `painter_momopie.sav`; 1 PLAYER on the title screen continues there (hold B while pressing START for a new game). Finishing the game clears it. |
| `all_cards` | 0/1 | all nine magic cards from the first round |
| `infinite_magic` | 0/1 | casting costs no magic points |
| `no_time_limit` | 0/1 | the round clock stops (so the time-up enemy never comes) |
| `level_pack` | file | a level pack (docs/LEVELS.md) |
| `start_round` | 0-33 | first round of a one player game |

All of these default to the original game's behaviour, and the byte-exact checks (`tools/lift_check.py`, `tools/verify_all.py`) run with the defaults.
The options live in `port/config.c`; the widescreen and sprite code is in `port/gb_rt.c` (`render`) and `port/logic.c` (`DrawObject`, `AddOamSprite`).

## Recording and replaying

`game_win.exe --record run.pmrec` writes the buttons of every frame (and the options that change the game, and the level pack) to a text file; `game_win.exe --replay run.pmrec`
plays it back exactly, whatever your own settings are. The game is deterministic, so a replay shows the same game every time (the headless runner takes the
same two options, which makes replays regression tests). Put `--ini` before `--record` in the headless runner.

## Controls

The keys can be changed in the `[keys]` section of `painter_momopie.ini` (`key_a=Z`, `key_up=Up,W` ...; several keys per action are allowed). Gamepad buttons are set the same way with `pad_a=1`, `pad_start=8,10` ... (button numbers; D-pad and stick are fixed). The defaults are below.

Keyboard: arrows, Z = A, X = B, Enter = Start, Right Shift or Backspace = Select, Esc quit, P pause, M mute, F2 palette, F11 full screen, F5 reloads the texture folders (edit a sheet, press F5, see the change), F12 saves a screenshot (PNG, in the `screenshots` folder next to the program), hold Tab to fast forward.
A gamepad (first joystick known to Windows) works too: D-pad or left stick, button 1 = A, button 2 = B, buttons 7/8 or 9/10 = Select/Start.

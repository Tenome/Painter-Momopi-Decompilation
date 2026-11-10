# Custom music

A level of a level pack (docs/LEVELS.md) can play a song of your own. A song is a small text file in a music macro language (MML); the player compiles it when the level
starts and plays it with the game's own sound engine, so it sounds like the game: two pulse (square) channels, the wave channel and the noise channel of the Game Boy.

In the level editor: *Level* tab > *Own song* > **New** (makes a song file next to the pack and opens it), **Edit**, **Browse**, **Listen** (renders it with the game's sound
engine and plays it). In a pack file: `song file.mml` inside the level. In `game_headless`: `game_headless - 600 --song file.mml --wav out.wav` writes the song to a WAV file.

## The language

```
title My song              (ignored)
tempo 132                  beats (quarter notes) per minute
ticks 12                   timing steps per quarter note (default 12)

pulse1 duty=2 volume=11 decay=1
  L o4 e8 g8 b4 a8 g8 e4 r4
pulse2 duty=1 volume=7
  L o3 e2 e2 d2 d2
wave pattern=4 level=1
  L o2 e1 e1 d1 d1
```

Channels (at most four, one line each, with options, then the music on the following lines):

| Channel | Options |
|---|---|
| `pulse1`, `pulse2` | `duty=0-3` (12.5 %, 25 %, 50 %, 75 % pulse width; default 2), `volume=0-15` (default 12), `decay=0-7` (0 = constant volume, higher = fades out faster) |
| `wave` | `pattern=N` (the wave shape, 0-6 are the game's), `level=1-3` (1 full, 2 half, 3 quarter volume) |
| `noise` | `volume`, `decay`; notes are raw (see below) |

Music text:

| Text | Meaning |
|---|---|
| `c d e f g a b` | notes; `+` or `#` sharp, `-` flat (`f+`, `b-`) |
| `4` after a note | length: 1 whole, 2 half, 4 quarter, 8 eighth, 16 sixteenth ...; a `.` makes it one and a half times longer |
| `r` | rest |
| `l8` | the default length for notes without a number |
| `o4`, `<`, `>` | the octave (`o4` has middle C = `c`), one lower, one higher |
| `v9` | volume 0-15 from here on |
| `@2` | pulse width 0-3 from here on |
| `&` | tie: `c4&c8` is one note of 3 eighths |
| `[ ... ]3` | repeat 3 times (`]` alone repeats twice); repeats can be nested up to 8 deep |
| `L` (capital) | where the song repeats from at its end; without one the channel stops |
| `x8f` | a raw note number in hexadecimal (for the noise channel; separate it from what follows with a space; a raw note takes the length set by `l`, e.g. `l4 x20 x28`, because digits after it would read as more hex) |
| `; text` | a comment |

Notes range from `c+2` (the lowest) to `o9 d+` or so. Keep the channels the same length if you want them to loop together.

## How it works

`port/mml.c` compiles the text to the engine's own song format (channel count, 10 byte channel headers, note streams) in the song window at `$a000-$bfff` of the
address space, which the real game never uses; `gb_play_custom_song` in `port/logic.c` then starts it like a song of the game. A note stream is `note number` +
`length in ticks`; the tempo is the number of ticks per frame, so `tempo` and `ticks` set the speed. The compiled songs are not stored in the game data, so the ROM and
its size limits are not involved.

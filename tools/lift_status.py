#!/usr/bin/env python3
"""How much of the game is hand-written C: python tools/lift_status.py

Sorts the 344 routines of config/functions.tsv into: lifted (port/logic.c, listed in port/overrides.txt), hardware routines of the runtime (port/gb_native.c), and the few that
the native build never runs: interrupt vectors and tables, and routines whose job a lifted routine does itself (the sound stream commands are the cases of `sound_parse`,
the magic points digits are inside `ShowMagicScreen`, the title loop is the loop of `Mode0_Title`). A probe build in which these routines print and return when entered ran
random play of all 33 rounds, both link modes and the ending without a single hit (see docs/PORTING.md)."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(ROOT, "config", "functions.tsv"))][1:]
ov = {l.strip().split()[0] for l in open(os.path.join(ROOT, "port", "overrides.txt")) if l.strip() and not l.startswith("#")}
logic = open(os.path.join(ROOT, "port", "logic.c"), encoding="utf-8").read()
native = open(os.path.join(ROOT, "port", "gb_native.c"), encoding="utf-8").read()
tables = {"RstJumpTable": "jump table of rst $00", "BonusModeJumpTable": "jump table of the bonus modes", "OamDmaRoutine": "copied to high RAM; the runtime does the DMA itself",
          "RstVector00": "interrupt vector", "VBlankVector": "interrupt vector", "StatVector": "interrupt vector", "TimerVector": "interrupt vector",
          "SerialVector": "interrupt vector", "JoypadVector": "interrupt vector", "Entry": "boot entry"}
folded = {"DrawMagicPointsDigits": "ShowMagicScreen", "StoreMagicPointsDigit": "ShowMagicScreen", "TitleLoop": "Mode0_Title", "L_00_364b": "EnemyKind13Leave"}
for n in ("SoundRunCommand", "SoundCmdStop", "SoundSilenceRecordChannel", "SoundParseStream", "SoundJumpHL", "SoundCmdCall", "SoundCmdReturn", "SoundCmdRepeat", "SoundCmdJump",
          "SoundSkipOperand2", "SoundCmdSetEnvelope", "SoundSetField", "SoundCmdAddTranspose", "SoundCmdSetDuty", "SoundCmdSetPan", "SoundCmdSetField6", "SoundCmdSetPitch",
          "SoundSetPendingWave", "SoundCmdSetWave", "SoundLoadWave", "SoundReturn", "SoundCmdEnd", "SoundCmdMuteOn", "SoundCmdMuteOff", "SoundCmdClearFlag0",
          "SoundCmdSetMasterVolume", "SoundAddSigned16"):
    folded[n] = "sound_parse / load_wave"
lifted, hw, other = [], [], []
for r in rows:
    n = r[3]
    if n in ov:
        (lifted if "gb_native_%s(" % n in logic else hw).append(n)
    else:
        other.append(n)
print("%d routines: %d lifted to C (port/logic.c), %d hardware routines of the runtime (port/gb_native.c), %d not entered by the native build" % (len(rows), len(lifted), len(hw), len(other)))
for n in other:
    print("  %-28s %s" % (n, ("folded into " + folded[n]) if n in folded else tables.get(n, "?")))
unknown = [n for n in other if n not in folded and n not in tables]
if unknown:
    print("UNEXPLAINED:", ", ".join(unknown))

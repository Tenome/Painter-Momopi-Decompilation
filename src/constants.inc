; RAM variables named from their use (see REVERSE.md). HRAM = $ff80-$fffe, WRAM = $c000-$dfff.
DEF hJoyHeld        EQU $ff8b   ; held buttons: bit7 down, 6 up, 5 left, 4 right, 3 start, 2 select, 1 B, 0 A ($0f = A+B+Select+Start = soft reset)
DEF hJoyNew         EQU $ff8c   ; buttons newly pressed this frame (same bit layout)
DEF hSpriteY        EQU $ff8d   ; pixel Y input of PixelToTilemapAddr
DEF hSpriteX        EQU $ff8e   ; pixel X input of PixelToTilemapAddr
DEF hTilemapAddrHi  EQU $ff8f   ; result of PixelToTilemapAddr
DEF hTilemapAddrLo  EQU $ff90
DEF hVBlankFlag     EQU $ff91   ; bit 0 set by the VBlank handler each frame
DEF hSavedIE        EQU $ff92   ; IE saved by LcdOff
DEF hVBlankTasks    EQU $ffb3   ; bit0 VramCopyList, bit1 OAM DMA, bit2 VramCopyRows, bit4 countdown running
DEF hFrameCounter   EQU $ffb4   ; incremented every VBlank
DEF hObjPtrLo       EQU $ffd5   ; pointer to the current object record
DEF hObjPtrHi       EQU $ffd6
DEF hOamCount       EQU $ffd9
DEF hRngCounter     EQU $ffda   ; incremented while the game waits for VBlank: cheap random source
DEF hFrameSpin      EQU $ffdb
DEF hTimeFrames     EQU $ffe0   ; frame counter reloaded with 60 each second (TIME on the magic screen counts down hTimeSeconds)
DEF hTimeSeconds    EQU $ffe1   ; seconds left in the round (shown as TIME)
DEF hSerialByte     EQU $ffeb   ; byte received over the link port
DEF wVramCopyFlags  EQU $c0a0   ; bit0 pending bit7 list mode
DEF wVramListPtrHi  EQU $c0a1
DEF wVramListPtrLo  EQU $c0a2
DEF wVramSrcHi      EQU $c0a3
DEF wVramSrcLo      EQU $c0a4
DEF wVramDstHi      EQU $c0a5
DEF wVramDstLo      EQU $c0a6
DEF wScrollX        EQU $c1aa   ; copied to SCX in VBlank
DEF wScrollY        EQU $c1ab   ; copied to SCY in VBlank
DEF wSoundArg       EQU $c30c   ; command byte passed to PlaySound
DEF wSoundBusy      EQU $c311   ; 1 while the queue is being modified
DEF wSoundCmd       EQU $c30e   ; command being started (bit 7 set = music/effect id)
DEF wSoundQueueLen  EQU $c316
DEF wSoundQueue     EQU $c317
DEF wSoundChannels  EQU $c327   ; 8 records x $20 bytes
DEF wLives          EQU $c1a9   ; starts at 3 (shown as "x 03" on the round intro)
DEF wRound          EQU $c522   ; round number, starts at 1 ("ROUND 01")
DEF wRoundBackup    EQU $c523   ; also set to 1 at boot; incremented together with wRound
DEF wRoomIndex      EQU $c524   ; selects the room tile set / name (0 = kitchen room)
DEF hLinkFlags      EQU $ffed   ; bit 0 = 2 player link game
; ---- play mode (found with tools/emu.py: pressing a direction changes the values below) ----
; Object record (used by DrawObject via hObjPtr): +0 flags (bit 7 active, bit 5 = flip X), +1/+2 animation pointer, +5 frame,
; +7/+8 X (16 bit), +$a/+$b Y (16 bit), +$d X velocity, +$f Y velocity.
DEF wPlayer         EQU $c4be   ; the player's object record
DEF wPlayerX        EQU $c4c5
DEF wPlayerY        EQU $c4c8
DEF wPlayerVelX     EQU $c4cb
DEF wPlayerVelY     EQU $c4cd
DEF wPlayerDir      EQU $c4de   ; low nibble = facing/direction bits, bit 5 = on a tile boundary, bit 6 = action pressed
DEF wPlayerStatus   EQU $c4df   ; bit 2 = caught/clear animation started
DEF wGameFlags      EQU $c51e   ; bit 0 = round cleared (PlayFrame jumps to RoundCleared), bit 6 = advance to the next mode after the clear
DEF wActiveMagic    EQU $c447   ; card id of the magic being cast or in effect (0 = none); effects test it (3 = T.STOP freezes enemies ...)
DEF wMagicState     EQU $c53a   ; bit 0 = effect running, bit 1 = cast animation, bit 2 = new cast to process
DEF wRoomMap        EQU $c0a7   ; tile map of the room: 16 bytes per row; pixel Y $18 + row*16, column from PixelXToColumn
DEF hObject2        EQU $ffb5   ; the enemy being updated: a 32 byte object record copied into HRAM from its slot (flags +0, animation pointer $ffb6/$ffb7)
DEF wPaintRemaining EQU $c520   ; unpainted path cells left; decremented as the painter paints a cell; 0 = round cleared
; Sound channel record ($20 bytes at wSoundChannels, 8 records; hardware channel = byte +1):
;  +0 flags (bit 0 note started, bit 2 mute, bit 4 paused, bit 7 active), +1 hardware channel 0-3 (pulse1 pulse2 wave noise),
;  +2 NR51 pan mask, +3/+4 song data pointer, +7 envelope (NRx2), +8/+9 tempo accumulator and step, +$b/+$c note length and counter,
;  +$e/+$f pitch, +$12/+$13 frequency written to NRx3/NRx4, +$15 duty/length (NRx1)
DEF hEnemySlotLo    EQU $ffd7   ; address of the slot hObject2 was loaded from
DEF hEnemySlotHi    EQU $ffd8
DEF wEnemySlots     EQU $c542   ; 16 enemy records of $20 bytes (to $c741)
DEF wCameraX        EQU $c1ac   ; 16 bit camera position set by UpdateCamera
DEF wCameraY        EQU $c1ae

; Sound ids for PlaySound (music/effect type from SoundCommandHandlerTable; names for ids seen at their call sites)
DEF SND_MUSIC_TITLE EQU $81
DEF SND_SFX_82 EQU $82
DEF SND_SFX_83 EQU $83
DEF SND_MUSIC_GAME_OVER EQU $84
DEF SND_MUSIC_ENDING EQU $85
DEF SND_MUSIC_86 EQU $86
DEF SND_MUSIC_87 EQU $87
DEF SND_MUSIC_88 EQU $88
DEF SND_MUSIC_BONUS_SELECT EQU $89
DEF SND_MUSIC_ROUND_CLEAR EQU $8a
DEF SND_MUSIC_DEATH EQU $8b
DEF SND_UNUSED_8C EQU $8c
DEF SND_SFX_8D EQU $8d
DEF SND_SFX_8E EQU $8e
DEF SND_SFX_CURSOR EQU $8f
DEF SND_SFX_90 EQU $90
DEF SND_SFX_91 EQU $91
DEF SND_SFX_92 EQU $92
DEF SND_SFX_93 EQU $93
; ---- fields of the enemy record held in HRAM (hObject2 = $ffb5; record offset = address - $ffb5) ----
DEF hEnemyX         EQU $ffbc   ; +7: pixel X (16 bit with $ffbd)
DEF hEnemyXHi       EQU $ffbd
DEF hEnemyY         EQU $ffbf   ; +$a: pixel Y (16 bit with $ffc0)
DEF hEnemyYHi       EQU $ffc0
DEF hEnemyDir       EQU $ffd1   ; low nibble = direction bits (like wPlayerDir); bit 4/5/6 = state flags
DEF hEnemyKind      EQU $ffd2   ; index into EnemyBehaviorTable
DEF hEnemyFlags     EQU $ffd4   ; bit 1/2 = frozen / hit by the player
; ---- scratch bytes used as arguments and temporaries by the drawing, lookup and movement routines ----
DEF hScratch00      EQU $ff96
DEF hScratch01      EQU $ff97
DEF hScratch02      EQU $ff98
DEF hScratch03      EQU $ff99
DEF hScratch04      EQU $ff9a
DEF hScratch05      EQU $ff9b
DEF hScratch06      EQU $ff9c
DEF hScratch07      EQU $ff9d
DEF hScratch08      EQU $ff9e
DEF hScratch09      EQU $ff9f
DEF hScratch0A      EQU $ffa0
DEF hScratch0B      EQU $ffa1
DEF hScratch0C      EQU $ffa2
DEF hScratch0D      EQU $ffa3
DEF hScratch0E      EQU $ffa4
DEF hScratch0F      EQU $ffa5
DEF hScratch10      EQU $ffa6
DEF hScratch11      EQU $ffa7
DEF hScratch12      EQU $ffa8
DEF hScratch13      EQU $ffa9
DEF hScratch14      EQU $ffaa
DEF hScratch15      EQU $ffab

; Immediate values named by their use (the disassembler substitutes them in `ld a, n` before the register write)
DEF LCDC_ON_BG_OBJ  EQU $93   ; LCD on, BG tile data $8000, BG and sprites on
DEF LCDC_ON_BG      EQU $91   ; LCD on, BG on, sprites off
DEF PAL_NORMAL      EQU $e4   ; BGP/OBP: shades 0 1 2 3 in order
DEF PAL_FADE_1      EQU $94
DEF PAL_FADE_2      EQU $50
DEF PAL_FADE_3      EQU $40
DEF PAL_WHITE       EQU $00   ; every shade maps to colour 0 (lightest): the last step of FadeOut
DEF IE_VBLANK       EQU $01
DEF IE_VBLANK_SERIAL EQU $09
DEF wStackTop       EQU $dfff ; SP is reset here at the start of every mode
DEF vTiles0         EQU $8000   ; VRAM: tile data start (LoadGfx* destinations)
DEF vTiles1         EQU $8700   ; second block of sprite tiles
DEF vBGMap0         EQU $9800   ; background map 0
DEF vBGMapLast      EQU $9bff   ; last byte of background map 0 (FillBackwardsFF starts here)
DEF hOamDma         EQU $ff80   ; HRAM copy of OamDmaRoutine
DEF hOtherObjLo     EQU $ffa4   ; pointer to the second object for ObjectsOverlap (set by callers)
DEF hOtherObjHi     EQU $ffa5
DEF hEnemyBlocked   EQU $ffc7   ; bit mask of directions the enemy cannot walk (set from the room map and the screen edges)
DEF hEnemyCounter   EQU $ffc9   ; frame counter used by the enemy behaviour routines
DEF hEnemyAnimState EQU $ffc6
DEF wPaintObject    EQU $c4fe   ; the paint blob object record (tested by CheckPaintHitsEnemy)
DEF wCursorObject   EQU $c74e   ; menu cursor object record (8 bit position variant, drawn by DrawObjectBytePos)
DEF wCursorX        EQU $c754
DEF wCursorY        EQU $c755   ; title screen: $64 = 1 PLAYER, $74 = 2 PLAYER
DEF wMagicPoints    EQU $c44a   ; 16 bit MP (MP 050 on the magic screen)
DEF wScoreDigits    EQU $c464   ; 8 BCD digits of the score (SCR on the magic screen)
DEF wMagicCol       EQU $c43c   ; magic screen cursor column (0-2)
DEF wMagicRow       EQU $c43d   ; magic screen cursor row (0-2)
DEF wMagicCards     EQU $c43e   ; 9 bytes: card id per slot of the 3x3 inventory (0 = empty); round 1 starts with S. UP in slot 0
DEF wPlayerBlocked  EQU $c43b   ; mask of directions the player cannot walk (set by PlayerComputeBlockedDirs); the bonus screens reuse it as a step counter
; Magic card ids (wMagicCards) and MP costs, read from the magic screen: 1 S.UP 10, 2 W.IN 50, 3 T.STOP 40, 4 GHOST 90, 5 FRIEND 60, 6 SEALED 30,
; 7 D.O.M 80, 8 CLEAR 70, 9 PYON 20 (0 = empty slot)
DEF CARD_S_UP       EQU 1
DEF CARD_W_IN       EQU 2
DEF CARD_T_STOP     EQU 3
DEF CARD_GHOST      EQU 4
DEF CARD_FRIEND     EQU 5
DEF CARD_SEALED     EQU 6
DEF CARD_DOM        EQU 7
DEF CARD_CLEAR      EQU 8
DEF CARD_PYON       EQU 9
DEF wProjectile     EQU $c49e   ; object record of an enemy projectile (kind 10 shoots it; the T.STOP and FRIEND cards remove it)
DEF wMagicScreenFlags EQU $c53b ; bit 1 = a card was just chosen (input locked), bit 2 = cursor animation toggling
DEF wEnemyCount     EQU $c47e   ; enemies alive (spawning stops at 3)
DEF wSpawnWave      EQU $c483   ; index (0-5) of the current wave in the round's list
DEF wSpawnIndex     EQU $c484   ; next entry within the wave (1 based)
DEF wContinues      EQU $c49b   ; continues left (5 in a normal game, $ff with the cheat)
DEF wCheatFlags     EQU $c49c   ; bit 0 = title code Up+Select+A+B entered: unlimited continues

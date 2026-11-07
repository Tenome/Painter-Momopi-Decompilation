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
DEF hEnemySpeed     EQU $ffc6   ; +$11: speed factor MoveObject multiplies the movement vector by (5 and 6 are used)
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
; 7 B.O.M 80, 8 CLEAR 70, 9 PYON 20 (0 = empty slot)
DEF CARD_S_UP       EQU 1
DEF CARD_W_IN       EQU 2
DEF CARD_T_STOP     EQU 3
DEF CARD_GHOST      EQU 4
DEF CARD_FRIEND     EQU 5
DEF CARD_SEALED     EQU 6
DEF CARD_BOM        EQU 7
DEF CARD_CLEAR      EQU 8
DEF CARD_PYON       EQU 9
DEF wProjectile     EQU $c49e   ; object record of an enemy projectile (kind 10 shoots it; the T.STOP and FRIEND cards remove it)
DEF wMagicScreenFlags EQU $c53b ; bit 1 = a card was just chosen (input locked), bit 2 = cursor animation toggling
DEF wEnemyCount     EQU $c47e   ; enemies alive (spawning stops at 3)
DEF wSpawnWave      EQU $c483   ; index (0-5) of the current wave in the round's list
DEF wSpawnIndex     EQU $c484   ; next entry within the wave (1 based)
DEF wContinues      EQU $c49b   ; continues left (5 in a normal game, $ff with the cheat)
DEF wCheatFlags     EQU $c49c   ; bit 0 = title code Up+Select+A+B entered: unlimited continues
DEF hMagicTimer     EQU $ffdf   ; frames left of the running magic effect (MagicTimerTick)
DEF wMagicPointsHi  EQU $c44b   ; high byte of the 16 bit MP
DEF wCursorIndex    EQU $c758   ; menu choice 0-2 (MenuCursorInput)
DEF wCursorFlags    EQU $c759   ; bit 7 = a choice was confirmed
DEF wCameraXHi      EQU $c1ad
DEF wCameraYHi      EQU $c1af
DEF hEnemyTick      EQU $ffd0   ; incremented by TickObjectTimer; bits 2 and 3 alternate animation variants
DEF hEnemyStep      EQU $ffca   ; enemy step counter
DEF hEnemyAux       EQU $ffcc   ; enemy auxiliary counter
DEF wEnemyPathPtr   EQU $c533   ; 16 bit pointer into the scripted path of kind 7 enemies
DEF wEndingObject   EQU $c76e   ; object record used by the ending scene
DEF wCreditsPage    EQU $c790   ; index into CreditsPageTable
DEF wMusicPriority  EQU $c30f   ; priority of the playing music (SoundStartMusic)
DEF wEffectPriority EQU $c310   ; priority of the playing effect (SoundStartEffect)

; ---- more names (provisional where the comment says so) ----
DEF hEnemyAnimLo    EQU $ffb6   ; +1: animation pointer of the enemy record (SetObjectAnimation)
DEF hEnemyAnimHi    EQU $ffb7   ; +2
DEF hEnemyBoxHalf   EQU $ffb9   ; +4: half size of the hit box used by ObjectsOverlap (2 or 4)
DEF hEnemyCounter2  EQU $ffd3   ; +$1e: second per-enemy counter (hit counter; bit 2 toggles animations of kind 10) (name provisional)
DEF wEnemyLoopIdx   EQU $c53e   ; slot index of the running enemy loop (15 down to 0)
DEF wEnemyLoopStart EQU $c53f   ; incremented each frame so the update order rotates
DEF wRoundFlags     EQU $c51f   ; bit 0 set while a round is running; bit 1 extra life given; bit 2 round variables initialised (provisional)
DEF wEndingObject2  EQU $c78e   ; second object record of the ending scene (also drawn with SetObjPtr); its flag bits 0-2 double as credits state: 0 window shown, 1 window slid in, 2 credits finished (provisional)
DEF wEndingObject2Anim EQU $c78f ; +1 of the second ending object (set to $ff when the credits start)
DEF wEnemyPathPtrHi EQU $c534   ; high byte of the enemy path pointer (wEnemyPathPtr is the low byte)
DEF wSoundTmp       EQU $c30b   ; scratch byte used by SoundLoadStream and the stream commands
DEF wBlobPhase      EQU $c519   ; counter of the paint blob; bit 1 picks one of two animations
DEF wTextBuf        EQU $c44c   ; VramCopyStream buffer: count, rows, tiles (round intro and continue texts)
DEF wRemoteRound    EQU $c7bf   ; round number received over the link cable (bit 7 stripped)
DEF wEndingStep     EQU $c781   ; ending scene step timer; reloaded with $0a (provisional)
DEF wEndingPhase    EQU $c782   ; ending scene step counter (provisional)
DEF wEndingEvents   EQU $c7ae   ; bit 2 hero reached its place, bit 7 scene finished (provisional)
DEF wMagicCastTimer EQU $c4d2   ; frame counter used while a card is being cast (provisional)
DEF wCheatTimer     EQU $c49d   ; counts down from $a0 after wCheatFlags bit 5 is set (provisional)
DEF wScoreTemp      EQU $c47a   ; scratch byte of AddScore
DEF wExtraLifeIdx   EQU $c488   ; index (0-4) of the next score threshold for an extra life (CheckExtraLife)
DEF wBonusChoice    EQU $c75a   ; chosen bonus door / entry, indexes D_00_2651 and D_00_269b (provisional)
DEF wTrailIdx       EQU $c1b6   ; index of the trail segment (7 bytes each) copied by LoadTrailSegment
DEF wProjectileAnimLo EQU $c49f ; wProjectile +1: animation pointer
DEF wProjectileAnimHi EQU $c4a0
DEF wPaintAnimLo    EQU $c4ff   ; wPaintObject +1: animation pointer
DEF wPaintAnimHi    EQU $c500
; sound channel records (wSoundChannels = record 0), $20 bytes each
DEF wSoundChan1     EQU $c347
DEF wSoundChan2     EQU $c367
DEF wSoundChan3     EQU $c387
DEF wSoundChan4     EQU $c3a7   ; SoundStartEffect loads its stream here (records 5-7 provisional)
DEF wSoundChan5     EQU $c3c7
DEF wSoundChan6     EQU $c3e7
DEF wSoundChan7     EQU $c407
; sound register shadows: the engine writes a register only when the new value differs from the last one written
DEF wShadowNR12     EQU $c427   ; pulse 1 envelope
DEF wShadowNR13     EQU $c428   ; pulse 1 frequency low
DEF wShadowNR14     EQU $c429   ; pulse 1 frequency high
DEF wShadowNR22     EQU $c42a   ; pulse 2 envelope
DEF wShadowNR23     EQU $c42b   ; pulse 2 frequency low
DEF wShadowNR24     EQU $c42c   ; pulse 2 frequency high
DEF wShadowNR32     EQU $c42d   ; wave output level
DEF wShadowNR33     EQU $c42e   ; wave frequency low
DEF wShadowNR34     EQU $c42f   ; wave frequency high
DEF wShadowNR42     EQU $c430   ; noise envelope
DEF wShadowNR43     EQU $c431   ; noise polynomial
DEF wSoundChanLeft  EQU $c30d   ; channel records left to update in SoundUpdate (8 down to 0)
DEF wSoundMasterVol EQU $c315   ; NR50 value ($77 at init, set by command $ef)
DEF wWavePending    EQU $c312   ; wave pattern index waiting to be loaded (provisional)
DEF wWaveEffect     EQU $c313   ; wave pattern of the effect record (provisional)
DEF wWaveCurrent    EQU $c314   ; wave pattern index currently in wave RAM (provisional)
DEF hEnemyAngle     EQU $ffc5   ; +$10: heading 0-31 (index into the movement vector table at $0bb6)
DEF hEnemyDXLo      EQU $ffc1   ; +$0c: horizontal movement of the last MoveObject (16 bit with $ffc2)
DEF hEnemyDXHi      EQU $ffc2
DEF hEnemyDYLo      EQU $ffc3   ; +$0e: vertical movement of the last MoveObject (16 bit with $ffc4)
DEF hEnemyDYHi      EQU $ffc4
; fields of the ending scene objects (record offsets: +7 X, +$a Y, +$10 heading, +$11 speed)
DEF wEndingX        EQU $c775   ; wEndingObject +7
DEF wEndingY        EQU $c778   ; wEndingObject +$a
DEF wEndingAngle    EQU $c77e   ; wEndingObject +$10
DEF wEndingSpeed    EQU $c77f   ; wEndingObject +$11
DEF wEnding2X       EQU $c795   ; wEndingObject2 +7
DEF wEnding2Y       EQU $c798   ; wEndingObject2 +$a
DEF wMapCellMask    EQU $c7c0   ; DrawMetatileMap ANDs each map cell with this ($0f ignores the painted bit, $ff keeps it)
DEF wMpStream       EQU $c451   ; VramCopyStream buffer of the magic points display: count, rows, then tiles from $c453
DEF wMpStreamIdx    EQU $c463   ; number of tiles written so far into the magic points stream (provisional)
DEF wSpawnListPtr   EQU $c481   ; 16 bit pointer to the spawn list of the current wave (StepEnemySpawnScript)
DEF wSpawnCount     EQU $c485   ; number of spawns in the current wave (first byte of the list)
DEF wWaveEnded      EQU $c486   ; set to 1 when a wave has finished spawning (provisional)
DEF wComboCounter   EQU $c4bc   ; chain counter used by EnemyDefeated while wPlayerStatus bit 4 is set (provisional)
DEF wCursorBlink    EQU $c47d   ; counts to $50 and toggles the card cursor animation (CursorBlinkStep)
DEF wWalkAnimCount  EQU $c4d9   ; walk animation counter of the player (AnimatePlayerWalk)
; more object record fields (offsets from the record start: +1/+2 animation, +4 box half size, +7 X, +$a Y, +$10 heading, +$11 speed)
DEF wPlayerAnimLo   EQU $c4bf   ; wPlayer +1
DEF wPlayerAnimHi   EQU $c4c0   ; wPlayer +2
DEF wPlayerAngle    EQU $c4ce   ; wPlayer +$10
DEF wPlayerSpeed    EQU $c4cf   ; wPlayer +$11
DEF wProjectileBox  EQU $c4a2   ; wProjectile +4
DEF wProjectileX    EQU $c4a5   ; wProjectile +7 (16 bit with $c4a6)
DEF wProjectileY    EQU $c4a8   ; wProjectile +$a (16 bit with $c4a9)
DEF wProjectileSpeed EQU $c4af  ; wProjectile +$11
DEF wPaintX         EQU $c505   ; wPaintObject +7 (16 bit with $c506)
DEF wPaintY         EQU $c508   ; wPaintObject +$a (16 bit with $c509)
; score display: wScoreDigits holds the score as three bytes; DrawDecimalDigits turns them into six digits at $c467-$c46c, then tiles are streamed from $c46d
DEF wScoreDecimal   EQU $c467   ; six decimal digits of the score
DEF wScoreStream    EQU $c46d   ; VramCopyStream buffer: count, rows, then six digit tiles from $c46f
DEF hRoundSeconds   EQU $ffe3   ; seconds the round started with (hTimeSeconds counts down from it)
DEF hSpawnDelay     EQU $ffe9   ; delay value (in seconds into the round) of the next spawn from the wave list
DEF hSpawnFlag      EQU $ffee   ; flag bit taken from the low 3 bits of the Y byte of a spawn entry (bit 1 in rounds 17 and later, else bit 0); the Y position itself is Y and $f8
DEF hEnemySpawnFlag EQU $ffcf   ; per-enemy value set at spawn from hSpawnFlag; selects animation tables (provisional)
DEF hEnemyTimer     EQU $ffcb   ; per-enemy countdown (kind 7 follows its path when it runs out; provisional)
DEF hEnemyFrame     EQU $ffba   ; +5: animation frame index of the enemy record
DEF hEnemyField3    EQU $ffb8   ; +3: unused by the code read so far
DEF hEnemyXFrac     EQU $ffbb   ; +6: fraction of the X position
DEF hEnemyYFrac     EQU $ffbe   ; +9: fraction of the Y position
DEF hEnemyField13   EQU $ffc8   ; +$13: only copied (provisional)
DEF hEnemyField18   EQU $ffcd   ; +$18: only copied (provisional)
DEF hEnemyField19   EQU $ffce   ; +$19: only copied (provisional)
DEF hBlinkTick      EQU $ffde   ; incremented by the game; bit 2 alternates and makes blinking enemies visible every other group of frames (provisional)
DEF wPlayerStepXLo  EQU $c4ca   ; wPlayer +$0c: horizontal step (fraction part; $c4cb = wPlayerVelX is the pixel part)
DEF wPlayerStepYLo  EQU $c4cc   ; wPlayer +$0e: vertical step (fraction part; $c4cd = wPlayerVelY is the pixel part)
DEF wPlayerAnimPtrLo EQU $c4e3  ; pointer to the table of animation pointers chosen by SelectPlayerAnimation (16 bit with $c4e4)
DEF wPlayerAnimPtrHi EQU $c4e4

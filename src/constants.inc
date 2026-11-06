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
DEF hCountdownLo    EQU $ffe0   ; 16-bit frame countdown (reloaded with 60)
DEF hCountdownHi    EQU $ffe1
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
DEF wRoomType       EQU $c447   ; compared with 2/4/6/9 for special rooms
DEF wSubState       EQU $c53a   ; bit 0 = special action in progress
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

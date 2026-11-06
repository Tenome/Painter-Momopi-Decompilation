; RAM variables named from their use (see REVERSE.md). HRAM = $ff80-$fffe, WRAM = $c000-$dfff.
DEF hJoyHeld        EQU $ff8b   ; joypad state, bit 7-4 = start/select/b/a ... bit 3-0 = down/up/left/right; 15 = soft-reset combo
DEF hJoyNew         EQU $ff8c   ; buttons newly pressed this frame
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

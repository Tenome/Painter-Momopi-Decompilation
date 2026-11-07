INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank00", ROM0[$0000]

RstVector00::  ; jp RstJumpTable
    jp RstJumpTable
    INCBIN "assets/bank_00/0003.bin"
D_00_0027::
    INCBIN "assets/bank_00/0027.bin"
VBlankVector::  ; jp to VBlankHandler
    jp VBlankHandler
    INCBIN "assets/bank_00/0043.bin"
StatVector::  ; reti: the LCD STAT interrupt is not used
    reti
    INCBIN "assets/bank_00/0049.bin"
TimerVector::  ; reti: the timer interrupt is not used
    reti
    INCBIN "assets/bank_00/0051.bin"
SerialVector::  ; jp SerialHandler
    jp SerialHandler
    INCBIN "assets/bank_00/005b.bin"
JoypadVector::  ; reti: the joypad interrupt is not used
    reti
    INCBIN "assets/bank_00/0061.bin"
Entry::  ; nop; jp Start
    nop
    jp Start
    INCBIN "assets/bank_00/0104.bin"
Start::  ; sets SP=$dfff; clears WRAM and HRAM; inits LCD and palettes; enters mode 0
    ld sp, wStackTop
    call LcdOff
    di
    ld a, $01
    ld [$3fff], a
    ld hl, $c000
    ld bc, $1fef
    call ClearMemory
    ld hl, hOamDma
    ld bc, $007e
    call ClearMemory
    call CopyOamDmaRoutine
    ld hl, vBGMapLast
    call FillBackwardsFF
    call ClearOamShadow
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    xor a, a
    ld [rSCX], a
    ld [rSCY], a
    ld a, $01
    ld [wRound], a
    ld [wRoundBackup], a
    ld a, $03
    ld [wLives], a
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ld a, $ff
    call PlaySound
    xor a, a
GameModeDispatch::  ; rst $00 jump table indexed by A: 8 game modes (see REVERSE.md)
    rst $00
    dw Mode0_Title
    dw Mode1_Play
    dw Mode2_BonusSelect
    dw Mode3_RoundIntro
    dw Mode4_GameOver
    dw Mode5_Continue
    dw Mode6_Ending
    dw Mode7_LinkLose
LoadGfxBank2::  ; selects bank 2; copies $4000 (0x700 bytes) to VRAM $8000; then table-driven tiles to $8700
    ld a, $02
    ld [$3fff], a
    ld hl, SpriteTiles
    ld de, vTiles0
    ld bc, $0700
    call CopyMemory
    ld hl, RoomSpriteSetTable
    ld a, [wRoomIndex]
    call TableIndexFromRound
    ld de, vTiles1
    ld bc, $0900
    call CopyMemory
    ld a, $01
    ld [$3fff], a
    ret
LoadTilesBank3A::  ; bank 3 $4000 0x1000 bytes to $8000 via LoadTilesBank3
    ld hl, TilesTitle
    jr LoadTilesBank3Full
LoadTilesBank3B::  ; bank 3 $5000 0x1000 bytes to $8000
    ld hl, TilesIcons
    jr LoadTilesBank3Full
LoadTilesBank3D::  ; bank 3 $6e10 0x1000 bytes to $8000
    ld hl, TilesFont2
LoadTilesBank3Full::  ; BC = $1000 then LoadTilesBank3 (copies a full $1000 byte tile set from bank 3)
    ld bc, $1000
    jr LoadTilesBank3
LoadTilesBank3C::  ; bank 3 $6000 0xe10 bytes to $8000
    ld hl, TilesEnding
    ld bc, $0e10
LoadTilesBank3::  ; copy BC bytes from bank 3 HL to VRAM $8000
    ld a, $03
    ld [$3fff], a
    ld de, vTiles0
    call CopyMemory
    ld a, $01
    ld [$3fff], a
    ret
SerialStartTransfer::  ; link port: clears internal clock bit; sets transfer start
    ld a, [rSC]
    res 0, a
    ld [rSC], a
    ld a, [rSC]
    set 7, a
    ld [rSC], a
    ret
SerialHandler::  ; serial interrupt: stores received byte state in hSerialByte flags
    push af
    push bc
    push de
    push hl
    xor a, a
    ldh [hSerialByte], a
    ldh a, [hLinkFlags]
    and a, $f1
    ldh [hLinkFlags], a
    ld a, [rSC]
    bit 0, a
    jr z, .L_00_0241
    ld hl, hSerialByte
    set 2, [hl]
    set 0, [hl]
    pop hl
    pop de
    pop bc
    pop af
    reti
.L_00_0241:
    ld hl, wCheatFlags
    bit 3, [hl]
    jr nz, .L_00_02b3
    ld a, [rSB]
    bit 7, a
    jr z, .L_00_025b
    and a, $7f
    ld [wRemoteRound], a
    ld hl, hSerialByte
    set 4, [hl]
    jr .L_00_029f
.L_00_025b:
    ld a, [rSB]
    bit 2, a
    jr z, .L_00_0270
    ld hl, hLinkFlags
    set 1, [hl]
    ld hl, hSerialByte
    set 6, [hl]
    set 7, [hl]
    jr .L_00_029f
.L_00_0270:
    ld a, [rSB]
    bit 3, a
    jr z, .L_00_0283
    ld hl, hLinkFlags
    set 2, [hl]
    ld hl, hSerialByte
    set 3, [hl]
    jr .L_00_029f
.L_00_0283:
    ld a, [rSB]
    bit 1, a
    jr z, .L_00_0291
    ld hl, hSerialByte
    set 5, [hl]
    jr .L_00_029f
.L_00_0291:
    ld a, [rSB]
    bit 4, a
    jr z, .L_00_029f
    ld hl, hLinkFlags
    set 3, [hl]
    jr .L_00_029f
.L_00_029f:
    ld hl, hSerialByte
    set 2, [hl]
    set 1, [hl]
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    pop hl
    pop de
    pop bc
    pop af
    reti
.L_00_02b3:
    ld a, $88
    ld [rSB], a
    call SerialStartTransfer
    pop hl
    pop de
    pop bc
    pop af
    reti
VBlankHandler::  ; runs OAM DMA; queued VRAM copies; scroll; bank 1 per-frame update $4157; frame counters
    push af
    push bc
    push de
    push hl
    ldh a, [hJoyHeld]
    cp a, $0f
    jr nz, .L_00_02dd
    ld hl, rLCDC
    set 7, [hl]
    xor a, a
    ld [rIF], a
    ld [rIE], a
    ld [rSC], a
    di
    jp Entry
.L_00_02dd:
    ldh a, [hVBlankTasks]
    bit 1, a
    jp z, .L_00_02e7
    call $ff80
.L_00_02e7:
    nop
    ldh a, [hVBlankTasks]
    bit 0, a
    jp z, .L_00_02f7
    call VramCopyList
    ld hl, hVBlankTasks
    res 0, [hl]
.L_00_02f7:
    ldh a, [hVBlankTasks]
    bit 2, a
    jp z, .L_00_0306
    call VramCopyRows
    ld hl, hVBlankTasks
    res 2, [hl]
.L_00_0306:
    ld a, [wScrollX]
    ld [rSCX], a
    ld a, [wScrollY]
    ld [rSCY], a
    ldh a, [hVBlankTasks]
    bit 1, a
    jp z, .L_00_0321
    ld hl, hVBlankTasks
    res 1, [hl]
    call ClearOamShadowY
.L_00_0321:
    call SoundUpdate
    ldh a, [hVBlankTasks]
    bit 4, a
    jr z, .L_00_0348
    ldh a, [hTimeSeconds]
    and a, a
    jr z, .L_00_0348
    ldh a, [hTimeFrames]
    sub a, $01
    ldh [hTimeFrames], a
    jr nc, .L_00_0348
    ldh a, [hTimeSeconds]
    sbc a, $00
    ldh [hTimeSeconds], a
    jr nc, .L_00_0344
    ld hl, hVBlankTasks
    res 4, [hl]
.L_00_0344:
    ld a, $3c
    ldh [hTimeFrames], a
.L_00_0348:
    ld hl, hVBlankFlag
    set 0, [hl]
    ld hl, hFrameCounter
    inc [hl]
    pop hl
    pop de
    pop bc
    pop af
    reti
WaitSerialByte::  ; enables serial interrupt only and waits for hSerialByte
    xor a, a
    ld [rIF], a
    ld a, $08
    ldh [rIE], a
    xor a, a
    ldh [hSerialByte], a
.L_00_0361:
    ldh a, [hSerialByte]
    and a, a
    jr z, .L_00_0361
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ret
WaitFrameAndSyncOam::  ; waits one frame; requests OAM DMA
    push hl
    ld hl, hFrameSpin
.L_00_0373:
    inc [hl]
    ldh a, [hFrameCounter]
    cp a, $01
    jr c, .L_00_0373
    pop hl
    call RequestOamDma
    call WaitVBlankFlag
    xor a, a
    ldh [hFrameCounter], a
    ret
WaitVBlankFlag::  ; spins (bumping hRngCounter) until the VBlank handler sets hVBlankFlag
    push af
    push hl
    ld hl, hRngCounter
    xor a, a
    ldh [hVBlankFlag], a
.L_00_038d:
    inc [hl]
    ldh a, [hVBlankFlag]
    bit 0, a
    jr z, .L_00_038d
    pop hl
    pop af
    ret
DelayFrames::  ; waits A frames
    push bc
    push hl
    ld hl, hRngCounter
    ld b, a
    ldh a, [hFrameCounter]
    add a, b
    ld b, a
.L_00_03a1:
    ldh a, [hFrameCounter]
    inc [hl]
    cp a, b
    jr nz, .L_00_03a1
    ld a, [hl]
    ldh [hRngCounter], a
    pop hl
    pop bc
    ret
PlaySound::  ; stores A in wSoundArg and queues it with the bank 1 routine $485b
    ld [wSoundArg], a
    jp PlaySound_Bank1
FadeOut::  ; steps BGP/OBP0/OBP1 e4-94-50-40-00
    ld b, $05
.L_00_03b5:
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, PAL_FADE_1
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, .L_00_03b5
    ld b, $05
.L_00_03da:
    ld a, PAL_FADE_1
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, PAL_FADE_2
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, .L_00_03da
    ld b, $05
.L_00_03ff:
    ld a, PAL_FADE_2
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, PAL_FADE_3
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, .L_00_03ff
    ld b, $05
.L_00_0424:
    ld a, PAL_FADE_3
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, PAL_WHITE
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, .L_00_0424
    ret
ReadJoypad::  ; hJoyHeld = buttons+dpad; hJoyNew = newly pressed
    ld a, $20
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and a, $0f
    swap a
    ld b, a
    ld a, $10
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and a, $0f
    or a, b
    ld c, a
    ldh a, [hJoyHeld]
    xor a, c
    and a, c
    ldh [hJoyNew], a
    ld a, c
    ldh [hJoyHeld], a
    ld a, $30
    ld [rP1], a
    ret
CopyOamDmaRoutine::  ; copies 10 bytes to $ff80
    ld c, $80
    ld b, $0a
    ld hl, $0492
.L_00_048b:
    ld a, [hl+]
    ldh [c], a
    inc c
    dec b
    jr nz, .L_00_048b
    ret
OamDmaRoutine::  ; source of the HRAM routine: DMA from $c000 then waits 40 cycles
    ld a, $c0
    ldh [rDMA], a
    ld a, $28
DelayLoopA::  ; counts A down to 0 (busy wait)
    dec a
    jr nz, DelayLoopA
    ret
PixelToTilemapAddr::  ; hSpriteY/X pixel to BG map address $9800+
    ldh a, [hSpriteY]
    sub a, $10
    srl a
    srl a
    srl a
    ld de, $0000
    ld e, a
    ld hl, vBGMap0
    ld b, $20
.L_00_04af:
    add hl, de
    dec b
    jr nz, .L_00_04af
    ldh a, [hSpriteX]
    sub a, $08
    srl a
    srl a
    srl a
    ld de, $0000
    ld e, a
    add hl, de
    ld a, h
    ldh [hTilemapAddrHi], a
    ld a, l
    ldh [hTilemapAddrLo], a
    ret
RstJumpTable::  ; target of rst $00: pop hl; index word table after the rst
    add a, a
    pop hl
    ld e, a
    ld d, $00
    add hl, de
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    pop hl
    jp hl
LcdOff::  ; waits for LY=$91 then clears LCDC bit 7
    ldh a, [rIE]
    ldh [hSavedIE], a
    res 0, a
    ldh [rIE], a
.L_00_04dd:
    ld a, [rLY]
    cp a, $91
    jr nz, .L_00_04dd
    ld a, [rLCDC]
    and a, $7f
    ld [rLCDC], a
    ldh a, [hSavedIE]
    ldh [rIE], a
    ret
ClearMemory::  ; zero fill HL for BC bytes
    xor a, a
    ld [hl+], a
    dec bc
    ld a, c
    or a, b
    jr nz, ClearMemory
    ret
FillBackwardsFF::  ; fills $400 bytes with $ff going down from HL
    ld bc, $0400
FillBackwardsFFBC::  ; fills BC bytes with $ff going down from HL
    ld a, $ff
    ld [hl-], a
    dec bc
    ld a, b
    or a, c
    jr nz, FillBackwardsFFBC
    ret
CopyMemory::  ; copy BC bytes from HL to DE
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or a, c
    jr nz, CopyMemory
    ret
Clear32Bytes::  ; zero fill HL for 32 bytes
    ld b, $20
.L_00_0510:
    xor a, a
    ld [hl+], a
    dec b
    jr nz, .L_00_0510
    ret
SetObjPtr::  ; hObjPtr = HL
    ld a, h
    ldh [hObjPtrHi], a
    ld a, l
    ldh [hObjPtrLo], a
    ret
DrawBonusMetatileMap::  ; hScratch00 = $0a and hScratch01 = $09 then DrawMetatileMap (name provisional)
    ld a, $09
    ld [hScratch01], a
    ld a, $0a
    ld [hScratch00], a
DrawMetatileMap::  ; draws a map of 2x2 tile metatiles: HL VRAM dest; BC metatile table; DE cell map; mask in $c7c0
    ld a, l
    ldh [hScratch06], a
    ldh [hScratch08], a
    ld a, h
    ldh [hScratch07], a
    ldh [hScratch09], a
    ld a, c
    ldh [hScratch0A], a
    ld a, b
    ldh [hScratch0B], a
    ld a, e
    ldh [hScratch0C], a
    ld a, d
    ldh [hScratch0D], a
    ldh a, [hScratch00]
    ldh [hScratch10], a
    xor a, a
    ldh [hScratch03], a
    ldh [hScratch04], a
    ldh [hScratch05], a
.L_00_0548:
    ldh a, [hScratch0C]
    ld l, a
    ldh a, [hScratch0D]
    ld h, a
    ldh a, [hScratch04]
    ld e, a
    ld d, $00
    add hl, de
    ld a, [hl]
    ld b, $00
    sla a
    rl b
    sla a
    rl b
    ld c, a
    ldh a, [hScratch0A]
    ld l, a
    ldh a, [hScratch0B]
    ld h, a
    add hl, bc
    ld a, l
    ldh [hOtherObjLo], a
    ld a, h
    ldh [hOtherObjHi], a
    ldh a, [hScratch05]
    ld c, a
    ldh a, [hScratch03]
    ld b, a
    ld de, hScratch06
    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
    add hl, bc
    push hl
    ld hl, hOtherObjLo
    ld a, [hl]
    ld e, a
    inc hl
    ld a, [hl]
    ld d, a
    pop hl
    ld c, $02
.L_00_0588:
    ld b, $02
.L_00_058a:
    ld a, [de]
    push hl
    ld hl, wMapCellMask
    and a, [hl]
    pop hl
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .L_00_058a
    dec c
    jr z, .L_00_05a3
    push bc
    ld c, $1e
    ld b, $00
    add hl, bc
    pop bc
    jr .L_00_0588
.L_00_05a3:
    ldh a, [hScratch00]
    dec a
    jr z, .L_00_05c0
    ldh [hScratch00], a
    ld hl, hScratch04
    inc [hl]
    ldh a, [hScratch05]
    inc a
    inc a
    jr z, .L_00_05b9
    ldh [hScratch05], a
    jp .L_00_0548
.L_00_05b9:
    ld hl, hScratch03
    inc [hl]
    jp .L_00_0548
.L_00_05c0:
    ldh a, [hScratch01]
    dec a
    ret z
    ldh [hScratch01], a
    ld de, $0040
    ldh a, [hScratch08]
    ld l, a
    ldh a, [hScratch09]
    ld h, a
    add hl, de
    ld a, l
    ldh [hScratch06], a
    ldh [hScratch08], a
    ld a, h
    ldh [hScratch07], a
    ldh [hScratch09], a
    xor a, a
    ldh [hScratch05], a
    ldh a, [hScratch10]
    ldh [hScratch00], a
    ld hl, hScratch04
    inc [hl]
    jp .L_00_0548
QueueVramCopyRows::  ; queue run-length VRAM copy for the next VBlank
    ld a, h
    ld [wVramDstHi], a
    ld a, l
    ld [wVramDstLo], a
    ld a, d
    ld [wVramSrcHi], a
    ld a, e
    ld [wVramSrcLo], a
    ld hl, wVramCopyFlags
    set 0, [hl]
    ld hl, hVBlankTasks
    set 2, [hl]
    ret
QueueVramCopyList::  ; queue a list of VRAM copy jobs for the next VBlank
    ld a, c
    ld [wVramListPtrLo], a
    ld a, b
    ld [wVramListPtrHi], a
    ld hl, wVramCopyFlags
    set 0, [hl]
    set 7, [hl]
    ld hl, hVBlankTasks
    set 0, [hl]
    ret
VramCopyRows::  ; run-length copy of rows to VRAM (from VBlank)
    ld a, [wVramDstHi]
    ld h, a
    ld a, [wVramDstLo]
    ld l, a
    ld a, [wVramSrcHi]
    ld d, a
    ld a, [wVramSrcLo]
    ld e, a
VramCopyStream::  ; HL = VRAM destination; DE = stream of count/rows/tiles (count bit 7 = repeat one tile); copies the rows (shared by VramCopyRows)
    ld a, [de]
    ldh [hScratch12], a
    inc de
    ld a, [de]
    ld c, a
    inc de
.L_00_062f:
    ldh a, [hScratch12]
    res 7, a
    ld b, a
.L_00_0634:
    ld a, [de]
    ld [hl+], a
    ldh a, [hScratch12]
    bit 7, a
    jr nz, .L_00_063d
    inc de
.L_00_063d:
    dec b
    jr nz, .L_00_0634
    dec c
    jr z, .L_00_0657
    ld a, l
    add a, $20
    ld l, a
    jr nc, .L_00_064a
    inc h
.L_00_064a:
    ldh a, [hScratch12]
    res 7, a
    ld b, a
    ld a, l
    sub a, b
    ld l, a
    jr nc, .L_00_0655
    dec h
.L_00_0655:
    jr .L_00_062f
.L_00_0657:
    ld a, [wVramCopyFlags]
    bit 7, a
    ret nz
    ld hl, wVramCopyFlags
    res 0, [hl]
    ret
VramCopyList::  ; runs a list of VramCopyRows jobs (from VBlank)
    ld a, [wVramListPtrLo]
    ld c, a
    ld a, [wVramListPtrHi]
    ld b, a
RunVramCopyList::  ; BC = list of VRAM copy jobs run immediately
    ld a, [bc]
    ldh [hScratch15], a
    inc bc
.L_00_066f:
    ld a, b
    ldh [hScratch14], a
    ld a, c
    ldh [hScratch13], a
    ld a, [bc]
    ld l, a
    inc bc
    ld a, [bc]
    ld h, a
    inc bc
    ld a, [bc]
    ld e, a
    inc bc
    ld a, [bc]
    ld d, a
    call VramCopyStream
    ldh a, [hScratch15]
    dec a
    jr z, .L_00_0696
    ldh [hScratch15], a
    ldh a, [hScratch13]
    ld c, a
    ldh a, [hScratch14]
    ld b, a
    inc bc
    inc bc
    inc bc
    inc bc
    jr .L_00_066f
.L_00_0696:
    ld hl, wVramCopyFlags
    res 0, [hl]
    ret
WaitVramCopyDone::  ; waits until the VBlank task bit 2 is cleared
    ld a, [hVBlankTasks]
    bit 2, a
    jr nz, WaitVramCopyDone
    ret
ObjectShapeTable::  ; word pointers indexed by shape id; each shape = count then count pairs of signed (x y) offsets of 8x8 parts (read by DrawObject)
    INCBIN "assets/bank_00/06a4_ObjectShapeTable.bin"
ClearOamShadowY::  ; clears Y of every OAM shadow entry
    ld hl, $c000
.L_00_07ea:
    xor a, a
    ld [hl], a
    inc hl
    inc hl
    inc hl
    inc hl
    ld a, l
    cp a, $a0
    jr nz, .L_00_07ea
    xor a, a
    ldh [hOamCount], a
    ret
ClearOamShadow::  ; zero fills the 160 byte OAM shadow at $c000
    ld b, $a0
    xor a, a
    ldh [hOamCount], a
    ld hl, $c000
.L_00_0801:
    ld [hl+], a
    dec b
    jr nz, .L_00_0801
    ret
RequestOamDma::  ; sets the OAM DMA bit in hVBlankTasks
    ld hl, hVBlankTasks
    set 1, [hl]
    ret
DrawObjectBytePos::  ; variant of DrawObject for records with 8 bit positions (+6/+7)
    ldh a, [hObjPtrHi]
    ld h, a
    ld b, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld c, a
    ld a, [hl]
    bit 7, a
    jp z, ReturnOnly
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld d, $00
    ld e, $06
    add hl, de
    ld a, [hl]
    ldh [hScratch01], a
    ld a, $00
    ldh [hScratch02], a
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld d, $00
    ld e, $07
    add hl, de
    ld a, [hl]
    ldh [hScratch03], a
    ld a, $00
    ldh [hScratch04], a
    jr DrawObjectParts
DrawObject::  ; builds OAM sprites for the object record at hObjPtr from its animation data
    ldh a, [hObjPtrHi]
    ld h, a
    ld b, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld c, a
    ld a, [hl]
    bit 7, a
    jp z, ReturnOnly
    ld d, $00
    ld e, $07
    add hl, de
    ld a, [hl+]
    ldh [hScratch01], a
    ld a, [hl]
    ldh [hScratch02], a
    push bc
    pop hl
    ld d, $00
    ld e, $0a
    add hl, de
    ld a, [hl+]
    ldh [hScratch03], a
    ld a, [hl]
    ldh [hScratch04], a
DrawObjectParts::  ; shared part of DrawObject: applies camera
    push bc
    pop hl
    ld a, [hl]
    and a, $fb
    ldh [hScratch00], a
    and a, $02
    jr z, .L_00_0895
    ld a, [wCameraX]
    ld l, a
    ldh a, [hScratch01]
    sub a, l
    ldh [hScratch01], a
    ld a, [wCameraXHi]
    ld l, a
    ldh a, [hScratch02]
    sbc a, l
    ldh [hScratch02], a
    ld a, [wCameraY]
    ld l, a
    ldh a, [hScratch03]
    sub a, l
    ldh [hScratch03], a
    ld a, [wCameraYHi]
    ld l, a
    ldh a, [hScratch04]
    sbc a, l
    ldh [hScratch04], a
.L_00_0895:
    ldh a, [hScratch00]
    bit 5, a
    jr z, .L_00_08a7
    ldh a, [hScratch01]
    sub a, $08
    ldh [hScratch01], a
    ldh a, [hScratch02]
    sbc a, $00
    ldh [hScratch02], a
.L_00_08a7:
    ldh a, [hScratch00]
    bit 6, a
    jr z, .L_00_08b9
    ldh a, [hScratch03]
    sub a, $08
    ldh [hScratch03], a
    ldh a, [hScratch04]
    sbc a, $00
    ldh [hScratch04], a
.L_00_08b9:
    push bc
    pop hl
    ld d, $00
    ld e, $01
    add hl, de
    ld a, [hl+]
    ldh [hScratch05], a
    ld a, [hl]
    ldh [hScratch06], a
    or a, $9b
    jr nz, .L_00_08cb
    ret
.L_00_08cb:
    push bc
    pop hl
    ld d, $00
    ld e, $05
    add hl, de
    ld a, [hl]
    ldh [hOtherObjLo], a
    ldh a, [hScratch06]
    ld h, a
    ldh a, [hScratch05]
    ld l, a
    ld a, [hl]
    sla a
    ld e, a
    ld d, $00
    ld hl, ObjectShapeTable
    add hl, de
    ld a, [hl+]
    ldh [hScratch07], a
    ld a, [hl]
    ldh [hScratch08], a
    ldh a, [hScratch08]
    ld h, a
    ldh a, [hScratch07]
    ld l, a
    ld a, [hl]
    ldh [hScratch09], a
    ldh [hOtherObjHi], a
.L_00_08f6:
    ldh a, [hOtherObjLo]
    ld hl, hScratch09
    cp a, [hl]
    jr c, .L_00_0901
    xor a, a
    ldh [hOtherObjLo], a
.L_00_0901:
    ld hl, hOtherObjLo
    inc [hl]
    sla a
    ld c, a
    inc c
    ld b, $00
    ldh a, [hScratch00]
    sla a
    sla a
    sla a
    push af
    ld e, $00
    ldh a, [hScratch07]
    ld l, a
    ldh a, [hScratch08]
    ld h, a
    add hl, bc
    pop af
    ld a, [hl]
    jr nc, .L_00_0924
    ld a, $00
    sub a, [hl]
.L_00_0924:
    bit 7, a
    jr z, .L_00_0929
    dec e
.L_00_0929:
    ld hl, hScratch01
    add a, [hl]
    ldh [hScratch0A], a
    ld a, e
    ld hl, hScratch02
    adc a, [hl]
    jr nz, .L_00_098a
    inc c
    ldh a, [hScratch00]
    sla a
    sla a
    push af
    ld de, $0000
    ldh a, [hScratch07]
    ld l, a
    ldh a, [hScratch08]
    ld h, a
    add hl, bc
    pop af
    ld a, [hl]
    jr nc, .L_00_094e
    ld a, e
    sub a, [hl]
.L_00_094e:
    bit 7, a
    jr z, .L_00_0953
    dec e
.L_00_0953:
    ld hl, hScratch03
    add a, [hl]
    ldh [hScratch0B], a
    ld a, e
    ld hl, hScratch04
    adc a, [hl]
    jr nz, .L_00_098a
    ldh a, [hScratch05]
    ld l, a
    ldh a, [hScratch06]
    ld h, a
    ld d, $00
    ldh a, [hOtherObjLo]
    ld e, a
    add hl, de
    ld a, [hl]
    ldh [hScratch0C], a
    ldh a, [hScratch00]
    or a, $04
    ldh [hScratch00], a
    ld e, a
    and a, $08
    sla a
    sla a
    sla a
    sla a
    ld b, a
    ld a, e
    and a, $70
    or a, b
    ldh [hScratch0D], a
    call AddOamSprite
.L_00_098a:
    ld hl, hOtherObjHi
    dec [hl]
    jp nz, .L_00_08f6
    ldh a, [hObjPtrLo]
    ld l, a
    ld c, a
    ldh a, [hObjPtrHi]
    ld h, a
    ld b, a
    ldh a, [hScratch00]
    ld [hl], a
    ld hl, hOtherObjLo
    dec [hl]
    ld e, $05
    ld d, $00
    push bc
    pop hl
    add hl, de
    ldh a, [hOtherObjLo]
    ld [hl], a
ReturnOnly::  ; a bare ret (jump target of DrawObject for inactive objects)
    ret
AddOamSprite::  ; appends one OAM entry from hScratch values to the shadow at $c000 (hOamCount wraps at 39)
    ldh a, [hOamCount]
    cp a, $27
    jr c, .L_00_09b4
    xor a, a
    ldh [hOamCount], a
.L_00_09b4:
    sla a
    sla a
    ld c, a
    ld b, $00
    ldh a, [hScratch0B]
    ld hl, $c000
    add hl, bc
    ld [hl+], a
    ldh a, [hScratch0A]
    ld [hl+], a
    ldh a, [hScratch0C]
    ld [hl+], a
    ldh a, [hScratch0D]
    ld [hl], a
    ldh a, [hOamCount]
    inc a
    ldh [hOamCount], a
    ret
MoveObjectHalfStep::  ; adds the X and Y deltas at offsets 6 and 8 to the position (name provisional)
    ld e, $06
    ld a, e
    ldh [hScratch00], a
    ld e, $08
    ld a, e
    ldh [hScratch01], a
    call AddObjectField
    jr AddObjectField
ApplyObjectStep::  ; adds the horizontal step (+$0c/+$0d) to the 24 bit fixed point X (+6 fraction
    ld e, $06
    ld a, e
    ldh [hScratch00], a
    ld e, $0c
    ld a, e
    ldh [hScratch01], a
    call AddStepSigned
AddStepSigned::  ; adds one step to a fixed point coordinate: two AddObjectField bytes then the sign extension of the step into the top byte
    and a, a
    call AddObjectField
    call AddObjectField
    ld c, $00
    ldh a, [hScratch02]
    bit 7, a
    jr z, .L_00_09fd
    dec c
.L_00_09fd:
    ldh a, [hScratch00]
    ld e, a
    ld d, $00
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    push af
    add hl, de
    pop af
    ld a, c
    adc a, [hl]
    ld [hl], a
    ld hl, hScratch00
    inc [hl]
    ret
AddObjectField::  ; object byte [hScratch00] += object byte [hScratch01] (with carry); both indexes then advance (name provisional)
    ldh a, [hScratch01]
    ld e, a
    ld d, $00
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    push af
    add hl, de
    pop af
    ld a, [hl]
    ld b, a
    ldh [hScratch02], a
    ldh a, [hScratch00]
    ld e, a
    ld d, $00
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    push af
    add hl, de
    pop af
    ld a, b
    adc a, [hl]
    ld [hl], a
    ld hl, hScratch00
    inc [hl]
    ld hl, hScratch01
    inc [hl]
    ret
D_00_0a3f::
    INCBIN "assets/bank_00/0a3f.bin"
SerialSendByte::  ; sends C over the link port with the internal clock and waits for the reply
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    ld a, c
    ld [rSB], a
    ld a, [rSC]
    set 0, a
    ld [rSC], a
    ld a, [rSC]
    set 7, a
    ld [rSC], a
    call WaitSerialByte
    jp WaitVBlankFlag
ByteToBCD::  ; converts a byte in A (and C flag) to decimal digits using daa
    ldh [hScratch00], a
    ld a, c
    ldh [hScratch01], a
    xor a, a
    ldh [hScratch02], a
    ldh [hScratch03], a
    ldh a, [hScratch01]
    and a, a
    jr z, .L_00_0a86
    ldh a, [hScratch00]
    add a, $38
    ldh [hScratch00], a
    ldh a, [hScratch03]
    add a, $02
    ldh [hScratch03], a
.L_00_0a86:
    ldh a, [hScratch00]
    cp a, $0a
    jr c, .L_00_0a9f
    sub a, $0a
    ldh [hScratch00], a
    ldh a, [hScratch02]
    add a, $10
    daa
    ldh [hScratch02], a
    ldh a, [hScratch03]
    adc a, $00
    ldh [hScratch03], a
    jr .L_00_0a86
.L_00_0a9f:
    push de
    ldh a, [hScratch00]
    ld d, a
    ldh a, [hScratch02]
    add a, d
    ldh [hScratch02], a
    pop de
    ret
LookupByte::  ; A = byte at HL + C (table lookup)
    ld b, $00
    add hl, bc
    ld a, [hl]
    ret
LookupWord::  ; HL = word at HL + A*2 (also copied to DE and BC)
    sla a
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl]
    ld e, a
    inc hl
    ld a, [hl]
    ld d, a
    push de
    pop hl
    push de
    pop bc
    ret
ObjectsOverlap::  ; hObjPtr object against the object at hOtherObj: A = $80 and C = $80 when their boxes overlap else 0
    ldh a, [hEnemyBoxHalf]
    sla a
    ldh [hScratch02], a
    ld e, $04
    ld d, $00
    ldh a, [hOtherObjHi]
    ld h, a
    ldh a, [hOtherObjLo]
    ld l, a
    add hl, de
    ld a, [hl]
    sla a
    ldh [hScratch03], a
    ldh a, [hEnemyXHi]
    and a, a
    jr nz, .L_00_0b03
    ld e, $08
    ld d, $00
    ldh a, [hOtherObjHi]
    ld h, a
    ldh a, [hOtherObjLo]
    ld l, a
    add hl, de
    ld a, [hl]
    and a, a
    jr nz, .L_00_0b03
    ld e, $07
    ld d, $00
    call CompareObjectCoordinate
    jr nc, .L_00_0b03
    ld hl, hScratch02
    inc [hl]
    ld hl, hScratch03
    inc [hl]
    ld e, $0a
    ld d, $00
    call CompareObjectCoordinate
    jr c, .L_00_0b06
.L_00_0b03:
    xor a, a
    ld c, a
    ret
.L_00_0b06:
    ld a, $80
    ld c, a
    ret
CompareObjectCoordinate::  ; compares a coordinate (offset in DE) of the two objects; carry = within the box size
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    add hl, de
    ld a, [hl]
    push af
    ldh a, [hOtherObjHi]
    ld h, a
    ldh a, [hOtherObjLo]
    ld l, a
    add hl, de
    pop af
    sub a, [hl]
    ldh [hScratch04], a
    jp nc, .L_00_0b27
    ld hl, hScratch04
    xor a, a
    sub a, [hl]
    ld [hl], a
.L_00_0b27:
    ldh a, [hScratch02]
    ld e, a
    ld d, $00
    ldh a, [hScratch03]
    ld c, a
    ld b, $00
    ld hl, D_00_0a3f
    add hl, de
    ld a, [hl]
    ld hl, D_00_0a3f
    add hl, bc
    add a, [hl]
    ldh [hScratch06], a
    ldh a, [hScratch04]
    ld hl, hScratch06
    cp a, [hl]
    ret
NextRandomDirection::  ; derives a pseudo random direction nibble from hFrameSpin
    ldh a, [hFrameSpin]
    and a, $10
    jr z, .L_00_0b55
    ldh a, [hFrameSpin]
    sla a
    jr c, .L_00_0b5b
.L_00_0b50:
    and a, $fe
    jp .L_00_0b5d
.L_00_0b55:
    ldh a, [hFrameSpin]
    sla a
    jr c, .L_00_0b50
.L_00_0b5b:
    or a, $01
.L_00_0b5d:
    ldh [hFrameSpin], a
    ld b, a
    ldh a, [hRngCounter]
    add a, b
    ldh [hRngCounter], a
    ret
MoveObject::  ; moves the object by its heading (+$10
    ldh a, [hObjPtrLo]
    ld l, a
    ldh a, [hObjPtrHi]
    ld h, a
    push hl
    ld b, $00
    ld c, $11
    add hl, bc
    ld a, [hl]
    ld e, a
    pop hl
    push de
    ld b, $00
    ld c, $10
    add hl, bc
    ld a, [hl]
    sla a
    ld b, $00
    ld c, a
    ld hl, MoveVectorTable
    add hl, bc
    ld a, [hl]
    push af
    inc hl
    ld a, [hl]
    call MultiplyByDE
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld b, $00
    ld c, $0e
    add hl, bc
    ldh a, [hScratch00]
    ld [hl], a
    inc hl
    ldh a, [hScratch01]
    ld [hl], a
    pop af
    pop de
    call MultiplyByDE
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld b, $00
    ld c, $0c
    add hl, bc
    ldh a, [hScratch00]
    ld [hl], a
    inc hl
    ldh a, [hScratch01]
    ld [hl], a
    ret
MoveVectorTable::  ; 32 headings (index 0-31) x (dx dy) signed bytes: points on a circle of radius about 50; MoveObject multiplies them by the speed
    INCBIN "assets/bank_00/0bb6_MoveVectorTable.bin"
MultiplyByDE::  ; signed multiply of A by DE (shift and add)
    push af
    bit 7, a
    jr z, .L_00_0c00
    cpl
    add a, $01
.L_00_0c00:
    ld h, $00
    ld l, h
    ld d, h
    ld c, $08
.L_00_0c06:
    srl a
    jr nc, .L_00_0c0b
    add hl, de
.L_00_0c0b:
    sla e
    rl d
    dec c
    jr nz, .L_00_0c06
    pop af
    bit 7, a
    jp z, .L_00_0c23
    ld a, $00
    sub a, l
    ldh [hScratch00], a
    ld a, $00
    sbc a, h
    ldh [hScratch01], a
    ret
.L_00_0c23:
    ld a, h
    ldh [hScratch01], a
    ld a, l
    ldh [hScratch00], a
    ret
CounterToFrame::  ; turns a running counter and a bit mask (hScratch06-08) into a frame index
    dec a
    ldh [hScratch05], a
    ld hl, hScratch06
    ldh a, [hScratch08]
    and a, [hl]
.L_00_0c33:
    srl a
    ld hl, hScratch07
    dec [hl]
    jr nz, .L_00_0c33
    ld b, a
    ldh a, [hScratch05]
    cp a, b
    jr nc, .L_00_0c45
    ld a, $00
    ldh [hScratch08], a
.L_00_0c45:
    sla b
    ld c, b
    ret
PaintCellCountTable::  ; number of path cells to paint per round (index (round-1)&15): initial wPaintRemaining
    INCBIN "assets/bank_00/0c49_PaintCellCountTable.bin"
UnpackRoomMap::  ; HL = packed map (2 bits per cell; 4 cells per byte) unpacked to the 256 byte wRoomMap
    ld c, $00
    ld b, $01
    ld de, wRoomMap
.L_00_0d15:
    push hl
    ld a, $04
    ld [$c1b5], a
    pop hl
    ld a, [hl]
    ldh [hScratch02], a
.L_00_0d1f:
    ldh a, [hScratch02]
    rlc a
    rlc a
    ldh [hScratch02], a
    and a, $03
    ld [de], a
    inc de
    push hl
    ld hl, $c1b5
    dec [hl]
    pop hl
    jr nz, .L_00_0d1f
    inc hl
    dec bc
    dec bc
    dec bc
    dec bc
    ld a, c
    or a, b
    jr nz, .L_00_0d15
    ret
RoundDataTable::  ; 33 pointers indexed by wRound-1
    dw SpawnRound01
    dw SpawnRound02
    dw SpawnRound03
    dw SpawnRound04
    dw SpawnRound05
    dw SpawnRound06
    dw SpawnRound07
    dw SpawnRound08
    dw SpawnRound09
    dw SpawnRound10
    dw SpawnRound11
    dw SpawnRound12
    dw SpawnRound13
    dw SpawnRound14
    dw SpawnRound15
    dw SpawnRound16
    dw SpawnRound01
    dw SpawnRound02
    dw SpawnRound03
    dw SpawnRound04
    dw SpawnRound05
    dw SpawnRound06
    dw SpawnRound07
    dw SpawnRound08
    dw SpawnRound09
    dw SpawnRound10
    dw SpawnRound11
    dw SpawnRound12
    dw SpawnRound13
    dw SpawnRound14
    dw SpawnRound15
    dw SpawnRound16
    dw SpawnRound33
SpawnRound01::  ; data (table entry)
    INCBIN "assets/bank_00/0d7f_SpawnRound01.bin"
SpawnRound02::  ; data (table entry)
    INCBIN "assets/bank_00/0da5_SpawnRound02.bin"
SpawnRound03::  ; data (table entry)
    INCBIN "assets/bank_00/0dd0_SpawnRound03.bin"
SpawnRound04::  ; data (table entry)
    INCBIN "assets/bank_00/0dff_SpawnRound04.bin"
SpawnRound05::  ; data (table entry)
    INCBIN "assets/bank_00/0e25_SpawnRound05.bin"
SpawnRound06::  ; data (table entry)
    INCBIN "assets/bank_00/0e4b_SpawnRound06.bin"
SpawnRound07::  ; data (table entry)
    INCBIN "assets/bank_00/0e75_SpawnRound07.bin"
SpawnRound08::  ; data (table entry)
    INCBIN "assets/bank_00/0ea8_SpawnRound08.bin"
SpawnRound09::  ; data (table entry)
    INCBIN "assets/bank_00/0ec1_SpawnRound09.bin"
SpawnRound10::  ; data (table entry)
    INCBIN "assets/bank_00/0eee_SpawnRound10.bin"
SpawnRound11::  ; data (table entry)
    INCBIN "assets/bank_00/0f0b_SpawnRound11.bin"
SpawnRound12::  ; data (table entry)
    INCBIN "assets/bank_00/0f30_SpawnRound12.bin"
SpawnRound13::  ; data (table entry)
    INCBIN "assets/bank_00/0f56_SpawnRound13.bin"
SpawnRound14::  ; data (table entry)
    INCBIN "assets/bank_00/0f73_SpawnRound14.bin"
SpawnRound15::  ; data (table entry)
    INCBIN "assets/bank_00/0f94_SpawnRound15.bin"
SpawnRound16::  ; data (table entry)
    INCBIN "assets/bank_00/0fbd_SpawnRound16.bin"
SpawnRound33::  ; data (table entry)
    INCBIN "assets/bank_00/0fda_SpawnRound33.bin"
AddScore::  ; adds to the BCD score digits at wScoreDigits
    ld bc, $0000
    ld hl, wScoreDigits
    ld a, e
    add a, [hl]
    ld [wScoreTemp], a
    call ByteToBCD
    ldh a, [hScratch03]
    and a, a
    jr z, .L_00_1027
    inc d
    ld a, [wScoreTemp]
    sub a, $64
    ld [wScoreTemp], a
.L_00_1027:
    ld a, [wScoreTemp]
    ld [hl], a
    inc hl
    ld a, $00
    ld a, d
    adc a, [hl]
    ld [hl], a
    inc hl
    ld a, $00
    adc a, [hl]
    ld [hl], a
    call DrawDecimalDigits
    dec hl
    call DrawDecimalDigits
    dec hl
    call DrawDecimalDigits
    ld a, $06
    ld [wScoreStream], a
    ld a, $01
    ld [$c46e], a
    ld a, [wScoreDecimal]
    call LowNibbleToDigitTile
    ld [$c46f], a
    ld a, [$c468]
    call LowNibbleToDigitTile
    ld [$c470], a
    ld a, [$c469]
    call LowNibbleToDigitTile
    ld [$c471], a
    ld a, [$c46a]
    call LowNibbleToDigitTile
    ld [$c472], a
    ld a, [$c46b]
    call LowNibbleToDigitTile
    ld [$c473], a
    ld a, [$c46c]
    call LowNibbleToDigitTile
    ld [$c474], a
    jp CheckExtraLife
DrawDecimalDigits::  ; draws a byte as decimal digits using ByteToBCD
    push hl
    ld a, [hl]
    push bc
    ld c, $00
    call ByteToBCD
    pop bc
    ldh a, [hScratch02]
    ld d, a
    swap a
    and a, $0f
    ld hl, wScoreDecimal
    add hl, bc
    ld [hl], a
    inc bc
    inc bc
    inc hl
    ld a, d
    and a, $0f
    ld [hl], a
    pop hl
    ret
LowNibbleToDigitTile::  ; A and $0f then falls into NumberToTile
    and a, $0f
NumberToTile::  ; digit in A to its tile id using the table at 10ab
    ld c, a
    ld hl, D_00_10ab
    jp LookupByte
D_00_10ab::
    INCBIN "assets/bank_00/10ab.bin"
Mode1_Play::  ; gameplay in a room (paint the floor); loads tiles of bank 2
    ld sp, wStackTop
    call LcdOff
    di
    ld hl, vBGMapLast
    call FillBackwardsFF
    call LoadGfxBank2
    call ClearOamShadow
    ld hl, RoomMapTable
    ld a, [wRound]
    call TableIndexFromRoundDec
    call UnpackRoomMap
    ld a, $10
    ld [hScratch01], a
    ld a, $10
    ld [hScratch00], a
    ld a, [wRoomIndex]
    ld hl, RoomMetatileTable
    call TableIndexFromRound
    ld hl, vBGMap0
    ld de, wRoomMap
    ld a, $0f
    ld [wMapCellMask], a
    call DrawMetatileMap
    ld a, [wRoomIndex]
    ld hl, RoomVramJobTable
    call TableIndexFromRound
    call RunVramCopyList
    ld c, $10
    ld a, [wRound]
    dec a
    cp a, $20
    jr nz, .L_00_110e
    jp .L_00_1111
.L_00_110e:
    and a, $0f
    ld c, a
.L_00_1111:
    ld hl, PaintCellCountTable
    call LookupByte
    ld [wPaintRemaining], a
    call RequestOamDma
    call ClearOamShadowY
    call InitMagicScreenState
    call InitMagicPoints
    call ResetCamera
    ld a, [wRoundFlags]
    bit 2, a
    jr nz, .L_00_1138
    set 2, a
    ld [wRoundFlags], a
    call ClearRoundVariables
.L_00_1138:
    ld a, [wGameFlags]
    bit 7, a
    jr nz, .L_00_1147
    set 7, a
    ld [wGameFlags], a
    call InitPlayer
.L_00_1147:
    call ClearAllEnemies
    ld hl, wProjectile
    call Clear32Bytes
    call SerialStartTransfer
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    call StartRoundMusic
    ld hl, wGameFlags
    res 5, [hl]
    ld a, $3c
    ldh [hTimeFrames], a
    ld a, [wRound]
    cp a, $21
    jr nz, .L_00_117f
    ld a, $5a
    jr .L_00_118a
.L_00_117f:
    srl a
    srl a
    ld c, a
    ld hl, RoundTimeTable
    call LookupByte
.L_00_118a:
    ldh [hTimeSeconds], a
    ldh [hRoundSeconds], a
    ld hl, hVBlankTasks
    set 4, [hl]
.L_00_1193:
    call WaitFrameAndSyncOam
    call ReadJoypad
    call PlayFrame
    call ShowMagicScreen
    call UpdateCamera
    call StepEnemySpawnScript
    call UpdateAllEnemies
    call TimeUpSpawnEnemy
    call CheckExtraLife
    ld hl, $ffde
    inc [hl]
    jr .L_00_1193
CheckExtraLife::  ; when a score digit reaches the next threshold (table $11e7): wLives += 1 (once per threshold)
    ld a, [wRoundFlags]
    bit 1, a
    jr nz, .L_00_11c6
    ld a, [$c465]
    cp a, $02
    ret c
    ld hl, wRoundFlags
    set 1, [hl]
.L_00_11c6:
    ld a, [$c46a]
    ld d, a
    ld a, [wExtraLifeIdx]
    cp a, $05
    jr nz, .L_00_11d5
    xor a, a
    ld [wExtraLifeIdx], a
.L_00_11d5:
    ld c, a
    ld hl, D_00_11e7
    call LookupByte
    cp a, d
    ret nz
    ld hl, wLives
    inc [hl]
    ld hl, wExtraLifeIdx
    inc [hl]
    ret
D_00_11e7::
    INCBIN "assets/bank_00/11e7.bin"
TimeUpSpawnEnemy::  ; when hTimeSeconds reaches 0 (once per round): creates an extra enemy ($a0/$04) in a free slot
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_00_11f8
    ldh a, [hSerialByte]
    bit 5, a
    jr nz, .L_00_11ff
.L_00_11f8:
    ldh a, [hTimeSeconds]
    ld b, a
    ldh a, [$ffe2]
    or a, b
    ret nz
.L_00_11ff:
    ld a, [wGameFlags]
    bit 5, a
    ret nz
    set 5, a
    ld [wGameFlags], a
    ld a, $04
    ldh [hScratch07], a
    ld a, $a0
    ldh [hScratch08], a
    ld a, $98
    ldh [hScratch0A], a
    call FindFreeEnemySlot
    jp SerialStartTransfer
ShowMagicScreen::  ; B button in play: MOMOPIE'S MAGIC screen (score
    ld a, [wPlayerDir]
    bit 5, a
    ret nz
    ld a, [wMagicState]
    bit 1, a
    ret nz
    ldh a, [hJoyNew]
    bit 1, a
    ret z
    call LcdOff
    di
    call LoadTilesBank3B
    ld hl, $9fff
    call FillBackwardsFF
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld hl, hVBlankTasks
    res 4, [hl]
    ld bc, D_00_1a94
    call RunVramCopyList
    ld bc, D_00_1a57
    call RunVramCopyList
    ld bc, $0010
    ld hl, $9cd0
    call FillBackwardsFFBC
    xor a, a
    ld [wMpStreamIdx], a
    ld bc, $0010
    ld hl, $c462
.L_00_1265:
    ld a, $98
    ld [hl], a
    dec hl
    dec bc
    ld a, b
    or a, c
    jr nz, .L_00_1265
    call InitMagicScreenState
    ld hl, $9c66
    ld de, wScoreStream
    call VramCopyStream
    ld a, [wMagicPointsHi]
    ld c, a
    ld a, [wMagicPoints]
    call ByteToBCD
    ldh a, [hScratch02]
    and a, $0f
    call NumberToTile
    ld [$c450], a
    ldh a, [hScratch02]
    swap a
    and a, $0f
    call NumberToTile
    ld [$c44f], a
    ldh a, [hScratch03]
    call NumberToTile
    ld [$c44e], a
    ld a, $03
    ld [wTextBuf], a
    ld a, $01
    ld [$c44d], a
    ld hl, $9ca5
    ld de, wTextBuf
    call VramCopyStream
    ldh a, [hTimeSeconds]
    ld c, $00
    call ByteToBCD
    ldh a, [hScratch02]
    and a, $0f
    call NumberToTile
    ld [$ffe8], a
    ldh a, [hScratch02]
    swap a
    and a, $0f
    call NumberToTile
    ld [$ffe7], a
    ldh a, [hScratch03]
    call NumberToTile
    ld [$ffe6], a
    ld a, $03
    ld [$ffe4], a
    ld a, $01
    ld [$ffe5], a
    ld hl, $9cb0
    ld de, $ffe4
    call VramCopyStream
    ld a, [wRound]
    ld b, a
    ld hl, $9c71
    call DrawTwoDigitNumber
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    call ClearOamShadowY
    call RequestOamDma
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, $9b
    ld [rLCDC], a
    ei
    xor a, a
    ldh [hScratch00], a
    call DrawMagicPage
    ld bc, $0002
    ld a, [wMagicPointsHi]
    and a, a
    jr z, .L_00_1325
    ld e, $01
    jr .L_00_1327
.L_00_1325:
    ld e, $00
.L_00_1327:
    ld a, [wMagicPoints]
    ldh [hScratch00], a
DrawMagicPointsDigits::  ; loop of the magic points display: subtracts 100s then 10s from hScratch00 and stores tile $b8 style digits into the stream at $c453 (name provisional)
    ldh a, [hScratch00]
    sub a, $64
    ld d, a
    jr c, .L_00_1338
    ldh [hScratch00], a
    jp StoreMagicPointsDigit
.L_00_1338:
    ld a, e
    and a, a
    jr z, .L_00_1344
    ld a, d
    ldh [hScratch00], a
    ld e, $00
    jp StoreMagicPointsDigit
.L_00_1344:
    ldh a, [hScratch00]
    and a, a
    jr z, .L_00_1371
    cp a, $0a
    jr z, .L_00_1364
    sub a, $14
    ldh [hScratch00], a
    ld a, [wMpStreamIdx]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $b8
    ld [hl], a
    ld hl, wMpStreamIdx
    inc [hl]
    jr .L_00_1344
.L_00_1364:
    ld a, [wMpStreamIdx]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $a8
    ld [hl], a
.L_00_1371:
    ld a, $10
    ld [wMpStream], a
    ld a, $01
    ld [$c452], a
    ld hl, $9cc2
    ld de, wMpStream
    call QueueVramCopyRows
    call WaitVramCopyDone
    call WaitVBlankFlag
    ld a, $ff
    call PlaySound
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
.L_00_1396:
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 2, a
    jr z, .L_00_13a9
    bit 7, a
    jp nz, GotoLinkLose
    bit 3, a
    jp nz, GotoLinkLose
.L_00_13a9:
    call ReadJoypad
    ld hl, $c769
    inc [hl]
    call MagicScreenInput
    call CursorBlinkStep
    ldh a, [hJoyNew]
    bit 1, a
    jr z, .L_00_1396
    ld hl, wMagicScreenFlags
    res 1, [hl]
    call LcdOff
    di
    call LoadGfxBank2
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    call ClearOamShadow
    call RequestOamDma
    call ClearOamShadowY
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
StartRoundMusic::  ; plays the song for the current round (id from a table indexed by wRound/4) and starts the frame countdown
    call WaitVBlankFlag
    ld a, [wRound]
    srl a
    srl a
    ld c, a
    ld hl, D_00_1400
    call LookupByte
    call PlaySound
    ld hl, hVBlankTasks
    set 4, [hl]
    ret
D_00_1400::
    INCBIN "assets/bank_00/1400.bin"
StoreMagicPointsDigit::  ; writes one block of digit tiles into the magic points stream and advances wMpStreamIdx by 5 (name provisional)
    ld a, [wMpStreamIdx]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $b8
    ld [hl], a
    inc hl
    ld [hl], a
    inc hl
    ld [hl], a
    inc hl
    ld [hl], a
    inc hl
    ld [hl], a
    ld a, [wMpStreamIdx]
    add a, $05
    ld [wMpStreamIdx], a
    jp DrawMagicPointsDigits
TableIndexFromRoundDec::  ; dec a then falls into TableIndexFromRound
    dec a
TableIndexFromRound::  ; A = (A-1)&15 or 16 for 32; then LookupWord
    ld c, $10
    cp a, $20
    jr nz, .L_00_1433
    ld a, c
    jr .L_00_1435
.L_00_1433:
    and a, $0f
.L_00_1435:
    jp LookupWord
InitMagicPoints::  ; loads the magic points ($c44a/$c44b) from MagicPointsTable by round ($0140 in a link game)
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_00_144a
    ld a, $40
    ld [wMagicPoints], a
    ld a, $01
    ld [wMagicPointsHi], a
    jr .L_00_145e
.L_00_144a:
    ld a, [wRound]
    sla a
    ld c, a
    ld b, $00
    ld hl, MagicPointsTable
    add hl, bc
    ld a, [hl+]
    ld [wMagicPointsHi], a
    ld a, [hl]
    ld [wMagicPoints], a
.L_00_145e:
    xor a, a
    ldh [$ffea], a
    ret
MagicPointsTable::  ; 16 bit MP per round (round 1 = 50)
    INCBIN "assets/bank_00/1462_MagicPointsTable.bin"
ClearRoundVariables::  ; zeroes the per-round counters ($c464-$c46c and $c488)
    xor a, a
    ld [wExtraLifeIdx], a
    ld [wScoreDigits], a
    ld [$c465], a
    ld [$c466], a
    ld [wScoreDecimal], a
    ld [$c468], a
    ld [$c469], a
    ld [$c46a], a
    ld [$c46b], a
    ld [$c46c], a
    ld a, $06
    ld [wScoreStream], a
    ld a, $01
    ld [$c46e], a
    ld a, $ab
    ld [$c46f], a
    ld [$c470], a
    ld [$c471], a
    ld [$c472], a
    ld [$c473], a
    ld [$c474], a
    ret
    INCBIN "assets/bank_00/14e4.bin"
RoundTimeTable::  ; seconds per round block (index wRound/4): initial hTimeSeconds
    INCBIN "assets/bank_00/14f0_RoundTimeTable.bin"
RoomVramJobTable::  ; 17 pointers to VRAM copy job lists
    dw RoomVramJob0
    dw RoomVramJob1
    dw RoomVramJob2
    dw RoomVramJob3
    dw RoomVramJob4
    dw RoomVramJob5
    dw RoomVramJob6
    dw RoomVramJob7
    dw RoomVramJob8
    dw RoomVramJob9
    dw RoomVramJob10
    dw RoomVramJob3
    dw RoomVramJob12
    dw RoomVramJob13
    dw RoomVramJob14
    dw RoomVramJob7
    dw RoomVramJob16
RoomVramJob0::  ; data (table entry)
    INCBIN "assets/bank_00/151b_RoomVramJob0.bin"
RoomVramJob1::  ; data (table entry)
    INCBIN "assets/bank_00/1538_RoomVramJob1.bin"
RoomVramJob2::  ; data (table entry)
    INCBIN "assets/bank_00/1551_RoomVramJob2.bin"
RoomVramJob4::  ; data (table entry)
    INCBIN "assets/bank_00/156a_RoomVramJob4.bin"
RoomVramJob5::  ; data (table entry)
    INCBIN "assets/bank_00/1583_RoomVramJob5.bin"
RoomVramJob6::  ; data (table entry)
    INCBIN "assets/bank_00/1598_RoomVramJob6.bin"
RoomVramJob8::  ; data (table entry)
    INCBIN "assets/bank_00/15b1_RoomVramJob8.bin"
RoomVramJob10::  ; data (table entry)
    INCBIN "assets/bank_00/15c2_RoomVramJob10.bin"
RoomVramJob9::  ; data (table entry)
    INCBIN "assets/bank_00/15d7_RoomVramJob9.bin"
RoomVramJob12::  ; data (table entry)
    INCBIN "assets/bank_00/15f0_RoomVramJob12.bin"
RoomVramJob13::  ; data (table entry)
    INCBIN "assets/bank_00/1609_RoomVramJob13.bin"
RoomVramJob14::  ; data (table entry)
    INCBIN "assets/bank_00/161e_RoomVramJob14.bin"
RoomVramJob3::  ; data (table entry)
    INCBIN "assets/bank_00/1637_RoomVramJob3.bin"
RoomVramJob7::  ; data (table entry)
    INCBIN "assets/bank_00/1640_RoomVramJob7.bin"
RoomVramJob16::  ; data (table entry)
    INCBIN "assets/bank_00/1649_RoomVramJob16.bin"
RoomMetatileTable::  ; 17 pointers to metatile definitions per room theme
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles0
    dw RoomMetatiles8
    dw RoomMetatiles8
    dw RoomMetatiles8
    dw RoomMetatiles0
    dw RoomMetatiles12
    dw RoomMetatiles12
    dw RoomMetatiles12
    dw RoomMetatiles0
    dw RoomMetatiles12
RoomSpriteSetTable::  ; 17 pointers into bank 2 to the sprite tile set copied to $8700 (0x900 bytes)
    dw SpriteSet0
    dw SpriteSet0
    dw SpriteSet0
    dw SpriteSet3
    dw SpriteSet3
    dw SpriteSet3
    dw SpriteSet3
    dw SpriteSet4
    dw SpriteSet2
    dw SpriteSet2
    dw SpriteSet2
    dw SpriteSet3
    dw SpriteSet1
    dw SpriteSet1
    dw SpriteSet1
    dw SpriteSet4
    dw SpriteSet1
RoomMapTable::  ; 17 pointers to packed 64 byte room maps (index (round-1)&15; 16 = bonus)
    dw RoomMap0
    dw RoomMap1
    dw RoomMap2
    dw RoomMap3
    dw RoomMap4
    dw RoomMap5
    dw RoomMap6
    dw RoomMap7
    dw RoomMap8
    dw RoomMap9
    dw RoomMap10
    dw RoomMap3
    dw RoomMap12
    dw RoomMap13
    dw RoomMap14
    dw RoomMap7
    dw RoomMap16
CursorBlinkStep::  ; counts $c47d to $50 and toggles the cursor animation between D_00_1a17 and D_00_1a30
    ld a, [wMagicScreenFlags]
    bit 2, a
    ret z
    ld a, [wCursorBlink]
    cp a, $50
    jr nc, ResetMagicCursorAnimation
    inc a
    ld [wCursorBlink], a
    ld a, [$c769]
    and a, $04
    jr nz, SetCursorDefaultAnimation
    ld hl, D_00_1a17
    jr SetCursorAnimation
SetCursorDefaultAnimation::  ; cursor object animation = D_00_1a30
    ld hl, D_00_1a30
SetCursorAnimation::  ; HL = animation pointer stored in the cursor object record ($c74f/$c750 = wCursorObject +1/+2)
    ld a, l
    ld [$c74f], a
    ld a, h
    ld [$c750], a
    ret
ResetMagicCursorAnimation::  ; clears wMagicScreenFlags bit 2 and sets the default cursor animation
    ld hl, wMagicScreenFlags
    res 2, [hl]
    jr SetCursorDefaultAnimation
MagicScreenInput::  ; D-pad moves the card cursor (sound SND_SFX_CURSOR); A or B closes or casts; uses $c53b flags
    ld a, [wMagicScreenFlags]
    bit 1, a
    jr nz, .L_00_17a9
    ldh a, [hJoyNew]
    and a, $f1
    jr z, .L_00_179c
    bit 0, a
    jr nz, .L_00_17b2
    ld a, SND_SFX_CURSOR
    call PlaySound
    ldh a, [hJoyNew]
    bit 4, a
    call nz, MagicCursorRight
    bit 5, a
    call nz, MagicCursorLeft
    bit 6, a
    call nz, MagicCursorUp
    bit 7, a
    call nz, MagicCursorDown
.L_00_179c:
    ld a, [wMagicCol]
    ld c, a
    ld hl, D_00_2630
    call LookupByte
    ld [wCursorX], a
.L_00_17a9:
    ld hl, wCursorObject
    call SetObjPtr
    jp DrawObjectBytePos
.L_00_17b2:
    ld a, [wMagicRow]
    ld e, $03
    call MultiplyByDE
    ldh a, [hScratch00]
    ld d, a
    ld a, [wMagicCol]
    add a, d
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    ld c, a
    ld b, $00
    ld hl, MagicCostTable
    add hl, bc
    ld d, [hl]
    ld a, [wMagicPoints]
    cp a, d
    jr nc, .L_00_17e2
    ld a, [wMagicPointsHi]
    and a, a
    jr nz, .L_00_17e2
    ld hl, wMagicScreenFlags
    res 2, [hl]
    ret
.L_00_17e2:
    ld a, SND_SFX_90
    call PlaySound
    ld a, [wMagicRow]
    ld e, $03
    call MultiplyByDE
    ldh a, [hScratch00]
    ld d, a
    ld a, [wMagicCol]
    add a, d
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    ld [wActiveMagic], a
    ld a, [wMagicScreenFlags]
    or a, $06
    ld [wMagicScreenFlags], a
    ld hl, hJoyNew
    res 7, [hl]
    jr .L_00_179c
MagicCursorRight::  ; moves the magic card cursor one column right (wraps to the next row)
    ld a, [wMagicCol]
    cp a, $02
    jr z, .L_00_1834
    ld a, [wMagicRow]
    ld e, $03
    call MultiplyByDE
    ldh a, [hScratch00]
    ld e, a
    ld a, [wMagicCol]
    inc a
    add a, e
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    or a, a
    ret z
    ld hl, wMagicCol
    inc [hl]
    ret
.L_00_1834:
    xor a, a
    ld [wMagicCol], a
    ret
MagicCursorLeft::  ; moves the magic card cursor one column left
    ld a, [wMagicCol]
    or a, a
    jr z, .L_00_1844
    ld hl, wMagicCol
    dec [hl]
    ret
.L_00_1844:
    ld a, [wMagicRow]
    ld e, $03
    call MultiplyByDE
    ldh a, [hScratch00]
    add a, $02
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    or a, a
    ret z
    ld a, $02
    ld [wMagicCol], a
    ret
MagicCursorUp::  ; moves the magic card cursor one row up
    ld a, [wMagicRow]
    or a, a
    jr z, .L_00_1871
    ld hl, wMagicRow
    dec [hl]
    ld a, [hl]
    ld e, $03
    call MultiplyByDE
    jr DrawMagicPage
.L_00_1871:
    xor a, a
    ld [wMagicRow], a
    ret
MagicCursorDown::  ; moves the magic card cursor one row down
    ld a, [wMagicRow]
    cp a, $02
    jp z, SetMagicRowAndReturn
    ld a, [wMagicRow]
    inc a
    ld e, $03
    call MultiplyByDE
    ldh a, [hScratch00]
    ld d, a
    ld a, [wMagicCol]
    add a, d
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    or a, a
    ret z
    ld hl, wMagicRow
    inc [hl]
    ld a, [wMagicRow]
    ld e, $03
    call MultiplyByDE
DrawMagicPage::  ; draws the three cards of the current row (name
    ldh a, [hScratch00]
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    ldh [hScratch02], a
    ld hl, MagicCardTitleJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d02
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardPictureJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d42
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardCostJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9de2
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch00]
    inc a
    ldh [hScratch00], a
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    ldh [hScratch02], a
    ld hl, MagicCardTitleJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d08
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardPictureJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d48
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardCostJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9de8
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch00]
    inc a
    ldh [hScratch00], a
    ld c, a
    ld hl, wMagicCards
    call LookupByte
    ldh [hScratch02], a
    ld hl, MagicCardTitleJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d0e
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardPictureJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9d4e
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [hScratch02]
    ld hl, MagicCardCostJobs
    call LookupWord
    push hl
    pop de
    ld hl, $9dee
    call QueueVramCopyRows
    jp WaitVramCopyDone
SetMagicRowAndReturn::  ; stores A in wMagicRow (tail of a cursor move; name provisional)
    ld [wMagicRow], a
    ret
InitMagicScreenState::  ; clears the cursor and card variables and creates the cursor object at wCursorObject
    xor a, a
    ld [wMagicCol], a
    ld [wMagicRow], a
    ld [wCursorBlink], a
    ld [wMagicScreenFlags], a
    ld hl, wCursorObject
    call Clear32Bytes
    ld a, $a0
    ld [wCursorObject], a
    ld a, $28
    ld [wCursorX], a
    ld a, $68
    ld [wCursorY], a
    ld hl, D_00_1a30
    jp SetCursorAnimation
MagicCostTable::  ; MP cost per card id (bytes: 0 10 50 40 90 60 30 80 70 20)
    INCBIN "assets/bank_00/199b_MagicCostTable.bin"
MagicCardTitleJobs::  ; 10 pointers to the card name VRAM jobs (index = card id)
    dw MagicTitleJob0
    dw MagicTitleJob1
    dw MagicTitleJob2
    dw MagicTitleJob3
    dw MagicTitleJob4
    dw MagicTitleJob5
    dw MagicTitleJob6
    dw MagicTitleJob7
    dw MagicTitleJob8
    dw MagicTitleJob9
MagicCardPictureJobs::  ; 10 pointers to the card picture VRAM jobs
    dw MagicPictureJob0
    dw MagicPictureJob1
    dw MagicPictureJob2
    dw MagicPictureJob3
    dw MagicPictureJob4
    dw MagicPictureJob5
    dw MagicPictureJob6
    dw MagicPictureJob7
    dw MagicPictureJob8
    dw MagicPictureJob9
MagicCardCostJobs::  ; 10 pointers to the MP cost VRAM jobs
    dw MagicTitleJob0
    dw MagicCostJob1
    dw MagicCostJob2
    dw MagicCostJob3
    dw MagicCostJob4
    dw MagicCostJob5
    dw MagicCostJob6
    dw MagicCostJob7
    dw MagicCostJob8
    dw MagicCostJob9
MagicCostJob1::  ; data (table entry)
    INCBIN "assets/bank_00/19e1_MagicCostJob1.bin"
MagicCostJob2::  ; data (table entry)
    INCBIN "assets/bank_00/19e7_MagicCostJob2.bin"
MagicCostJob3::  ; data (table entry)
    INCBIN "assets/bank_00/19ed_MagicCostJob3.bin"
MagicCostJob4::  ; data (table entry)
    INCBIN "assets/bank_00/19f3_MagicCostJob4.bin"
MagicCostJob5::  ; data (table entry)
    INCBIN "assets/bank_00/19f9_MagicCostJob5.bin"
MagicCostJob6::  ; data (table entry)
    INCBIN "assets/bank_00/19ff_MagicCostJob6.bin"
MagicCostJob7::  ; data (table entry)
    INCBIN "assets/bank_00/1a05_MagicCostJob7.bin"
MagicCostJob8::  ; data (table entry)
    INCBIN "assets/bank_00/1a0b_MagicCostJob8.bin"
MagicCostJob9::  ; data (table entry)
    INCBIN "assets/bank_00/1a11_MagicCostJob9.bin"
D_00_1a17::
    INCBIN "assets/bank_00/1a17.bin"
D_00_1a30::
    INCBIN "assets/bank_00/1a30.bin"
D_00_1a57::
    INCBIN "assets/bank_00/1a57.bin"
D_00_1a94::
    INCBIN "assets/bank_00/1a94.bin"
MagicPictureJob0::  ; data (table entry)
    INCBIN "assets/bank_00/1b67_MagicPictureJob0.bin"
MagicPictureJob7::  ; data (table entry)
    INCBIN "assets/bank_00/1b79_MagicPictureJob7.bin"
MagicPictureJob3::  ; data (table entry)
    INCBIN "assets/bank_00/1b8b_MagicPictureJob3.bin"
MagicPictureJob1::  ; data (table entry)
    INCBIN "assets/bank_00/1b9d_MagicPictureJob1.bin"
MagicPictureJob6::  ; data (table entry)
    INCBIN "assets/bank_00/1baf_MagicPictureJob6.bin"
MagicPictureJob2::  ; data (table entry)
    INCBIN "assets/bank_00/1bc1_MagicPictureJob2.bin"
MagicPictureJob9::  ; data (table entry)
    INCBIN "assets/bank_00/1bd3_MagicPictureJob9.bin"
MagicPictureJob5::  ; data (table entry)
    INCBIN "assets/bank_00/1be5_MagicPictureJob5.bin"
MagicPictureJob8::  ; data (table entry)
    INCBIN "assets/bank_00/1bf7_MagicPictureJob8.bin"
MagicPictureJob4::  ; data (table entry)
    INCBIN "assets/bank_00/1c09_MagicPictureJob4.bin"
MagicTitleJob0::  ; data (table entry)
    INCBIN "assets/bank_00/1c1b_MagicTitleJob0.bin"
MagicTitleJob1::  ; data (table entry)
    INCBIN "assets/bank_00/1c21_MagicTitleJob1.bin"
MagicTitleJob2::  ; data (table entry)
    INCBIN "assets/bank_00/1c27_MagicTitleJob2.bin"
MagicTitleJob3::  ; data (table entry)
    INCBIN "assets/bank_00/1c2d_MagicTitleJob3.bin"
MagicTitleJob4::  ; data (table entry)
    INCBIN "assets/bank_00/1c33_MagicTitleJob4.bin"
MagicTitleJob6::  ; data (table entry)
    INCBIN "assets/bank_00/1c39_MagicTitleJob6.bin"
MagicTitleJob5::  ; data (table entry)
    INCBIN "assets/bank_00/1c3f_MagicTitleJob5.bin"
MagicTitleJob9::  ; data (table entry)
    INCBIN "assets/bank_00/1c45_MagicTitleJob9.bin"
MagicTitleJob7::  ; data (table entry)
    INCBIN "assets/bank_00/1c4b_MagicTitleJob7.bin"
MagicTitleJob8::  ; data (table entry)
    INCBIN "assets/bank_00/1c51_MagicTitleJob8.bin"
Mode3_RoundIntro::  ; ROUND nn / room name / lives / READY !!
    ld sp, wStackTop
    call LcdOff
    di
    ld a, $ff
    call PlaySound
    ld hl, vBGMapLast
    call FillBackwardsFF
    xor a, a
    ld [$c7c2], a
    call LoadTilesBank3A
    call ClearOamShadow
    ld bc, D_00_1d90
    call RunVramCopyList
    ld a, [wRound]
    ld b, a
    ld hl, $986c
    call DrawTwoDigitNumber
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_00_1c8d
    ld b, $01
    jr .L_00_1c91
.L_00_1c8d:
    ld a, [wLives]
    ld b, a
.L_00_1c91:
    ld hl, $992c
    call DrawTwoDigitNumber
    ld a, [wRound]
    ld hl, RoomNameJobTable
    call TableIndexFromRoundDec
    ld hl, $98c3
    call VramCopyStream
    call RequestOamDma
    call ClearOamShadowY
    call ClearRoomState
    call ClearBonusFlags
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ld a, $97
    ldh [hScratch00], a
.L_00_1cd6:
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, hScratch00
    dec [hl]
    jr nz, .L_00_1cd6
    ld a, $01
    jp GameModeDispatch
ClearRoomState::  ; zeroes wActiveMagic wMagicState and the room script variables
    xor a, a
    ld [wActiveMagic], a
    ld [wMagicState], a
    ld [wEnemyCount], a
    ld [wWaveEnded], a
    ld [wSpawnWave], a
    ld a, $01
    ld [wSpawnIndex], a
    ret
DrawTwoDigitNumber::  ; B = value drawn as two BCD digits at HL
    ld a, $02
    ldh [hScratch0A], a
    ld a, $01
    ldh [hScratch0B], a
    ld a, b
    call ByteToBCD
    ldh [hScratch00], a
    and a, $f0
    swap a
    call DigitToTile
    ldh [hScratch0C], a
    ldh a, [hScratch00]
    and a, $0f
    call DigitToTile
    ldh [hScratch0D], a
    ld de, hScratch0A
    jp VramCopyStream
DigitToTile::  ; A = BCD digit; returns the digit tile id from D_00_1d2f
    push hl
    push bc
    ld c, a
    ld hl, D_00_1d2f
    call LookupByte
    pop bc
    pop hl
    ret
D_00_1d2f::
    INCBIN "assets/bank_00/1d2f.bin"
RoomNameJobTable::  ; 17 pointers to the room name VRAM jobs
    dw RoomNameJob0
    dw RoomNameJob0
    dw RoomNameJob0
    dw RoomNameJob3
    dw RoomNameJob4
    dw RoomNameJob4
    dw RoomNameJob4
    dw RoomNameJob3
    dw RoomNameJob8
    dw RoomNameJob8
    dw RoomNameJob8
    dw RoomNameJob3
    dw RoomNameJob12
    dw RoomNameJob12
    dw RoomNameJob12
    dw RoomNameJob3
    dw RoomNameJob16
RoomNameJob0::  ; data (table entry)
    INCBIN "assets/bank_00/1d5b_RoomNameJob0.bin"
RoomNameJob4::  ; data (table entry)
    INCBIN "assets/bank_00/1d64_RoomNameJob4.bin"
RoomNameJob8::  ; data (table entry)
    INCBIN "assets/bank_00/1d6c_RoomNameJob8.bin"
RoomNameJob12::  ; data (table entry)
    INCBIN "assets/bank_00/1d75_RoomNameJob12.bin"
RoomNameJob3::  ; data (table entry)
    INCBIN "assets/bank_00/1d7e_RoomNameJob3.bin"
RoomNameJob16::  ; data (table entry)
    INCBIN "assets/bank_00/1d87_RoomNameJob16.bin"
D_00_1d90::
    INCBIN "assets/bank_00/1d90.bin"
Mode7_LinkLose::  ; SORRY YOU LOSE / TRY AGAIN (2 player loser)
    ld sp, wStackTop
    call LcdOff
    di
    ld hl, $9fff
    call FillBackwardsFF
    ld a, $ff
    call PlaySound
    call LoadTilesBank3C
    call ClearOamShadow
    ldh a, [hSerialByte]
    bit 6, a
    jr nz, .L_00_1de6
    ld bc, D_00_1e2e
    call RunVramCopyList
    jr .L_00_1dec
.L_00_1de6:
    ld bc, D_00_1e57
    call RunVramCopyList
.L_00_1dec:
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, $9b
    ld [rLCDC], a
    ei
    ld a, $ff
    ldh [hScratch00], a
.L_00_1e12:
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, hScratch00
    dec [hl]
    jr nz, .L_00_1e12
    ld a, [wContinues]
    and a, a
    jr z, .L_00_1e29
    ld a, $05
    jp GameModeDispatch
.L_00_1e29:
    ld a, $04
    jp GameModeDispatch
D_00_1e2e::
    INCBIN "assets/bank_00/1e2e.bin"
D_00_1e57::
    INCBIN "assets/bank_00/1e57.bin"
Mode4_GameOver::  ; GAME OVER screen
    ld sp, wStackTop
    call LcdOff
    di
    ld hl, vBGMapLast
    call FillBackwardsFF
    call LoadTilesBank3A
    call ClearOamShadow
    ld a, SND_MUSIC_GAME_OVER
    call PlaySound
    ld hl, $9905
    ld de, D_00_1f10
    call VramCopyStream
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ld hl, wRoundFlags
    res 0, [hl]
    ld hl, wGameFlags
    res 2, [hl]
    ld a, $ff
    ldh [hScratch00], a
    ld a, $02
    ldh [hScratch01], a
.L_00_1eee:
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, hScratch00
    dec [hl]
    jr nz, .L_00_1eee
    ldh a, [hScratch01]
    dec a
    ldh [hScratch01], a
    bit 7, a
    jr z, .L_00_1eee
    ldh a, [hLinkFlags]
    bit 0, a
    jr nz, .L_00_1f0d
    xor a, a
    jp GameModeDispatch
.L_00_1f0d:
    jp Entry
D_00_1f10::
    INCBIN "assets/bank_00/1f10.bin"
Mode5_Continue::  ; CONTINUE? countdown with YES/NO
    ld sp, wStackTop
    call LcdOff
    di
    ld hl, vBGMapLast
    call FillBackwardsFF
    ld hl, wCursorObject
    call Clear32Bytes
    call LoadTilesBank3A
    call ClearOamShadow
    ld bc, D_00_2085
    call RunVramCopyList
    ld hl, D_00_2083
    call SetCursorAnimation
    ld a, $3c
    ld [wCursorX], a
    ld a, $50
    ld [wCursorY], a
    ld a, $80
    ld [wCursorObject], a
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld [wMagicCol], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, [wCheatFlags]
    bit 0, a
    jr z, .L_00_1f82
    ld a, $ff
    ld [wContinues], a
    ld a, $02
    ld [wTextBuf], a
    ld a, $01
    ld [$c44d], a
    ld a, $cd
    ld [$c44e], a
    ld a, $ce
    ld [$c44f], a
    jr .L_00_1f93
.L_00_1f82:
    ld a, $01
    ld [wTextBuf], a
    ld [$c44d], a
    ld a, [wContinues]
    call NumberToTile
    ld [$c44e], a
.L_00_1f93:
    ld de, wTextBuf
    ld hl, $98a9
    call VramCopyStream
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $ee
    ld [rSB], a
    call SerialStartTransfer
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ld a, $f0
    ld [wPlayerBlocked], a
.L_00_1fc2:
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 4, a
    jp nz, .L_00_2050
    ldh a, [hLinkFlags]
    bit 3, a
    jr nz, .L_00_2024
    call ReadJoypad
    call ContinueCursorInput
    ld hl, wCursorObject
    call SetObjPtr
    call DrawObjectBytePos
    ld hl, wPlayerBlocked
    dec [hl]
    jp z, Entry
    ldh a, [hJoyNew]
    bit 0, a
    jr z, .L_00_1fc2
    ld a, [wMagicCol]
    and a, a
    jr z, .L_00_2029
    xor a, a
    ld [wRoomIndex], a
    ld a, $01
    ld [wRound], a
    ld [wRoundBackup], a
    ld hl, wMagicCards
    ld bc, $0008
    call ClearMemory
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_00_2014
    ld c, $10
    call SerialSendByte
.L_00_2014:
    ld a, [wCheatFlags]
    bit 0, a
    jr z, .L_00_201f
    ld a, $ff
    jr .L_00_2021
.L_00_201f:
    ld a, $05
.L_00_2021:
    ld [wContinues], a
.L_00_2024:
    ld a, $04
    jp GameModeDispatch
.L_00_2029:
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_00_2042
    call PickRandomRound
    ld a, [rSC]
    bit 7, a
    jr z, .L_00_2050
    ld a, [wRound]
    or a, $80
    ld c, a
    call SerialSendByte
.L_00_2042:
    ld hl, wRoundFlags
    res 2, [hl]
    ld hl, wContinues
    dec [hl]
    ld a, $03
    jp GameModeDispatch
.L_00_2050:
    xor a, a
    ld [rSB], a
    ldh [hSerialByte], a
    ld a, [wRemoteRound]
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr .L_00_2042
ContinueCursorInput::  ; A or B moves the YES/NO cursor (wCursorX $3c or $74) in the continue mode
    ldh a, [hJoyNew]
    and a, $30
    ret z
    bit 4, a
    jr nz, .L_00_2078
    ld a, $3c
    ld [wCursorX], a
    xor a, a
    ld [wMagicCol], a
    ret
.L_00_2078:
    ld a, $74
    ld [wCursorX], a
    ld a, $01
    ld [wMagicCol], a
    ret
D_00_2083::
    INCBIN "assets/bank_00/2083.bin"
D_00_2085::
    INCBIN "assets/bank_00/2085.bin"
RoomMetatiles0::  ; data (table entry)
    INCBIN "assets/bank_00/20a7_RoomMetatiles0.bin"
RoomMetatiles8::  ; data (table entry)
    INCBIN "assets/bank_00/20b7_RoomMetatiles8.bin"
RoomMetatiles12::  ; data (table entry)
    INCBIN "assets/bank_00/20c7_RoomMetatiles12.bin"
RoomMap0::  ; data (table entry)
    INCBIN "assets/bank_00/20d7_RoomMap0.bin"
RoomMap1::  ; data (table entry)
    INCBIN "assets/bank_00/2117_RoomMap1.bin"
RoomMap2::  ; data (table entry)
    INCBIN "assets/bank_00/2157_RoomMap2.bin"
RoomMap3::  ; data (table entry)
    INCBIN "assets/bank_00/2197_RoomMap3.bin"
RoomMap4::  ; data (table entry)
    INCBIN "assets/bank_00/21d7_RoomMap4.bin"
RoomMap5::  ; data (table entry)
    INCBIN "assets/bank_00/2217_RoomMap5.bin"
RoomMap6::  ; data (table entry)
    INCBIN "assets/bank_00/2257_RoomMap6.bin"
RoomMap7::  ; data (table entry)
    INCBIN "assets/bank_00/2297_RoomMap7.bin"
RoomMap8::  ; data (table entry)
    INCBIN "assets/bank_00/22d7_RoomMap8.bin"
RoomMap9::  ; data (table entry)
    INCBIN "assets/bank_00/2317_RoomMap9.bin"
RoomMap10::  ; data (table entry)
    INCBIN "assets/bank_00/2357_RoomMap10.bin"
RoomMap12::  ; data (table entry)
    INCBIN "assets/bank_00/2397_RoomMap12.bin"
RoomMap13::  ; data (table entry)
    INCBIN "assets/bank_00/23d7_RoomMap13.bin"
RoomMap14::  ; data (table entry)
    INCBIN "assets/bank_00/2417_RoomMap14.bin"
RoomMap16::  ; data (table entry)
    INCBIN "assets/bank_00/2457_RoomMap16.bin"
Mode2_BonusSelect::  ; SELECT JUST ONE! choose A/B/C
    ld sp, wStackTop
    ld hl, $c487
    inc [hl]
    xor a, a
    ld [wPlayerBlocked], a
    ld a, SND_MUSIC_BONUS_SELECT
    call PlaySound
    call LcdOff
    di
    call LoadTilesBank3C
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    call InitBonusCursor
Mode2_Init::  ; bonus select setup after LcdOff
    call LcdOff
    di
    ld a, [wPlayerBlocked]
    ld hl, BonusSelectJobTable
    call LookupWord
    push hl
    pop de
    ld bc, D_00_270f
    ld hl, vBGMap0
    ld a, $ff
    ld [wMapCellMask], a
    call DrawBonusMetatileMap
    ld bc, D_00_29b1
    call RunVramCopyList
    ld a, [wPlayerBlocked]
    and a, a
    jr nz, .L_00_24e9
    ld de, D_00_264a
    ld hl, $988c
    call VramCopyStream
.L_00_24e9:
    cp a, $02
    jr nz, .L_00_250f
    ld a, [wBonusChoice]
    ld hl, D_00_269b
    call LookupWord
    push hl
    pop de
    ld hl, $9886
    call VramCopyStream
    ld a, [wBonusChoice]
    ld hl, D_00_2651
    call LookupWord
    push hl
    pop de
    ld hl, $98c9
    call VramCopyStream
.L_00_250f:
    call RequestOamDma
    call ClearOamShadow
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, IE_VBLANK
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ld a, [wPlayerBlocked]
    ld hl, BonusModeJumpTable
    call LookupWord
    jp hl
BonusModeJumpTable::  ; 3 entry points chosen by wPlayerBlocked: intro wait then Mode2_Init; BonusSelectLoop; BonusResultWait
    dw BonusIntroWait
    dw BonusSelectLoop
    dw BonusResultWait
BonusIntroWait::  ; waits $d0 frames then wPlayerBlocked++ and jumps to Mode2_Init (name provisional)
    ld a, $d0
    ldh [hScratch00], a
.L_00_2545:
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, hScratch00
    dec [hl]
    jr nz, .L_00_2545
    ld hl, wPlayerBlocked
    inc [hl]
    jp Mode2_Init
BonusResultWait::  ; waits $e0 frames after the door result then goes to mode 3
    ld d, $01
    ld e, $00
    call AddScore
    ld a, $e0
    ldh [hScratch00], a
.L_00_2563:
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, hScratch00
    dec [hl]
    jr nz, .L_00_2563
    ld a, $03
    jp GameModeDispatch
BonusSelectLoop::  ; per-frame loop of the three-door choice: cursor input
    ld a, $10
    call DelayFrames
    ld hl, wPlayerBlocked
    inc [hl]
.L_00_257d:
    call WaitFrameAndSyncOam
    call ReadJoypad
    call MenuCursorInput
    ld a, [wCursorFlags]
    bit 7, a
    jr z, .L_00_257d
    ld a, [$c487]
    ld e, $03
    call MultiplyByDE
    ld c, a
    ld b, $00
    ld hl, D_00_25cb
    add hl, bc
    ldh a, [hFrameSpin]
    cp a, $7f
    jr c, .L_00_25a8
    inc hl
    cp a, $cd
    jr c, .L_00_25a8
    inc hl
.L_00_25a8:
    ld a, [hl]
    ldh [hScratch00], a
    ld hl, wMagicCards
.L_00_25ae:
    ld a, [hl]
    and a, a
    jr z, .L_00_25bc
    ld c, a
    ldh a, [hScratch00]
    cp a, c
    jp z, .L_00_25c5
    inc hl
    jr .L_00_25ae
.L_00_25bc:
    ldh a, [hScratch00]
    ld [hl], a
    ld [wBonusChoice], a
    jp Mode2_Init
.L_00_25c5:
    ld [wBonusChoice], a
    jp Mode2_Init
D_00_25cb::
    INCBIN "assets/bank_00/25cb.bin"
MenuCursorInput::  ; dpad changes the cursor ($c758 wraps 0-2) with sound $8f
    ldh a, [hJoyNew]
    bit 5, a
    jr z, .L_00_25f8
    ld a, SND_SFX_CURSOR
    call PlaySound
    ld a, [wCursorIndex]
    dec a
    bit 7, a
    jr z, .L_00_25f5
    ld a, $02
.L_00_25f5:
    ld [wCursorIndex], a
.L_00_25f8:
    ldh a, [hJoyNew]
    bit 4, a
    jr z, .L_00_260f
    ld a, SND_SFX_CURSOR
    call PlaySound
    ld a, [wCursorIndex]
    inc a
    cp a, $03
    jr c, .L_00_260c
    xor a, a
.L_00_260c:
    ld [wCursorIndex], a
.L_00_260f:
    ldh a, [hJoyNew]
    bit 0, a
    jr z, .L_00_261a
    ld hl, wCursorFlags
    set 7, [hl]
.L_00_261a:
    ld a, [wCursorIndex]
    ld c, a
    ld hl, D_00_2630
    call LookupByte
    ld [wCursorX], a
    ld hl, wCursorObject
    call SetObjPtr
    jp DrawObjectBytePos
D_00_2630::
    INCBIN "assets/bank_00/2630.bin"
InitBonusCursor::  ; resets the door selection cursor (wCursorIndex 0; cursor object at $80/$50)
    xor a, a
    ld [wCursorIndex], a
    ld [wCursorFlags], a
    ld a, $50
    ld [wCursorY], a
    ld a, $80
    ld [wCursorObject], a
    ld hl, D_00_2704
    jp SetCursorAnimation
D_00_264a::
    INCBIN "assets/bank_00/264a.bin"
D_00_2651::
    INCBIN "assets/bank_00/2651.bin"
D_00_269b::
    INCBIN "assets/bank_00/269b.bin"
D_00_2704::
    INCBIN "assets/bank_00/2704.bin"
BonusSelectJobTable::  ; 3 pointers to VRAM job lists
    dw BonusSelectJob0
    dw BonusSelectJob1
    dw BonusSelectJob2
D_00_270f::
    INCBIN "assets/bank_00/270f.bin"
BonusSelectJob0::  ; data (table entry)
    INCBIN "assets/bank_00/28a3_BonusSelectJob0.bin"
BonusSelectJob1::  ; data (table entry)
    INCBIN "assets/bank_00/28fd_BonusSelectJob1.bin"
BonusSelectJob2::  ; data (table entry)
    INCBIN "assets/bank_00/2957_BonusSelectJob2.bin"
D_00_29b1::
    INCBIN "assets/bank_00/29b1.bin"
Mode0_Title::  ; title screen: 1 PLAYER / 2 PLAYER; link-cable detection via the serial port
    ld sp, wStackTop
    call LcdOff
    di
    call LoadTilesBank3A
    ld a, SND_MUSIC_TITLE
    call PlaySound
    ld hl, vBGMapLast
    call FillBackwardsFF
    ld bc, D_00_2b86
    call RunVramCopyList
    call RequestOamDma
    ld hl, wCursorObject
    call Clear32Bytes
    call InitTitleVariables
    ld a, $ee
    ld [rSB], a
    call SerialStartTransfer
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK_SERIAL
    ldh [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
TitleLoop::  ; title screen loop: serial check; joypad; button codes; Start sends the round over the link port
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 4, a
    jp nz, .L_00_2ac4
    call ReadJoypad
    ldh a, [hJoyHeld]
    cp a, $93
    jr nz, .L_00_2a3f
    ld a, $06
    jp GameModeDispatch
.L_00_2a3f:
    cp a, $47
    jr nz, .L_00_2a48
    ld hl, wCheatFlags
    set 0, [hl]
.L_00_2a48:
    call TitleCursorUpdate
    ld a, [wCheatFlags]
    bit 5, a
    jr z, .L_00_2a61
    ld hl, wCheatTimer
    dec [hl]
    ld a, [wCheatTimer]
    and a, a
    jr nz, .L_00_2ad8
    ld hl, wCheatFlags
    res 5, [hl]
.L_00_2a61:
    ldh a, [hJoyNew]
    cp a, $08
    jr nz, TitleLoop
    ld a, [wCursorY]
    cp a, $64
    jr z, .L_00_2ae7
    call PickRandomRound
    ld a, [wRound]
    or a, $80
    ld c, a
    call SerialSendByte
    ld a, [rSB]
    cp a, $ee
    jr z, .L_00_2a8b
    cp a, $ff
    jr z, .L_00_2a94
    cp a, $88
    jr z, .L_00_2a9b
    jr .L_00_2abc
.L_00_2a8b:
    ld hl, wCheatFlags
    res 1, [hl]
    res 5, [hl]
    jr .L_00_2aa5
.L_00_2a94:
    ld hl, wCheatFlags
    set 1, [hl]
    jr .L_00_2aa5
.L_00_2a9b:
    ld a, $a0
    ld [wCheatTimer], a
    ld hl, wCheatFlags
    set 5, [hl]
.L_00_2aa5:
    ld a, [wCheatFlags]
    bit 1, a
    jp nz, .L_00_2abc
    bit 5, a
    jp nz, .L_00_2abc
    ld hl, hLinkFlags
    set 0, [hl]
.L_00_2ab7:
    ld a, $03
    jp GameModeDispatch
.L_00_2abc:
    ld a, $64
    ld [wCursorY], a
    jp TitleLoop
.L_00_2ac4:
    ld hl, hLinkFlags
    set 0, [hl]
    ld a, [wRemoteRound]
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr .L_00_2ab7
.L_00_2ad8:
    ld a, [wCursorY]
    cp a, $64
    jp nz, TitleLoop
    ldh a, [hJoyNew]
    cp a, $08
    jp nz, TitleLoop
.L_00_2ae7:
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    ld a, $88
    ld [rSB], a
    call SerialStartTransfer
    ld hl, wCheatFlags
    set 3, [hl]
    ld a, $01
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr .L_00_2ab7
PickRandomRound::  ; title button code path: chooses wRound from hRngCounter (value $1f selects round $1e)
    call NextRandomDirection
    ldh a, [hRngCounter]
    and a, $1f
    jr z, PickRandomRound
    cp a, $1f
    jr nz, .L_00_2b18
    dec a
.L_00_2b18:
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    ret
TitleCursorUpdate::  ; Select toggles wCursorY between $64 (1 PLAYER) and $74 (2 PLAYER); draws the cursor object
    ldh a, [hJoyNew]
    cp a, $04
    jr nz, .L_00_2b2b
    jr .L_00_2b34
.L_00_2b2b:
    ld hl, wCursorObject
    call SetObjPtr
    jp DrawObjectBytePos
.L_00_2b34:
    ld a, [wCursorY]
    cp a, $64
    jr z, .L_00_2b3f
    ld a, $64
    jr .L_00_2b41
.L_00_2b3f:
    ld a, $74
.L_00_2b41:
    ld [wCursorY], a
    jr .L_00_2b2b
InitTitleVariables::  ; clears hLinkFlags and the variables used by the title screen
    xor a, a
    ldh [hLinkFlags], a
    ld [wCheatFlags], a
    ld [wMagicCards], a
    ld [$c43f], a
    ld [$c440], a
    ld [$c441], a
    ld [$c442], a
    ld [$c443], a
    ld [$c444], a
    ld [$c445], a
    ld [$c446], a
    ld [$c487], a
    ld a, $05
    ld [wContinues], a
    ld a, $34
    ld [wCursorX], a
    ld a, $64
    ld [wCursorY], a
    ld a, $80
    ld [wCursorObject], a
    ld hl, AnimFrames0_2b84
    jp SetCursorAnimation
AnimFrames0_2b84::  ; animation frames (typed text form)
    INCBIN "assets/bank_00/2b84_AnimFrames0_2b84.bin"
D_00_2b86::
    INCBIN "assets/bank_00/2b86.bin"
Mode6_Ending::  ; castle scene after the last round
    ld sp, wStackTop
    call LcdOff
    di
    call LoadTilesBank3D
    ld hl, vBGMapLast
    call FillBackwardsFF
    ld hl, $9fff
    call FillBackwardsFF
    call ClearOamShadowY
    call RequestOamDma
    ld a, $06
    ldh [hScratch01], a
    ld a, $0a
    ldh [hScratch00], a
    ld hl, $98c0
    ld bc, D_00_3156
    ld de, D_00_31a6
    ld a, $ff
    ld [wMapCellMask], a
    call DrawMetatileMap
    ld hl, wEndingObject
    ld bc, $0041
    call ClearMemory
    ld a, $80
    ld [wEndingObject], a
    ld [wEndingObject2], a
    ld hl, D_00_3143
    ld a, h
    ld [$c770], a
    ld a, l
    ld [$c76f], a
    ld a, $80
    ld [wEndingX], a
    ld a, $68
    ld [wEndingY], a
    ld a, $04
    ld [wEndingSpeed], a
    ld a, $18
    ld [wEndingAngle], a
    ld a, $70
    ld [wEnding2X], a
    ld a, $68
    ld [wEnding2Y], a
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK
    ld [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    call EndingCastleBlink
    call EndingWalkStep
    ld a, SND_MUSIC_ENDING
    call PlaySound
    ld a, $46
    call DelayFrames
    call EndingCastleBlink
    call EndingWalkStep
.L_00_2d16:
    call WaitFrameAndSyncOam
    call EndingCastleBlink
    call EndingWalkStep
    ld a, [wEndingEvents]
    bit 7, a
    jr z, .L_00_2d16
    call EndingSetup
    ld a, $10
    ld [wCheatFlags], a
    ld a, $05
    ld [wCheatTimer], a
.L_00_2d33:
    call WaitFrameAndSyncOam
    call EndingScrollStep
    call EndingTick
    call EndingCreditsWindow
    call ReadJoypad
    ld a, [wCreditsPage]
    cp a, $08
    jr nz, .L_00_2d33
    ld hl, wCheatFlags
    dec [hl]
    jr nz, .L_00_2d33
    ld a, [wCheatTimer]
    dec a
    ld [wCheatTimer], a
    bit 7, a
    jr z, .L_00_2d33
    jp Entry
EndingCreditsWindow::  ; when the scene is done: turns the window on (rWY/rWX) and starts the credit pages
    ld a, [wEndingEvents]
    bit 2, a
    ret z
    ld a, [wEndingObject2]
    bit 0, a
    jr nz, .L_00_2d89
    ld a, $5a
    ld [rWY], a
    ld a, $a5
    ld [rWX], a
    ld a, [rLCDC]
    or a, $60
    ld [rLCDC], a
    ld hl, wEndingObject2
    set 0, [hl]
    ld a, $ff
    ld [wEndingObject2Anim], a
    call EndingShowCreditsPage
.L_00_2d89:
    ld a, [wEndingObject2]
    bit 2, a
    jr nz, .L_00_2dc1
    ld a, [wEndingObject2]
    bit 1, a
    jr nz, .L_00_2da9
    ld hl, rWX
    dec [hl]
    dec [hl]
    dec [hl]
    dec [hl]
    dec [hl]
    ld a, [hl]
    cp a, $0a
    ret nz
    ld hl, wEndingObject2
    set 1, [hl]
    ret
.L_00_2da9:
    ld a, [wCreditsPage]
    cp a, $08
    ret z
    ld hl, wEndingObject2Anim
    dec [hl]
    ret nz
    ld a, $ff
    ld [wEndingObject2Anim], a
    ld hl, wEndingObject2
    res 1, [hl]
    set 2, [hl]
    ret
.L_00_2dc1:
    ld hl, rWX
    inc [hl]
    inc [hl]
    inc [hl]
    inc [hl]
    inc [hl]
    ld a, [hl]
    cp a, $a5
    ret nz
    xor a, a
    ld [wEndingObject2], a
    ld hl, wCreditsPage
    inc [hl]
    call EndingShowCreditsPage
    ret
EndingShowCreditsPage::  ; queues the credit page $c790 from CreditsPageTable
    call EndingScrollStep
    call RunEndingTextListAndWait
    call EndingScrollStep
    ld a, [wCreditsPage]
    ld hl, CreditsPageTable
    call LookupWord
    call QueueVramCopyList
    jp WaitVramCopyDone
RunEndingTextListAndWait::  ; queues the VRAM copy list at $2dff and waits until it is done (name provisional)
    ld bc, D_00_2dff
    call QueueVramCopyList
.L_00_2df7:
    ld a, [wVramCopyFlags]
    bit 0, a
    jr nz, .L_00_2df7
    ret
D_00_2dff::
    INCBIN "assets/bank_00/2dff.bin"
CreditsPageTable::  ; 9 pointers to credit pages
    dw CreditsPage0
    dw CreditsPage1
    dw CreditsPage2
    dw CreditsPage3
    dw CreditsPage4
    dw CreditsPage5
    dw CreditsPage6
    dw CreditsPage7
    dw CreditsPage8
CreditsPage0::  ; data (table entry)
    INCBIN "assets/bank_00/2e21_CreditsPage0.bin"
CreditsPage1::  ; data (table entry)
    INCBIN "assets/bank_00/2e2d_CreditsPage1.bin"
CreditsPage5::  ; data (table entry)
    INCBIN "assets/bank_00/2e4c_CreditsPage5.bin"
CreditsPage6::  ; data (table entry)
    INCBIN "assets/bank_00/2e6c_CreditsPage6.bin"
CreditsPage2::  ; data (table entry)
    INCBIN "assets/bank_00/2e88_CreditsPage2.bin"
CreditsPage3::  ; data (table entry)
    INCBIN "assets/bank_00/2ea7_CreditsPage3.bin"
CreditsPage4::  ; data (table entry)
    INCBIN "assets/bank_00/2ec6_CreditsPage4.bin"
CreditsPage7::  ; data (table entry)
    INCBIN "assets/bank_00/2ee5_CreditsPage7.bin"
CreditsPage8::  ; data (table entry)
    INCBIN "assets/bank_00/2eff_CreditsPage8.bin"
EndingTick::  ; one step of the ending scene: hero movement then the object animation
    call EndingMoveHero
    jp EndingAnimateObject
EndingMoveHero::  ; moves the hero in the ending scene until it reaches $c775 = $50
    call EndingHeroFrame
    ld a, [wEndingEvents]
    bit 2, a
    ret nz
    ld a, [wEndingX]
    cp a, $50
    jr z, .L_00_2f41
    dec a
    ld [wEndingX], a
    ret
.L_00_2f41:
    ld hl, wEndingEvents
    set 2, [hl]
    ret
EndingHeroFrame::  ; chooses the hero frame and flips it by $c782 bit 0
    ld a, $02
    ld [wEndingSpeed], a
    ld a, [wEndingPhase]
    bit 0, a
    jr nz, .L_00_2f59
    xor a, a
    ld [wEndingAngle], a
    jr .L_00_2f5e
.L_00_2f59:
    ld a, $10
    ld [wEndingAngle], a
.L_00_2f5e:
    call SelectEndingObject
    call MoveObject
    call ApplyObjectStep
    ld hl, wEndingStep
    dec [hl]
    ret nz
    ld a, $0a
    ld [wEndingStep], a
    ld hl, wEndingPhase
    inc [hl]
    ret
EndingAnimateObject::  ; cycles the ending object between the frame tables D_00_30df and D_00_3111
    ld c, $00
    ld hl, $c780
    inc [hl]
    ld a, [hl]
    and a, $08
    srl a
    srl a
    ld c, a
    ld hl, D_00_30df
    ld a, [wEndingEvents]
    bit 2, a
    jr z, .L_00_2f91
    ld hl, D_00_3111
.L_00_2f91:
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ld [$c76f], a
    ld a, [hl]
    ld [$c770], a
    ld hl, wEndingObject
    call SetObjPtr
    jp DrawObject
EndingScrollStep::  ; scrolls the castle scene: $c798/$c799 -= $5a and copies it to wScrollX
    ld a, [wEnding2Y]
    sub a, $5a
    ld [wEnding2Y], a
    ld a, [$c799]
    sbc a, $00
    ld [$c799], a
    ld [wScrollX], a
    ret
EndingSetup::  ; mode 6 setup: clears OAM and the ending variables at $c76e and loads the castle scene jobs
    call LcdOff
    di
    ld hl, vBGMapLast
    call FillBackwardsFF
    call ClearOamShadowY
    call RequestOamDma
    ld hl, wEndingObject
    ld bc, $0041
    call ClearMemory
    xor a, a
    ld [wCameraX], a
    ld [wCameraY], a
    ld bc, D_00_30c4
    call RunVramCopyList
    ld a, $80
    ld [wEndingObject], a
    ld a, $c8
    ld [wEndingX], a
    ld a, $50
    ld [wEndingY], a
    ld a, $0a
    ld [wEndingStep], a
    ld bc, D_00_3009
    call RunVramCopyList
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK
    ld [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ret
D_00_3009::
    INCBIN "assets/bank_00/3009.bin"
EndingWalkStep::  ; steps the walking animation counters at $c77e-$c780
    ld a, [wEndingY]
    cp a, $08
    jr c, EndingAdvance
    ld hl, $c780
    inc [hl]
    ld a, [hl]
    and a, $10
    jr z, .L_00_3070
    ld hl, wEndingSpeed
    inc [hl]
    ld hl, wEndingAngle
    inc [hl]
    xor a, a
    ld [$c780], a
.L_00_3070:
    call SelectEndingObject
    call MoveObject
    call ApplyObjectStep
    call SelectEndingObject
    jp DrawObject
SelectEndingObject::  ; hObjPtr = wEndingObject
    ld hl, wEndingObject
    jp SetObjPtr
EndingCastleBlink::  ; toggles the castle flag animation from D_00_3148
    ld c, $00
    ld hl, $c7a0
    inc [hl]
    ld a, [hl]
    and a, $08
    srl a
    srl a
    ld c, a
    ld hl, D_00_3148
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ld [wEndingObject2Anim], a
    ld a, [hl]
    ld [wCreditsPage], a
    ld hl, wEndingObject2
    call SetObjPtr
    jp DrawObject
EndingAdvance::  ; advances $c781/$c782 by $10 per call; sets $c7ae bit 7 at 5
    ld a, [wEndingStep]
    add a, $10
    ld [wEndingStep], a
    ld a, [wEndingPhase]
    adc a, $00
    ld [wEndingPhase], a
    and a, a
    cp a, $05
    ret nz
    ld hl, wEndingEvents
    set 7, [hl]
    ret
D_00_30c4::
    INCBIN "assets/bank_00/30c4.bin"
D_00_30df::
    INCBIN "assets/bank_00/30df.bin"
AnimFrames0_30e3::  ; animation frames (typed text form)
    INCBIN "assets/bank_00/30e3_AnimFrames0_30e3.bin"
D_00_3111::
    INCBIN "assets/bank_00/3111.bin"
D_00_3143::
    INCBIN "assets/bank_00/3143.bin"
D_00_3148::
    INCBIN "assets/bank_00/3148.bin"
AnimFrames0_314c::  ; animation frames (typed text form)
    INCBIN "assets/bank_00/314c_AnimFrames0_314c.bin"
D_00_3156::
    INCBIN "assets/bank_00/3156.bin"
D_00_31a6::
    INCBIN "assets/bank_00/31a6.bin"
TickObjectTimer::  ; increments $ffd0; Z flag from bit 7 of $ffd1
    ld hl, hEnemyTick
    inc [hl]
    inc hl
    ld a, [hl]
    bit 7, a
    ret
SetEnemyHitFlag::  ; sets hEnemyFlags bit 2 (paint hit)
    ld hl, hEnemyFlags
    set 2, [hl]
    ret
StepEnemySpawnScript::  ; reads the round's spawn list (RoundDataTable by wRound; position $c481/$c482
    ld a, [wRound]
    dec a
    ld hl, RoundDataTable
    call LookupWord
    ld a, [wSpawnWave]
    cp a, $06
    jr nz, .L_00_3206
    xor a, a
    ld [wSpawnWave], a
.L_00_3206:
    call LookupWord
    ld a, l
    ld [wSpawnListPtr], a
    ld a, h
    ld [$c482], a
    ld a, [hl]
    ld [wSpawnCount], a
    ld d, a
    ld a, [wSpawnIndex]
    dec a
    cp a, d
    jr nz, .L_00_3229
    ld hl, wSpawnWave
    inc [hl]
    ld a, $01
    ld [wSpawnIndex], a
    ld [wWaveEnded], a
.L_00_3229:
    ld a, [wPlayerStatus]
    bit 5, a
    jr nz, .L_00_324a
    ld hl, wSpawnListPtr
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    pop hl
    ld a, [wSpawnIndex]
    sla a
    sla a
    ld c, a
    call LookupByte
    ldh [hSpawnDelay], a
    ld hl, wPlayerStatus
    set 5, [hl]
.L_00_324a:
    ldh a, [hSpawnDelay]
    ld e, a
    ldh a, [hTimeSeconds]
    ld d, a
    ldh a, [hRoundSeconds]
    sub a, e
    cp a, d
    ret c
    ld a, [wEnemyCount]
    cp a, $03
    ret nc
    ld hl, wSpawnListPtr
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    pop hl
    ld a, [wSpawnIndex]
    sla a
    sla a
    sub a, $03
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ldh [hScratch07], a
    ld a, [hl+]
    ldh [hScratch08], a
    ld a, [hl]
    and a, $f8
    ldh [hScratch0A], a
    ld a, [wRound]
    cp a, $11
    jr c, .L_00_3289
    ld a, [hl]
    and a, $02
    ldh [hSpawnFlag], a
    jr .L_00_328e
.L_00_3289:
    ld a, [hl]
    and a, $01
    ldh [hSpawnFlag], a
.L_00_328e:
    ld hl, wSpawnIndex
    inc [hl]
    ld hl, wWaveEnded
    inc [hl]
    ld hl, wEnemyCount
    inc [hl]
    ld hl, wPlayerStatus
    res 5, [hl]
    jp FindFreeEnemySlot
ProjectileFrame::  ; per frame step and draw of the projectile object at wProjectile (skipped while SEALED or GHOST magic runs)
    ld a, [wActiveMagic]
    cp a, $06
    jr nz, .L_00_32af
    ld a, [wMagicState]
    bit 0, a
    ret nz
.L_00_32af:
    ld a, [wActiveMagic]
    cp a, $04
    jr nz, .L_00_32bc
    ld a, [wMagicState]
    bit 0, a
    ret nz
.L_00_32bc:
    ld a, [wProjectile]
    bit 7, a
    ret z
    ld hl, wProjectile
    ld a, l
    ldh [hOtherObjLo], a
    ld a, h
    ldh [hOtherObjHi], a
    ld hl, wPlayer
    ld a, l
    ldh [hObjPtrLo], a
    ld a, h
    ldh [hObjPtrHi], a
    call ObjectsOverlap
    and a, a
    ret z
    ld hl, wPlayerDir
    set 5, [hl]
    ret
EnemyDefeated::  ; plays SND_SFX_8E and handles an enemy hit by paint (hEnemyFlags bit 2): score and removal
    ld a, SND_SFX_8E
    call PlaySound
    ld hl, hEnemyCounter2
    inc [hl]
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_32f3
    ld hl, wComboCounter
    inc [hl]
.L_00_32f3:
    ld a, $0c
    ldh [hScratch06], a
    ld a, $02
    ldh [hScratch07], a
    ldh a, [hEnemyCounter2]
    ldh [hScratch08], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_330b
    ld a, [wComboCounter]
    ldh [hScratch08], a
.L_00_330b:
    ld a, $03
    call CounterToFrame
    ldh a, [hScratch08]
    ldh [hEnemyCounter2], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_3320
    ldh a, [hScratch08]
    ld [wComboCounter], a
.L_00_3320:
    ld a, $06
    cp a, c
    jp z, .L_00_33da
    ld a, c
    and a, a
    jr nz, .L_00_332f
    ld hl, D_00_36c1
    jr .L_00_333b
.L_00_332f:
    cp a, $02
    jr nz, .L_00_3338
    ld hl, D_00_36bc
    jr .L_00_333b
.L_00_3338:
    ld hl, D_00_36c6
.L_00_333b:
    push hl
    ld a, l
    ldh [hEnemyAnimLo], a
    ld a, h
    ldh [hEnemyAnimHi], a
    call SelectObject2
    call DrawObject
    pop hl
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_3361
    ld a, l
    ld [wProjectileAnimLo], a
    ld a, h
    ld [wProjectileAnimHi], a
    ld hl, wProjectile
    call SetObjPtr
    call DrawObject
.L_00_3361:
    ld hl, hObject2
    set 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_3381
    ld hl, wProjectile
    set 6, [hl]
    ld hl, wProjectile
    call SetObjPtr
    call DrawObject
.L_00_3381:
    ld hl, hObject2
    set 5, [hl]
    res 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_33a5
    ld hl, wProjectile
    set 5, [hl]
    res 6, [hl]
    ld hl, wProjectile
    call SetObjPtr
    call DrawObject
.L_00_33a5:
    ld hl, hObject2
    set 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_33c5
    ld hl, wProjectile
    set 6, [hl]
    ld hl, wProjectile
    call SetObjPtr
    call DrawObject
.L_00_33c5:
    ldh a, [hObject2]
    and a, $9f
    ldh [hObject2], a
    ld a, [wPlayerStatus]
    bit 4, a
    ret z
    ld a, [wProjectile]
    and a, $9f
    ld [wProjectile], a
    ret
.L_00_33da:
    ld hl, wPlayerStatus
    res 3, [hl]
    res 4, [hl]
    ld hl, hEnemyFlags
    res 2, [hl]
    ldh a, [hEnemyKind]
    ld c, a
    ld hl, D_00_33fd
    call LookupByte
    ld e, a
    ld d, $00
    call AddScore
    ld hl, wProjectile
    res 7, [hl]
    jp RemoveEnemy
D_00_33fd::
    INCBIN "assets/bank_00/33fd.bin"
EnemySnapToGrid::  ; aligns hEnemyX to the 16 pixel grid and sets hEnemyDir to $90 plus the low nibble; also sets $ffb9 = 4 (name provisional)
    ld a, $04
    ldh [hEnemyBoxHalf], a
    ldh a, [hEnemyX]
    push af
    and a, $f0
    ldh [hEnemyX], a
    pop af
    and a, $0f
    or a, $90
    ldh [hEnemyDir], a
    ret
CheckEnemyTouchesPlayer::  ; if the enemy in hObject2 overlaps wPlayer then wPlayerDir bit 5 is set (PlayFrame then runs PlayerDeath)
    ldh a, [hEnemyKind]
    cp a, $04
    jr z, .L_00_3432
    ld a, [wActiveMagic]
    cp a, $04
    jr nz, .L_00_3432
    ld a, [wMagicState]
    bit 0, a
    ret nz
.L_00_3432:
    ld hl, wPlayer
    ld a, l
    ldh [hOtherObjLo], a
    ld a, h
    ldh [hOtherObjHi], a
    call SelectObject2
    call ObjectsOverlap
    and a, a
    ret z
    ld hl, wPlayerDir
    set 5, [hl]
    ret
EnemyScreenPosition::  ; converts enemy pixel position to screen coordinates (camera subtracted) in hScratch00/01
    push hl
    ld a, [wCameraX]
    ld l, a
    ld a, c
    sub a, l
    ldh [hScratch00], a
    ld a, [wCameraY]
    ld l, a
    ld a, b
    sub a, l
    ldh [hScratch01], a
    pop hl
    ldh a, [hScratch00]
    cp a, $a8
    jr nc, .L_00_3475
    ldh a, [hScratch00]
    cp a, $08
    jr c, .L_00_3475
    ldh a, [hScratch01]
    cp a, $a8
    jr nc, .L_00_3475
    ldh a, [hScratch01]
    cp a, $10
    jr c, .L_00_3475
    xor a, a
    ret
.L_00_3475:
    ld a, $01
    ret
EnemyOnTileGrid::  ; Z when the enemy is aligned to the 16 pixel grid
    ldh a, [hEnemyX]
    ld b, a
    ldh a, [hEnemyY]
    ld c, a
    jp IsOnTileGrid
EnemyComputeBlockedDirs::  ; fills hEnemyBlocked from the room map cells around the enemy
    ldh a, [hEnemyX]
    ld b, a
    ldh a, [hEnemyY]
    ld c, a
    xor a, a
    ldh [hEnemyBlocked], a
    ld a, b
    add a, $08
    and a, $f0
    call PixelXToColumn
    ld a, c
    and a, $f0
    add a, $08
    cp a, c
    jr c, .L_00_34ae
    ld a, c
    and a, $f0
    add a, $08
    sub a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_00_34ae
    ld a, $04
    ldh [hEnemyBlocked], a
.L_00_34ae:
    ld a, b
    add a, $08
    and a, $f0
    call PixelXToColumn
    ld a, c
    and a, $f0
    add a, $08
    ld d, a
    ld a, c
    cp a, d
    jr c, .L_00_34d5
    and a, $f0
    add a, $08
    add a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_00_34d5
    ldh a, [hEnemyBlocked]
    or a, $08
    ldh [hEnemyBlocked], a
.L_00_34d5:
    ld a, b
    add a, $08
    and a, $f0
    cp a, b
    jr c, .L_00_34fc
    add a, $08
    and a, $f0
    call PixelXToColumn
    ld a, e
    sub a, $01
    ld e, a
    ld a, c
    and a, $f0
    add a, $08
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_00_34fc
    ldh a, [hEnemyBlocked]
    or a, $02
    ldh [hEnemyBlocked], a
.L_00_34fc:
    ld a, b
    add a, $08
    and a, $f0
    ld d, a
    ld a, b
    cp a, d
    ret c
    ld a, b
    add a, $08
    and a, $f0
    call PixelXToColumn
    ld a, e
    add a, $01
    ld e, a
    ld a, c
    and a, $f0
    add a, $08
    call LookupMapTile
    and a, $0f
    or a, $00
    ret nz
    ldh a, [hEnemyBlocked]
    or a, $01
    ldh [hEnemyBlocked], a
    ret
RemoveEnemy::  ; clears the active bit of hObject2 and decrements wEnemyCount
    ld hl, hObject2
    res 7, [hl]
    ld hl, wEnemyCount
    dec [hl]
    ret
EnemyPaintStep::  ; paint trail step of an enemy: when hEnemyDir bit 5 is set looks up the map tile under the enemy and acts on it (skipped for kind 8 and while the B.O.M card runs; name provisional)
    ldh a, [hEnemyKind]
    cp a, $08
    ret z
    ld a, [wActiveMagic]
    cp a, $05
    jr nz, .L_00_3541
    ld a, [wMagicState]
    bit 0, a
    ret nz
.L_00_3541:
    ldh a, [hEnemyDir]
    bit 5, a
    ret z
    ld hl, hEnemyDir
    res 5, [hl]
    ldh a, [hEnemyX]
    call PixelXToColumn
    ldh a, [hEnemyY]
    and a, $f0
    add a, $08
    call LookupMapTile
    ld e, a
    bit 7, a
    ret nz
    bit 4, a
    ret z
    ldh a, [hEnemyX]
    ld c, a
    ldh a, [hEnemyY]
    ld b, a
    call EnemyScreenPosition
    and a, a
    ret nz
    ld a, e
    and a, $0f
    or a, $80
    ld [hl], a
    ldh a, [hEnemyX]
    add a, $08
    and a, $f0
    ldh [hSpriteX], a
    ldh a, [hEnemyY]
    and a, $f0
    add a, $08
    sub a, $08
    ldh [hSpriteY], a
    call PixelToTilemapAddr
    ld l, a
    dec l
    ldh a, [hTilemapAddrHi]
    ld h, a
    ld de, D_00_3ac4
    call QueueVramCopyRows
    call WaitVramCopyDone
    ld hl, wPaintRemaining
    inc [hl]
    ret
EnemyAimAtPlayer::  ; when on the tile grid: compares enemy and player positions to set the direction bits towards the player
    ldh a, [hEnemyX]
    ld b, a
    ldh a, [hEnemyY]
    ld c, a
    call IsOnTileGrid
    ret nz
    ldh a, [hEnemyXHi]
    cp a, $01
    jr z, .L_00_35ba
    ldh a, [hEnemyX]
    ld c, a
    ld a, [wPlayerX]
    ld e, a
    cp a, c
    jr z, .L_00_35c6
    jr c, .L_00_35ba
    sub a, c
    ld l, $01
    jr .L_00_35be
.L_00_35ba:
    ld a, c
    sub a, e
    ld l, $02
.L_00_35be:
    ldh a, [hEnemyBlocked]
    and a, l
    jr nz, .L_00_35f0
    ld b, l
    jr .L_00_35e1
.L_00_35c6:
    ldh a, [hEnemyY]
    ld b, a
    ld a, [wPlayerY]
    ld d, a
    cp a, b
    jr z, .L_00_35e1
    jr c, .L_00_35d7
    sub a, b
    ld h, $08
    jr .L_00_35db
.L_00_35d7:
    ld a, b
    sub a, d
    ld h, $04
.L_00_35db:
    ldh a, [hEnemyBlocked]
    and a, h
    jr nz, .L_00_35f0
    ld b, h
.L_00_35e1:
    ldh a, [hEnemyBlocked]
    swap a
    and a, $0f
    and a, b
    ldh a, [hEnemyDir]
    and a, $f0
    or a, b
    ldh [hEnemyDir], a
    ret
.L_00_35f0:
    ld hl, hEnemyDir
    set 6, [hl]
    jp EnemyChooseDirection
RememberEnemyPosition::  ; stores hEnemyX/hEnemyY at $c525/$c526
    ldh a, [hEnemyX]
    ld [$c525], a
    ldh a, [hEnemyY]
    ld [$c526], a
    ret
EnemyTurnIfBlocked::  ; requests a turn when the enemy walks into a blocked direction; otherwise sets the speed from D_00_363d by direction (T.STOP card exception; name provisional)
    ldh a, [hEnemyKind]
    cp a, $04
    jr z, .L_00_3620
    cp a, $03
    jr nz, .L_00_3620
    ld a, [wActiveMagic]
    cp a, $03
    jr nz, .L_00_3620
    ld a, [wMagicState]
    bit 0, a
    jp nz, EnemyRequestTurn
    ld a, $05
    ldh [hEnemySpeed], a
.L_00_3620:
    ldh a, [hEnemyBlocked]
    and a, $0f
    ld d, a
    ldh a, [hEnemyDir]
    and a, $0f
    and a, d
    jp nz, EnemyRequestTurn
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld c, a
    ld hl, D_00_363d
    call LookupByte
    ldh [hEnemyAngle], a
    ret
D_00_363d::
    INCBIN "assets/bank_00/363d.bin"
MoveAndApplyObject::  ; MoveObject then ApplyObjectStep
    call MoveObject
    jp ApplyObjectStep
SetAnimationVariant::  ; DE = BC when bit 3 of $ffd0 is set; then SetObjectAnimation
    ldh a, [hEnemyTick]
    and a, $08
    jr z, SetObjectAnimationStub
    push bc
    pop de
SetObjectAnimationStub::  ; tail jump to SetObjectAnimation (name provisional)
    jp SetObjectAnimation
SelectObject2::  ; hObjPtr = hObject2
    ld hl, hObject2
    ld a, l
    ldh [hObjPtrLo], a
    ld a, $ff
    ldh [hObjPtrHi], a
    ret
SetObjectAnimation::  ; stores DE as the animation pointer (record +1/+2) of hObject2
    ld a, e
    ldh [hEnemyAnimLo], a
    ld a, d
    ldh [hEnemyAnimHi], a
    ret
EnemyRequestTurn::  ; sets hEnemyDir bit 6 and clears the movement variables
    ld hl, hEnemyDir
    set 6, [hl]
    xor a, a
    ldh [hEnemySpeed], a
    ldh [hEnemyDXHi], a
    ldh [hEnemyDYHi], a
    ret
EnemyTileUnder::  ; A = room map tile under the enemy (Y aligned to the grid)
    ldh a, [hEnemyX]
    call PixelXToColumn
    ldh a, [hEnemyY]
    and a, $f0
    add a, $08
    jp LookupMapTile
GetEnemyPos::  ; C = hEnemyX and B = hEnemyY
    ld hl, hEnemyX
    ld c, [hl]
    ld hl, hEnemyY
    ld b, [hl]
    ret
GetPlayerPos::  ; L = wPlayerX and H = wPlayerY
    ld a, [wPlayerX]
    ld l, a
    ld a, [wPlayerY]
    ld h, a
    ret
CheckPaintHitsEnemy::  ; tests the object at $c4fe (paint blob) against hObject2; on a hit sets wPlayerStatus bit 3 and hEnemyFlags bit 2
    ld a, [wPaintObject]
    bit 7, a
    ret z
    ld hl, wPaintObject
    ld a, l
    ldh [hOtherObjLo], a
    ld a, h
    ldh [hOtherObjHi], a
    call SelectObject2
    call ObjectsOverlap
    and a, a
    ret z
    ld hl, wPaintObject
    res 7, [hl]
    call SetEnemyHitFlag
    xor a, a
    ld [wMagicState], a
    ld hl, wPlayerStatus
    set 3, [hl]
    ret
D_00_36bc::
    INCBIN "assets/bank_00/36bc.bin"
D_00_36c1::
    INCBIN "assets/bank_00/36c1.bin"
D_00_36c6::
    INCBIN "assets/bank_00/36c6.bin"
EnemyEdgeBlockedDirs::  ; adds the screen edge limits (X $20-$f0; Y $28-$f8) to hEnemyBlocked
    xor a, a
    ldh [hEnemyBlocked], a
    ldh a, [hEnemyX]
    cp a, $21
    jr nc, .L_00_36d6
    ld a, $02
    ldh [hEnemyBlocked], a
.L_00_36d6:
    ldh a, [hEnemyX]
    cp a, $f0
    jr c, .L_00_36e2
    ldh a, [hEnemyBlocked]
    or a, $01
    ldh [hEnemyBlocked], a
.L_00_36e2:
    ldh a, [hEnemyY]
    cp a, $29
    jr nc, .L_00_36ee
    ldh a, [hEnemyBlocked]
    or a, $04
    ldh [hEnemyBlocked], a
.L_00_36ee:
    ldh a, [hEnemyY]
    cp a, $f8
    ret c
    ldh a, [hEnemyBlocked]
    or a, $08
    ldh [hEnemyBlocked], a
    ret
ClearAllEnemies::  ; clears the flag byte of all 16 enemy slots
    ld a, $0f
    ld [wEnemyLoopIdx], a
.L_00_36ff:
    ld hl, EnemySlotTable
    call SelectEnemySlot
    xor a, a
    ld [hl], a
    ld a, [wEnemyLoopIdx]
    dec a
    ld [wEnemyLoopIdx], a
    bit 7, a
    jr z, .L_00_36ff
    ret
UpdateAllEnemies::  ; starts the enemy loop with $c53f incremented and $c53e = 15
    ld hl, wEnemyLoopStart
    inc [hl]
    ld a, $0f
    ld [wEnemyLoopIdx], a
UpdateEnemyLoop::  ; for each slot index: load the slot into HRAM; run UpdateEnemy; store it back
    ld a, [wEnemyLoopStart]
    ld b, a
    ld a, [wEnemyLoopIdx]
    add a, b
    and a, $0f
    ld hl, EnemySlotTable
    call SelectEnemySlot
    ld a, [hl]
    bit 7, a
    jr z, .L_00_373a
    call LoadEnemySlot
    call UpdateEnemy
    call StoreEnemySlot
.L_00_373a:
    ld a, [wEnemyLoopIdx]
    dec a
    ld [wEnemyLoopIdx], a
    bit 7, a
    jr z, UpdateEnemyLoop
    ret
UpdateEnemy::  ; one enemy step on the record held in hObject2
    ldh a, [hEnemyDir]
    bit 4, a
    jr nz, .L_00_375e
    ldh a, [hEnemyKind]
    sla a
    ld c, a
    ld b, $00
    ld hl, EnemyBehaviorTable
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    push de
    pop hl
    jp hl
.L_00_375e:
    ldh a, [$ffde]
    bit 2, a
    ret z
    ld hl, hObject2
    ld a, l
    ldh [hObjPtrLo], a
    ld a, $ff
    ldh [hObjPtrHi], a
    call DrawObject
    ldh a, [hEnemyCounter]
    sub a, $01
    ldh [hEnemyCounter], a
    bit 7, a
    ret z
    ld hl, hEnemyDir
    res 4, [hl]
    xor a, a
    ldh [hEnemyCounter], a
    ret
EnemyBehaviorTable::  ; routine pointers indexed by $ffd2 (enemy kind/state); UpdateEnemy jumps through it
    dw EnemyKindIdle
    dw EnemyKind1
    dw EnemyKind2
    dw EnemyKind3
    dw EnemyKind4
    dw EnemyKind5
    dw EnemyKindIdle
    dw EnemyKind7
    dw EnemyKindIdle
    dw EnemyKind9
    dw EnemyKind10
    dw EnemyKind11
    INCBIN "assets/bank_00/379a.bin"
SelectEnemySlot::  ; HL = slot address from the word table at HL (A = index); stored in $ffd7/$ffd8
    sla a
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ldh [hEnemySlotLo], a
    push af
    ld a, [hl]
    ldh [hEnemySlotHi], a
    ld h, a
    pop af
    ld l, a
    ret
EnemySlotTable::  ; 16 word addresses of the enemy slots: $c542 + $20 * i
    dw $c542
    dw $c562
    dw $c582
    dw $c5a2
    dw $c5c2
    dw $c5e2
    dw $c602
    dw $c622
    dw $c642
    dw $c662
    dw $c682
    dw $c6a2
    dw $c6c2
    dw $c6e2
    dw $c702
    dw $c722
    INCBIN "assets/bank_00/37cf.bin"
FindFreeEnemySlot::  ; scans slots 15 down to 0 for one whose bit 7 is clear
    ld a, $0f
    ldh [hScratch06], a
.L_00_37f9:
    ldh a, [hScratch06]
    ld hl, EnemySlotTable
    call SelectEnemySlot
    ld a, [hl]
    bit 7, a
    jr z, .L_00_3810
    ldh a, [hScratch06]
    dec a
    ldh [hScratch06], a
    bit 7, a
    jr z, .L_00_37f9
    ret
.L_00_3810:
    call ClearEnemySlot
    ld a, $82
    ldh [hObject2], a
    ldh a, [hScratch07]
    ldh [hEnemyKind], a
    ldh a, [hScratch08]
    ldh [hEnemyX], a
    ldh a, [hScratch0A]
    ldh [hEnemyY], a
    ldh a, [hSpawnFlag]
    ldh [hEnemySpawnFlag], a
    jp StoreEnemySlot
ClearEnemySlot::  ; zero fills hObject2
    ld hl, hObject2
    jp Clear32Bytes
StoreEnemySlot::  ; copies the 32 byte HRAM object hObject2 back to its slot ($ffd7/$ffd8)
    ldh a, [hEnemySlotLo]
    ld l, a
    ldh a, [hEnemySlotHi]
    ld h, a
    ldh a, [hObject2]
    ld [hl+], a
    ldh a, [hEnemyAnimLo]
    ld [hl+], a
    ldh a, [hEnemyAnimHi]
    ld [hl+], a
    ldh a, [$ffb8]
    ld [hl+], a
    ldh a, [hEnemyBoxHalf]
    ld [hl+], a
    ldh a, [hEnemyFrame]
    ld [hl+], a
    ldh a, [$ffbb]
    ld [hl+], a
    ldh a, [hEnemyX]
    ld [hl+], a
    ldh a, [hEnemyXHi]
    ld [hl+], a
    ldh a, [$ffbe]
    ld [hl+], a
    ldh a, [hEnemyY]
    ld [hl+], a
    ldh a, [hEnemyYHi]
    ld [hl+], a
    ldh a, [hEnemyDXLo]
    ld [hl+], a
    ldh a, [hEnemyDXHi]
    ld [hl+], a
    ldh a, [hEnemyDYLo]
    ld [hl+], a
    ldh a, [hEnemyDYHi]
    ld [hl+], a
    ldh a, [hEnemyAngle]
    ld [hl+], a
    ldh a, [hEnemySpeed]
    ld [hl+], a
    ldh a, [hEnemyBlocked]
    ld [hl+], a
    ldh a, [$ffc8]
    ld [hl+], a
    ldh a, [hEnemyCounter]
    ld [hl+], a
    ldh a, [hEnemyStep]
    ld [hl+], a
    ldh a, [hEnemyTimer]
    ld [hl+], a
    ldh a, [hEnemyAux]
    ld [hl+], a
    ldh a, [$ffcd]
    ld [hl+], a
    ldh a, [$ffce]
    ld [hl+], a
    ldh a, [hEnemySpawnFlag]
    ld [hl+], a
    ldh a, [hEnemyTick]
    ld [hl+], a
    ldh a, [hEnemyDir]
    ld [hl+], a
    ldh a, [hEnemyKind]
    ld [hl+], a
    ldh a, [hEnemyCounter2]
    ld [hl+], a
    ldh a, [hEnemyFlags]
    ld [hl], a
    ret
LoadEnemySlot::  ; copies a slot ($ffd7/$ffd8) into the HRAM object hObject2
    ldh a, [hEnemySlotLo]
    ld l, a
    ldh a, [hEnemySlotHi]
    ld h, a
    ld a, [hl+]
    ldh [hObject2], a
    ld a, [hl+]
    ldh [hEnemyAnimLo], a
    ld a, [hl+]
    ldh [hEnemyAnimHi], a
    ld a, [hl+]
    ldh [$ffb8], a
    ld a, [hl+]
    ldh [hEnemyBoxHalf], a
    ld a, [hl+]
    ldh [hEnemyFrame], a
    ld a, [hl+]
    ldh [$ffbb], a
    ld a, [hl+]
    ldh [hEnemyX], a
    ld a, [hl+]
    ldh [hEnemyXHi], a
    ld a, [hl+]
    ldh [$ffbe], a
    ld a, [hl+]
    ldh [hEnemyY], a
    ld a, [hl+]
    ldh [hEnemyYHi], a
    ld a, [hl+]
    ldh [hEnemyDXLo], a
    ld a, [hl+]
    ldh [hEnemyDXHi], a
    ld a, [hl+]
    ldh [hEnemyDYLo], a
    ld a, [hl+]
    ldh [hEnemyDYHi], a
    ld a, [hl+]
    ldh [hEnemyAngle], a
    ld a, [hl+]
    ldh [hEnemySpeed], a
    ld a, [hl+]
    ldh [hEnemyBlocked], a
    ld a, [hl+]
    ldh [$ffc8], a
    ld a, [hl+]
    ldh [hEnemyCounter], a
    ld a, [hl+]
    ldh [hEnemyStep], a
    ld a, [hl+]
    ldh [hEnemyTimer], a
    ld a, [hl+]
    ldh [hEnemyAux], a
    ld a, [hl+]
    ldh [$ffcd], a
    ld a, [hl+]
    ldh [$ffce], a
    ld a, [hl+]
    ldh [hEnemySpawnFlag], a
    ld a, [hl+]
    ldh [hEnemyTick], a
    ld a, [hl+]
    ldh [hEnemyDir], a
    ld a, [hl+]
    ldh [hEnemyKind], a
    ld a, [hl+]
    ldh [hEnemyCounter2], a
    ld a, [hl]
    ldh [hEnemyFlags], a
    ret
EnemyKindIdle::  ; kinds 0 6 8: stationary enemy (kind 0 = the armoured guards standing in the corridor rooms 13-15 and 29-31)
    call TickObjectTimer
    jr nz, .L_00_3906
    jp EnemyInitMoveAnim
.L_00_3906:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call EnemyGridStep
    call EnemyChooseDirection
    call EnemyTurnOrAnimate
    call EnemyPaintStep
    call EnemyPaintUnderB0M
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call EnemySelectAnimByKind
    call SelectObject2
    jp DrawObject
EnemyPaintUnderB0M::  ; with the B.O.M card active paints the cell under an enemy that is not frozen (name provisional)
    ld a, [wActiveMagic]
    cp a, $05
    ret nz
    ld a, [wMagicState]
    bit 0, a
    ret z
    ldh a, [hEnemyFlags]
    bit 1, a
    ret nz
    ldh a, [hEnemyX]
    ld b, a
    ldh a, [hEnemyY]
    ld c, a
    call IsOnTileGrid
    ret nz
    ld a, b
    jp PaintCell
EnemyRemoveIfPlayerDead::  ; removes the enemy when wPlayerDir bit 5 is set
    ld a, [wPlayerDir]
    bit 5, a
    ret z
    jp RemoveEnemy
EnemySelectAnimByKind::  ; sets the animation pair for kinds 6 and 8 (D_00_3acf and D_00_3ad9) or the default (name provisional)
    ldh a, [hEnemyKind]
    cp a, $06
    jr z, .L_00_3963
    cp a, $08
    jr z, .L_00_396c
    jp .L_00_3975
.L_00_3963:
    ld de, D_00_3acf
    ld bc, D_00_3ad4
    jp SetAnimationVariant
.L_00_396c:
    ld de, D_00_3ad9
    ld bc, D_00_3ade
    jp SetAnimationVariant
.L_00_3975:
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_00_398c
    bit 1, a
    jr nz, .L_00_399a
    bit 2, a
    jr nz, .L_00_39a8
    ld de, D_00_3aa6
    ld bc, D_00_3aab
    jp SetAnimationVariant
.L_00_398c:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3ab0
    ld bc, D_00_3ab5
    jp SetAnimationVariant
.L_00_399a:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3ab0
    ld bc, D_00_3ab5
    jp SetAnimationVariant
.L_00_39a8:
    ld de, D_00_3aba
    ld bc, D_00_3abf
    jp SetAnimationVariant
EnemyTurnOrAnimate::  ; like EnemyTurnIfBlocked and then picks the animation table D_00_3ae3 or D_00_3aed (name provisional)
    ld a, [wActiveMagic]
    cp a, $03
    jr nz, .L_00_39c0
    ld a, [wMagicState]
    bit 0, a
    jp nz, EnemyRequestTurn
.L_00_39c0:
    ldh a, [hEnemyBlocked]
    and a, $0f
    ld d, a
    ldh a, [hEnemyDir]
    and a, $0f
    ld e, a
    and a, d
    jp nz, EnemyRequestTurn
    ld a, e
    srl a
    sla a
    ld c, a
    ld b, $00
    ld hl, D_00_3ae3
    ldh a, [hEnemyFlags]
    bit 7, a
    jr z, .L_00_39e4
    ld hl, D_00_3aed
    jr .L_00_39ec
.L_00_39e4:
    ldh a, [hEnemySpawnFlag]
    and a, a
    jr z, .L_00_39ec
    ld hl, D_00_3aed
.L_00_39ec:
    add hl, bc
    ld a, [hl+]
    ldh [hEnemyDXHi], a
    ld a, [hl]
    ldh [hEnemyDYHi], a
    call SelectObject2
    jp ApplyObjectStep
EnemyGridStep::  ; on the tile grid advances hEnemyStep to $0b and then sets hEnemyDir bits 5 and 6 (name provisional)
    call EnemyOnTileGrid
    jr z, .L_00_3a04
    ld hl, hEnemyDir
    res 6, [hl]
    ret
.L_00_3a04:
    ldh a, [hEnemyStep]
    cp a, $0b
    jr z, .L_00_3a0e
    inc a
    ldh [hEnemyStep], a
    ret
.L_00_3a0e:
    xor a, a
    ldh [hEnemyStep], a
    ldh a, [hEnemyDir]
    or a, $60
    ldh [hEnemyDir], a
    ret
EnemyChooseDirection::  ; when hEnemyDir bit 6 is set: picks a new direction among the unblocked ones (random from hRngCounter)
    ldh a, [hEnemyDir]
    bit 6, a
    ret z
    ld hl, hEnemyDir
    res 6, [hl]
    ldh a, [hEnemyBlocked]
    ld e, a
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld c, a
    ld hl, D_00_3aa2
    call LookupByte
    or a, e
    cp a, $0f
    jr z, .L_00_3a67
.L_00_3a37:
    call NextRandomDirection
    ldh a, [hRngCounter]
    and a, $0f
    ld b, a
    ldh a, [hEnemyBlocked]
    cpl
    and a, $0f
    and a, b
    ld c, a
    jr z, .L_00_3a37
    ld a, $08
    cp a, c
    jr z, .L_00_3a5f
    ld a, $04
    cp a, c
    jr z, .L_00_3a5f
    ld a, $02
    cp a, c
    jr z, .L_00_3a5f
    ld a, $01
    cp a, c
    jr z, .L_00_3a5f
    jp .L_00_3a37
.L_00_3a5f:
    ldh a, [hEnemyDir]
    and a, $f0
    or a, c
    ldh [hEnemyDir], a
    ret
.L_00_3a67:
    ldh a, [hEnemyBlocked]
    cpl
    and a, $0f
    ld b, a
    ldh a, [hEnemyDir]
    and a, $f0
    or a, b
    ldh [hEnemyDir], a
    ret
EnemyInitMoveAnim::  ; sets counter $20 and picks the first animation by enemy kind 6 or 8 or default (name provisional)
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $04
    ldh [hEnemyBoxHalf], a
    ldh a, [hEnemyKind]
    cp a, $06
    jr z, .L_00_3a90
    cp a, $08
    jr z, .L_00_3a99
    ld de, D_00_3aa6
    call SetObjectAnimation
    jp EnemySnapToGrid
.L_00_3a90:
    ld de, D_00_3acf
    call SetObjectAnimation
    jp EnemySnapToGrid
.L_00_3a99:
    ld de, D_00_3ad9
    call SetObjectAnimation
    jp EnemySnapToGrid
D_00_3aa2::
    INCBIN "assets/bank_00/3aa2.bin"
D_00_3aa6::
    INCBIN "assets/bank_00/3aa6.bin"
D_00_3aab::
    INCBIN "assets/bank_00/3aab.bin"
D_00_3ab0::
    INCBIN "assets/bank_00/3ab0.bin"
D_00_3ab5::
    INCBIN "assets/bank_00/3ab5.bin"
D_00_3aba::
    INCBIN "assets/bank_00/3aba.bin"
D_00_3abf::
    INCBIN "assets/bank_00/3abf.bin"
D_00_3ac4::
    INCBIN "assets/bank_00/3ac4.bin"
D_00_3aca::
    INCBIN "assets/bank_00/3aca.bin"
D_00_3acf::
    INCBIN "assets/bank_00/3acf.bin"
D_00_3ad4::
    INCBIN "assets/bank_00/3ad4.bin"
D_00_3ad9::
    INCBIN "assets/bank_00/3ad9.bin"
D_00_3ade::
    INCBIN "assets/bank_00/3ade.bin"
D_00_3ae3::
    INCBIN "assets/bank_00/3ae3.bin"
D_00_3aed::
    INCBIN "assets/bank_00/3aed.bin"
EnemyKind1::  ; enemy kind 1: ticks the object timer then moves on the tile grid
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3b02
    jp EnemyInitAnim3bbe
.L_00_3b02:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call EnemyGridStep
    call EnemyEdgeBlockedDirs
    call EnemyChooseDirection
    call EnemyFlagOnPaintedTile
    ldh a, [hEnemyFlags]
    bit 1, a
    jr z, .L_00_3b26
    ld hl, hEnemyCounter
    inc [hl]
    ld a, [hl]
    and a, $08
    ret z
.L_00_3b26:
    call EnemyTurnOrAnimate
    call EnemyPaintStep
    call EnemyPaintUnderB0M
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call SetEnemyAnimation
    jp DrawObject
EnemyAuxCounterStep::  ; when hEnemyFlags bit 0 is set clears it and steps hEnemyAux up to $80 (name provisional)
    ldh a, [hEnemyFlags]
    bit 0, a
    ret z
    set 0, a
    ldh [hEnemyFlags], a
    ldh a, [hEnemyAux]
    cp a, $80
    jr z, .L_00_3b4e
    inc a
    ldh [hEnemyAux], a
    ret
.L_00_3b4e:
    ld hl, hEnemyFlags
    res 0, [hl]
    xor a, a
    ldh [hEnemyAux], a
    ret
SetEnemyAnimation::  ; SelectEnemyAnimation then SetAnimationVariant
    call SelectEnemyAnimation
    jp SetAnimationVariant
SelectEnemyAnimation::  ; chooses the animation pointers from hEnemyDir (and flips the sprite)
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_00_3b74
    bit 1, a
    jr nz, .L_00_3b82
    bit 2, a
    jr nz, .L_00_3b90
    ld de, D_00_3bbe
    ld bc, D_00_3bc3
    jp SetAnimationVariant
.L_00_3b74:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3bc8
    ld bc, D_00_3bcd
    jp SetAnimationVariant
.L_00_3b82:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3bc8
    ld bc, D_00_3bcd
    jp SetAnimationVariant
.L_00_3b90:
    ld de, D_00_3bd2
    ld bc, D_00_3bd7
    jp SetAnimationVariant
EnemyFlagOnPaintedTile::  ; sets hEnemyFlags bit 1 when the tile under the enemy has a zero low nibble else clears it (name provisional)
    call EnemyTileUnder
    and a, $0f
    or a, a
    jr nz, .L_00_3ba7
    ld hl, hEnemyFlags
    set 1, [hl]
    ret
.L_00_3ba7:
    ld hl, hEnemyFlags
    res 1, [hl]
    ret
EnemyInitAnim3bbe::  ; hEnemySpeed 5 and counter $20; animation at $3bbe; snaps to the grid (name provisional)
    ld a, $05
    ldh [hEnemySpeed], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld de, D_00_3bbe
    call SetObjectAnimation
    jp EnemySnapToGrid
D_00_3bbe::
    INCBIN "assets/bank_00/3bbe.bin"
D_00_3bc3::
    INCBIN "assets/bank_00/3bc3.bin"
D_00_3bc8::
    INCBIN "assets/bank_00/3bc8.bin"
D_00_3bcd::
    INCBIN "assets/bank_00/3bcd.bin"
D_00_3bd2::
    INCBIN "assets/bank_00/3bd2.bin"
D_00_3bd7::
    INCBIN "assets/bank_00/3bd7.bin"
EnemyKind11::  ; enemy kind 11 (rounds 5 6 9 11 and the same rounds +16)
    call TickObjectTimer
    jr nz, .L_00_3be4
    jp EnemyKind7Start
.L_00_3be4:
    ldh a, [hEnemyFlags]
    bit 2, a
    jr z, .L_00_3bfb
    ldh a, [hEnemyDir]
    bit 1, a
    jp nz, EnemyDefeated
    set 1, a
    ldh [hEnemyDir], a
    call EnemyStoreAuxToTile
    jp EnemyDefeated
.L_00_3bfb:
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_00_3c09
    call EnemyClearTileSaveStep
    ld hl, hEnemyDir
    set 0, [hl]
.L_00_3c09:
    ldh a, [hEnemyTimer]
    sub a, $01
    ldh [hEnemyTimer], a
    jr nc, .L_00_3c1a
    call EnemyMapTile
    ldh a, [hEnemyAux]
    ld [hl], a
    jp RemoveEnemy
.L_00_3c1a:
    ld a, [wActiveMagic]
    cp a, $04
    jp nz, .L_00_3c2b
    ld a, [wMagicState]
    bit 0, a
    jr z, .L_00_3c2b
    jr .L_00_3c3a
.L_00_3c2b:
    ld a, [wActiveMagic]
    cp a, $06
    jp nz, .L_00_3c42
    ld a, [wMagicState]
    bit 0, a
    jr z, .L_00_3c42
.L_00_3c3a:
    call EnemyMapTile
    ldh a, [hEnemyAux]
    ld [hl], a
    jr .L_00_3c45
.L_00_3c42:
    call EnemyClearTileSaveStep
.L_00_3c45:
    call EnemyKind7SetAnimation
    call SelectObject2
    jp DrawObject
EnemyKind7SetAnimation::  ; animation pair at $3c87 and $3c8c (name provisional)
    ld de, AnimFrames0_3c87
    ld bc, D_00_3c8c
    jp SetAnimationVariant
EnemyKind7Start::  ; counter $20; hEnemyAux = map tile under the enemy; $ffcb = $fe; hEnemyDir = $90; animation $3c87 (name provisional)
    ld a, $20
    ldh [hEnemyCounter], a
    call EnemyMapTile
    ldh [hEnemyAux], a
    ld a, $fe
    ldh [hEnemyTimer], a
    ld a, $90
    ldh [hEnemyDir], a
    ld de, AnimFrames0_3c87
    jp SetObjectAnimation
EnemyStoreAuxToTile::  ; stores hEnemyAux into the map cell under the enemy (name provisional)
    call EnemyMapTile
    ldh a, [hEnemyAux]
    ld [hl], a
    ret
EnemyClearTileSaveStep::  ; hEnemyStep = map tile under the enemy and clears that cell (name provisional)
    call EnemyMapTile
    ldh [hEnemyStep], a
    xor a, a
    ld [hl], a
    ret
EnemyMapTile::  ; A = room map tile at the enemy position (X to column
    ldh a, [hEnemyX]
    call PixelXToColumn
    ldh a, [hEnemyY]
    jp LookupMapTile
AnimFrames0_3c87::  ; animation frames (typed text form)
    INCBIN "assets/bank_00/3c87_AnimFrames0_3c87.bin"
D_00_3c8c::
    INCBIN "assets/bank_00/3c8c.bin"
EnemyKind7::  ; enemy kind 7 (round 5-7 and 21-23): follows a scripted path from $c533
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3c9c
    jp EnemyKind7Init
.L_00_3c9c:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyKind7NextStep
    call MoveAndApplyObject
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call EnemyKind7Update
    jp DrawObject
EnemyKind7Update::  ; state step of enemy kind 7 following the path (name provisional)
    ldh a, [hEnemyDir]
    bit 0, a
    jr z, .L_00_3ccd
    ldh a, [hEnemyAux]
    and a, a
    jp z, .L_00_3d15
    dec a
    ldh [hEnemyAux], a
    ld de, D_00_3aca
    ld bc, D_00_3e4d
    jp SetAnimationVariant
.L_00_3ccd:
    ldh a, [hObject2]
    set 5, a
    set 6, a
    ldh [hObject2], a
    ldh a, [hEnemyCounter]
    cp a, $00
    jr z, .L_00_3ce7
    cp a, $08
    jr z, .L_00_3cf5
    cp a, $10
    jr z, .L_00_3d03
    cp a, $18
    jr z, .L_00_3d0c
.L_00_3ce7:
    ld hl, hObject2
    res 6, [hl]
    ld de, D_00_3e4d
    ld bc, D_00_3e52
    jp SetAnimationVariant
.L_00_3cf5:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3e57
    ld bc, D_00_3e5c
    jp SetAnimationVariant
.L_00_3d03:
    ld de, D_00_3e4d
    ld bc, D_00_3e52
    jp SetAnimationVariant
.L_00_3d0c:
    ld de, D_00_3e57
    ld bc, D_00_3e5c
    jp SetAnimationVariant
.L_00_3d15:
    jp RemoveEnemy
EnemyKind7NextStep::  ; reads the next path entry from wEnemyPathPtr (name provisional)
    ldh a, [hEnemyDir]
    bit 0, a
    ret nz
    ld a, [wActiveMagic]
    cp a, $03
    jr nz, .L_00_3d2b
    ld a, [wMagicState]
    bit 0, a
    jr nz, .L_00_3d54
.L_00_3d2b:
    ld a, $05
    ldh [hEnemySpeed], a
.L_00_3d2f:
    ld a, [wEnemyPathPtr]
    ld l, a
    ld a, [wEnemyPathPtrHi]
    ld h, a
    ld a, [hl]
    cp a, $01
    jp z, .L_00_3d4b
    ldh [hEnemyCounter], a
    ldh [hEnemyAngle], a
    inc hl
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [wEnemyPathPtrHi], a
    ret
.L_00_3d4b:
    ld hl, hEnemyDir
    set 0, [hl]
    xor a, a
    ldh [hEnemySpeed], a
    ret
.L_00_3d54:
    xor a, a
    ldh [hEnemySpeed], a
    ld a, [wEnemyPathPtr]
    ld l, a
    ld a, [wEnemyPathPtrHi]
    ld h, a
    dec hl
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [wEnemyPathPtrHi], a
    jr .L_00_3d2f
D_00_3d6a::
    dw D_00_3d6e
    dw D_00_3dc7
D_00_3d6e::
    INCBIN "assets/bank_00/3d6e.bin"
D_00_3dc7::
    INCBIN "assets/bank_00/3dc7.bin"
EnemyKind7Init::  ; sets hEnemySpeed 5 and counter $20 with animation $3e4d then follows the path table at $3d6a (name provisional)
    ld a, $05
    ldh [hEnemySpeed], a
    ld a, $20
    ldh [hEnemyCounter], a
    ldh [hEnemyAux], a
    ld hl, hObject2
    set 6, [hl]
    ld de, D_00_3e4d
    call SetObjectAnimation
    call EnemySnapToGrid
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld hl, D_00_3d6a
    call LookupWord
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [wEnemyPathPtrHi], a
    ret
D_00_3e4d::
    INCBIN "assets/bank_00/3e4d.bin"
D_00_3e52::
    INCBIN "assets/bank_00/3e52.bin"
D_00_3e57::
    INCBIN "assets/bank_00/3e57.bin"
D_00_3e5c::
    INCBIN "assets/bank_00/3e5c.bin"
EnemyKind5::  ; enemy kind 5
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3e6c
    jp EnemyBuildTeleportTable
.L_00_3e6c:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    ld a, [wActiveMagic]
    cp a, $06
    jr nz, .L_00_3e81
    ld a, [wMagicState]
    bit 0, a
    jr nz, .L_00_3e84
.L_00_3e81:
    call CheckEnemyTouchesPlayer
.L_00_3e84:
    call CheckPaintHitsEnemy
    call EnemyIdleAnimate
    call EnemyKind7Teleport
    jp DrawObject
EnemyIdleAnimate::  ; counts hEnemyCounter to $a0 with animation D_00_3f3a then sets hEnemyDir bit 1 (name provisional)
    ldh a, [hEnemyDir]
    bit 1, a
    jr nz, .L_00_3eb0
    ldh a, [hEnemyCounter]
    cp a, $a0
    jr z, .L_00_3ea8
    inc a
    ldh [hEnemyCounter], a
    ld de, D_00_3f3a
    ld bc, D_00_3f3f
    jp SetAnimationVariant
.L_00_3ea8:
    xor a, a
    ldh [hEnemyCounter], a
    ld hl, hEnemyDir
    set 1, [hl]
.L_00_3eb0:
    ldh a, [hEnemyCounter]
    cp a, $50
    jr z, .L_00_3ecb
    inc a
    ldh [hEnemyCounter], a
    ldh a, [hEnemyTick]
    and a, $04
    jr z, .L_00_3ec5
    ld de, D_00_3f3a
    jp SetObjectAnimationStub
.L_00_3ec5:
    ld de, D_00_3aca
    jp SetObjectAnimationStub
.L_00_3ecb:
    ld hl, hEnemyDir
    set 0, [hl]
    ret
EnemyKind7Teleport::  ; moves the enemy to the next position in the table at $c489 or removes it (name provisional)
    ldh a, [hEnemyDir]
    bit 0, a
    ret z
    ld a, $02
    ldh [hEnemyBoxHalf], a
    ldh a, [hEnemyStep]
    sla a
    ld c, a
    ld b, $00
    ld hl, $c489
    add hl, bc
    ld a, [hl+]
    or a, a
    jp z, RemoveEnemy
    ldh [hEnemyX], a
    ld a, [hl]
    ldh [hEnemyY], a
    ld hl, hEnemyStep
    inc [hl]
    ld de, D_00_3f44
    jp SetObjectAnimation
EnemyBuildTeleportTable::  ; fills the position table at $c489 around the enemy (+-$10) (name provisional)
    ld a, $20
    ldh [hEnemyCounter], a
    ldh a, [hEnemyX]
    ld [$c48b], a
    ld [$c48f], a
    ld [$c491], a
    sub a, $10
    ld [$c489], a
    ldh a, [hEnemyX]
    add a, $10
    ld [$c48d], a
    ldh a, [hEnemyY]
    ld [$c48a], a
    ld [$c48e], a
    ld [$c492], a
    sub a, $10
    ld [$c48c], a
    ldh a, [hEnemyY]
    add a, $10
    ld [$c490], a
    xor a, a
    ld [$c493], a
    ld de, D_00_3f3a
    call SetObjectAnimation
    ld a, $90
    ldh [hEnemyDir], a
    ret
D_00_3f3a::
    INCBIN "assets/bank_00/3f3a.bin"
D_00_3f3f::
    INCBIN "assets/bank_00/3f3f.bin"
D_00_3f44::
    INCBIN "assets/bank_00/3f44.bin"
SoundPitchTables::  ; pointers to the pitch tables used by SoundSetFrequency (the first word is not a pointer)
    dw $cecd
    dw D_00_3f56
    dw D_00_3f95
    dw D_00_3f9e
    dw D_00_3faf
D_00_3f56::
    dw RstVector00
    INCBIN "assets/bank_00/3f58.bin"
D_00_3f95::
    INCBIN "assets/bank_00/3f95.bin"
D_00_3f9e::
    INCBIN "assets/bank_00/3f9e.bin"
D_00_3faf::
    INCBIN "assets/bank_00/3faf.bin"
D_00_3fb8::
    INCBIN "assets/bank_00/3fb8.bin"

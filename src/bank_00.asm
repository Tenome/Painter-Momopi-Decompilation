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
    ld hl, $4000
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
    ld hl, $4000
    jr L_00_01f4
LoadTilesBank3B::  ; bank 3 $5000 0x1000 bytes to $8000
    ld hl, $5000
    jr L_00_01f4
LoadTilesBank3D::  ; bank 3 $6e10 0x1000 bytes to $8000
    ld hl, $6e10
L_00_01f4::
    ld bc, $1000
    jr LoadTilesBank3
LoadTilesBank3C::  ; bank 3 $6000 0xe10 bytes to $8000
    ld hl, $6000
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
    ld [$c7bf], a
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
L_00_0498::
    dec a
    jr nz, L_00_0498
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
L_00_04fc::
    ld a, $ff
    ld [hl-], a
    dec bc
    ld a, b
    or a, c
    jr nz, L_00_04fc
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
L_00_051d::
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
    ld hl, $c7c0
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
ObjectShapeTable::  ; word pointers indexed by shape id; each shape = count then count pairs of signed (y x) offsets of 8x8 parts (read by DrawObject)
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
    jp z, L_00_09aa
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
    jp z, L_00_09aa
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
L_00_09aa::
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
L_00_09d1::
    ld e, $06
    ld a, e
    ldh [hScratch00], a
    ld e, $08
    ld a, e
    ldh [hScratch01], a
    call L_00_0a13
    jr L_00_0a13
ClampObjectToRoom::  ; keeps the object inside the room limits after MoveObject (offsets $06 and $0c)
    ld e, $06
    ld a, e
    ldh [hScratch00], a
    ld e, $0c
    ld a, e
    ldh [hScratch01], a
    call L_00_09ed
L_00_09ed::
    and a, a
    call L_00_0a13
    call L_00_0a13
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
L_00_0a13::
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
L_00_0a3f::
    dec b
    dec b
    inc b
    inc b
    jr L_00_0a5d
    INCBIN "assets/bank_00/0a45.bin"
SerialSendByte::  ; sends C over the link port with the internal clock and waits for the reply
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    ld a, c
    ld [rSB], a
    ld a, [rSC]
    set 0, a
    ld [rSC], a
L_00_0a5d::
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
    ldh a, [$ffb9]
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
    ld hl, $0a3f
    add hl, de
    ld a, [hl]
    ld hl, $0a3f
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
MoveObject::  ; applies the object's direction (+$10) and speed (+$11) from D_00_0bb6 to its position with MultiplyByDE
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
    ld hl, D_00_0bb6
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
D_00_0bb6::
    INCBIN "assets/bank_00/0bb6.bin"
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
    dw D_00_0d7f
    dw D_00_0da5
    dw D_00_0dd0
    dw D_00_0dff
    dw D_00_0e25
    dw D_00_0e4b
    dw D_00_0e75
    dw D_00_0ea8
    dw D_00_0ec1
    dw D_00_0eee
    dw D_00_0f0b
    dw D_00_0f30
    dw D_00_0f56
    dw D_00_0f73
    dw D_00_0f94
    dw D_00_0fbd
    dw D_00_0d7f
    dw D_00_0da5
    dw D_00_0dd0
    dw D_00_0dff
    dw D_00_0e25
    dw D_00_0e4b
    dw D_00_0e75
    dw D_00_0ea8
    dw D_00_0ec1
    dw D_00_0eee
    dw D_00_0f0b
    dw D_00_0f30
    dw D_00_0f56
    dw D_00_0f73
    dw D_00_0f94
    dw D_00_0fbd
    dw D_00_0fda
D_00_0d7f::
    INCBIN "assets/bank_00/0d7f.bin"
D_00_0da5::
    INCBIN "assets/bank_00/0da5.bin"
D_00_0dd0::
    INCBIN "assets/bank_00/0dd0.bin"
D_00_0dff::
    INCBIN "assets/bank_00/0dff.bin"
D_00_0e25::
    INCBIN "assets/bank_00/0e25.bin"
D_00_0e4b::
    INCBIN "assets/bank_00/0e4b.bin"
D_00_0e75::
    INCBIN "assets/bank_00/0e75.bin"
D_00_0ea8::
    INCBIN "assets/bank_00/0ea8.bin"
D_00_0ec1::
    INCBIN "assets/bank_00/0ec1.bin"
D_00_0eee::
    INCBIN "assets/bank_00/0eee.bin"
D_00_0f0b::
    INCBIN "assets/bank_00/0f0b.bin"
D_00_0f30::
    INCBIN "assets/bank_00/0f30.bin"
D_00_0f56::
    INCBIN "assets/bank_00/0f56.bin"
D_00_0f73::
    INCBIN "assets/bank_00/0f73.bin"
D_00_0f94::
    INCBIN "assets/bank_00/0f94.bin"
D_00_0fbd::
    INCBIN "assets/bank_00/0fbd.bin"
D_00_0fda::
    INCBIN "assets/bank_00/0fda.bin"
AddScore::  ; adds to the BCD score digits at wScoreDigits
    ld bc, $0000
    ld hl, wScoreDigits
    ld a, e
    add a, [hl]
    ld [$c47a], a
    call ByteToBCD
    ldh a, [hScratch03]
    and a, a
    jr z, .L_00_1027
    inc d
    ld a, [$c47a]
    sub a, $64
    ld [$c47a], a
.L_00_1027:
    ld a, [$c47a]
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
    ld [$c46d], a
    ld a, $01
    ld [$c46e], a
    ld a, [$c467]
    call L_00_10a2
    ld [$c46f], a
    ld a, [$c468]
    call L_00_10a2
    ld [$c470], a
    ld a, [$c469]
    call L_00_10a2
    ld [$c471], a
    ld a, [$c46a]
    call L_00_10a2
    ld [$c472], a
    ld a, [$c46b]
    call L_00_10a2
    ld [$c473], a
    ld a, [$c46c]
    call L_00_10a2
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
    ld hl, $c467
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
L_00_10a2::
    and a, $0f
L_00_10a4::
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
    ld [$c7c0], a
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
    ld a, [$c51f]
    bit 2, a
    jr nz, .L_00_1138
    set 2, a
    ld [$c51f], a
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
    ldh [$ffe3], a
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
    ld a, [$c51f]
    bit 1, a
    jr nz, .L_00_11c6
    ld a, [$c465]
    cp a, $02
    ret c
    ld hl, $c51f
    set 1, [hl]
.L_00_11c6:
    ld a, [$c46a]
    ld d, a
    ld a, [$c488]
    cp a, $05
    jr nz, .L_00_11d5
    xor a, a
    ld [$c488], a
.L_00_11d5:
    ld c, a
    ld hl, $11e7
    call LookupByte
    cp a, d
    ret nz
    ld hl, wLives
    inc [hl]
    ld hl, $c488
    inc [hl]
    ret
L_00_11e7::
    ld [bc], a
    inc b
    ld b, $08
    nop
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
    ld bc, $1a94
    call RunVramCopyList
    ld bc, $1a57
    call RunVramCopyList
    ld bc, $0010
    ld hl, $9cd0
    call L_00_04fc
    xor a, a
    ld [$c463], a
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
    ld de, $c46d
    call VramCopyStream
    ld a, [wMagicPointsHi]
    ld c, a
    ld a, [wMagicPoints]
    call ByteToBCD
    ldh a, [hScratch02]
    and a, $0f
    call L_00_10a4
    ld [$c450], a
    ldh a, [hScratch02]
    swap a
    and a, $0f
    call L_00_10a4
    ld [$c44f], a
    ldh a, [hScratch03]
    call L_00_10a4
    ld [$c44e], a
    ld a, $03
    ld [$c44c], a
    ld a, $01
    ld [$c44d], a
    ld hl, $9ca5
    ld de, $c44c
    call VramCopyStream
    ldh a, [hTimeSeconds]
    ld c, $00
    call ByteToBCD
    ldh a, [hScratch02]
    and a, $0f
    call L_00_10a4
    ld [$ffe8], a
    ldh a, [hScratch02]
    swap a
    and a, $0f
    call L_00_10a4
    ld [$ffe7], a
    ldh a, [hScratch03]
    call L_00_10a4
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
L_00_132c::
    ldh a, [hScratch00]
    sub a, $64
    ld d, a
    jr c, .L_00_1338
    ldh [hScratch00], a
    jp L_00_1409
.L_00_1338:
    ld a, e
    and a, a
    jr z, .L_00_1344
    ld a, d
    ldh [hScratch00], a
    ld e, $00
    jp L_00_1409
.L_00_1344:
    ldh a, [hScratch00]
    and a, a
    jr z, .L_00_1371
    cp a, $0a
    jr z, .L_00_1364
    sub a, $14
    ldh [hScratch00], a
    ld a, [$c463]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $b8
    ld [hl], a
    ld hl, $c463
    inc [hl]
    jr .L_00_1344
.L_00_1364:
    ld a, [$c463]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $a8
    ld [hl], a
.L_00_1371:
    ld a, $10
    ld [$c451], a
    ld a, $01
    ld [$c452], a
    ld hl, $9cc2
    ld de, $c451
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
    ld hl, $1400
    call LookupByte
    call PlaySound
    ld hl, hVBlankTasks
    set 4, [hl]
    ret
L_00_1400::
    add a, [hl]
    add a, [hl]
    add a, a
    add a, a
    adc a, b
    add a, [hl]
    add a, [hl]
    add a, a
    add a, a
L_00_1409::
    ld a, [$c463]
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
    ld a, [$c463]
    add a, $05
    ld [$c463], a
    jp L_00_132c
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
    ld [$c488], a
    ld [wScoreDigits], a
    ld [$c465], a
    ld [$c466], a
    ld [$c467], a
    ld [$c468], a
    ld [$c469], a
    ld [$c46a], a
    ld [$c46b], a
    ld [$c46c], a
    ld a, $06
    ld [$c46d], a
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
    dw D_00_151b
    dw D_00_1538
    dw D_00_1551
    dw D_00_1637
    dw D_00_156a
    dw D_00_1583
    dw D_00_1598
    dw D_00_1640
    dw D_00_15b1
    dw D_00_15d7
    dw D_00_15c2
    dw D_00_1637
    dw D_00_15f0
    dw D_00_1609
    dw D_00_161e
    dw D_00_1640
    dw D_00_1649
D_00_151b::
    INCBIN "assets/bank_00/151b.bin"
D_00_1538::
    INCBIN "assets/bank_00/1538.bin"
D_00_1551::
    INCBIN "assets/bank_00/1551.bin"
D_00_156a::
    INCBIN "assets/bank_00/156a.bin"
D_00_1583::
    INCBIN "assets/bank_00/1583.bin"
D_00_1598::
    INCBIN "assets/bank_00/1598.bin"
D_00_15b1::
    INCBIN "assets/bank_00/15b1.bin"
D_00_15c2::
    INCBIN "assets/bank_00/15c2.bin"
D_00_15d7::
    INCBIN "assets/bank_00/15d7.bin"
D_00_15f0::
    INCBIN "assets/bank_00/15f0.bin"
D_00_1609::
    INCBIN "assets/bank_00/1609.bin"
D_00_161e::
    INCBIN "assets/bank_00/161e.bin"
D_00_1637::
    INCBIN "assets/bank_00/1637.bin"
D_00_1640::
    INCBIN "assets/bank_00/1640.bin"
D_00_1649::
    INCBIN "assets/bank_00/1649.bin"
RoomMetatileTable::  ; 17 pointers to metatile definitions per room theme
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20a7
    dw D_00_20b7
    dw D_00_20b7
    dw D_00_20b7
    dw D_00_20a7
    dw D_00_20c7
    dw D_00_20c7
    dw D_00_20c7
    dw D_00_20a7
    dw D_00_20c7
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
    dw D_00_20d7
    dw D_00_2117
    dw D_00_2157
    dw D_00_2197
    dw D_00_21d7
    dw D_00_2217
    dw D_00_2257
    dw D_00_2297
    dw D_00_22d7
    dw D_00_2317
    dw D_00_2357
    dw D_00_2197
    dw D_00_2397
    dw D_00_23d7
    dw D_00_2417
    dw D_00_2297
    dw D_00_2457
CursorBlinkStep::  ; counts $c47d to $50 and toggles the cursor animation between D_00_1a17 and D_00_1a30
    ld a, [wMagicScreenFlags]
    bit 2, a
    ret z
    ld a, [$c47d]
    cp a, $50
    jr nc, L_00_1769
    inc a
    ld [$c47d], a
    ld a, [$c769]
    and a, $04
    jr nz, L_00_175d
    ld hl, D_00_1a17
    jr SetCursorAnimation
L_00_175d::
    ld hl, D_00_1a30
SetCursorAnimation::  ; HL = animation pointer stored in the cursor object record ($c74f/$c750 = wCursorObject +1/+2)
    ld a, l
    ld [$c74f], a
    ld a, h
    ld [$c750], a
    ret
L_00_1769::
    ld hl, wMagicScreenFlags
    res 2, [hl]
    jr L_00_175d
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
    jp z, L_00_196f
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
L_00_196f::
    ld [wMagicRow], a
    ret
InitMagicScreenState::  ; clears the cursor and card variables and creates the cursor object at wCursorObject
    xor a, a
    ld [wMagicCol], a
    ld [wMagicRow], a
    ld [$c47d], a
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
    dw D_00_1c1b
    dw D_00_1c21
    dw D_00_1c27
    dw D_00_1c2d
    dw D_00_1c33
    dw D_00_1c3f
    dw D_00_1c39
    dw D_00_1c4b
    dw D_00_1c51
    dw D_00_1c45
MagicCardPictureJobs::  ; 10 pointers to the card picture VRAM jobs
    dw D_00_1b67
    dw D_00_1b9d
    dw D_00_1bc1
    dw D_00_1b8b
    dw D_00_1c09
    dw D_00_1be5
    dw D_00_1baf
    dw D_00_1b79
    dw D_00_1bf7
    dw D_00_1bd3
MagicCardCostJobs::  ; 10 pointers to the MP cost VRAM jobs
    dw D_00_1c1b
    dw D_00_19e1
    dw D_00_19e7
    dw D_00_19ed
    dw D_00_19f3
    dw D_00_19f9
    dw D_00_19ff
    dw D_00_1a05
    dw D_00_1a0b
    dw D_00_1a11
D_00_19e1::
    INCBIN "assets/bank_00/19e1.bin"
D_00_19e7::
    INCBIN "assets/bank_00/19e7.bin"
D_00_19ed::
    INCBIN "assets/bank_00/19ed.bin"
D_00_19f3::
    INCBIN "assets/bank_00/19f3.bin"
D_00_19f9::
    INCBIN "assets/bank_00/19f9.bin"
D_00_19ff::
    INCBIN "assets/bank_00/19ff.bin"
D_00_1a05::
    INCBIN "assets/bank_00/1a05.bin"
D_00_1a0b::
    INCBIN "assets/bank_00/1a0b.bin"
D_00_1a11::
    INCBIN "assets/bank_00/1a11.bin"
D_00_1a17::
    INCBIN "assets/bank_00/1a17.bin"
D_00_1a30::
    INCBIN "assets/bank_00/1a30.bin"
D_00_1b67::
    INCBIN "assets/bank_00/1b67.bin"
D_00_1b79::
    INCBIN "assets/bank_00/1b79.bin"
D_00_1b8b::
    INCBIN "assets/bank_00/1b8b.bin"
D_00_1b9d::
    INCBIN "assets/bank_00/1b9d.bin"
D_00_1baf::
    INCBIN "assets/bank_00/1baf.bin"
D_00_1bc1::
    INCBIN "assets/bank_00/1bc1.bin"
D_00_1bd3::
    INCBIN "assets/bank_00/1bd3.bin"
D_00_1be5::
    INCBIN "assets/bank_00/1be5.bin"
D_00_1bf7::
    INCBIN "assets/bank_00/1bf7.bin"
D_00_1c09::
    INCBIN "assets/bank_00/1c09.bin"
D_00_1c1b::
    INCBIN "assets/bank_00/1c1b.bin"
D_00_1c21::
    INCBIN "assets/bank_00/1c21.bin"
D_00_1c27::
    INCBIN "assets/bank_00/1c27.bin"
D_00_1c2d::
    INCBIN "assets/bank_00/1c2d.bin"
D_00_1c33::
    INCBIN "assets/bank_00/1c33.bin"
D_00_1c39::
    INCBIN "assets/bank_00/1c39.bin"
D_00_1c3f::
    INCBIN "assets/bank_00/1c3f.bin"
D_00_1c45::
    INCBIN "assets/bank_00/1c45.bin"
D_00_1c4b::
    INCBIN "assets/bank_00/1c4b.bin"
D_00_1c51::
    INCBIN "assets/bank_00/1c51.bin"
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
    ld bc, $1d90
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
    call L_01_492f
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
    ld [$c486], a
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
    dw D_00_1d5b
    dw D_00_1d5b
    dw D_00_1d5b
    dw D_00_1d7e
    dw D_00_1d64
    dw D_00_1d64
    dw D_00_1d64
    dw D_00_1d7e
    dw D_00_1d6c
    dw D_00_1d6c
    dw D_00_1d6c
    dw D_00_1d7e
    dw D_00_1d75
    dw D_00_1d75
    dw D_00_1d75
    dw D_00_1d7e
    dw D_00_1d87
D_00_1d5b::
    INCBIN "assets/bank_00/1d5b.bin"
D_00_1d64::
    INCBIN "assets/bank_00/1d64.bin"
D_00_1d6c::
    INCBIN "assets/bank_00/1d6c.bin"
D_00_1d75::
    INCBIN "assets/bank_00/1d75.bin"
D_00_1d7e::
    INCBIN "assets/bank_00/1d7e.bin"
D_00_1d87::
    INCBIN "assets/bank_00/1d87.bin"
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
    ld bc, $1e2e
    call RunVramCopyList
    jr .L_00_1dec
.L_00_1de6:
    ld bc, $1e57
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
    INCBIN "assets/bank_00/1e2e.bin"
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
    ld hl, $c51f
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
    ld bc, $2085
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
    ld [$c44c], a
    ld a, $01
    ld [$c44d], a
    ld a, $cd
    ld [$c44e], a
    ld a, $ce
    ld [$c44f], a
    jr .L_00_1f93
.L_00_1f82:
    ld a, $01
    ld [$c44c], a
    ld [$c44d], a
    ld a, [wContinues]
    call L_00_10a4
    ld [$c44e], a
.L_00_1f93:
    ld de, $c44c
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
    ld hl, $c51f
    res 2, [hl]
    ld hl, wContinues
    dec [hl]
    ld a, $03
    jp GameModeDispatch
.L_00_2050:
    xor a, a
    ld [rSB], a
    ldh [hSerialByte], a
    ld a, [$c7bf]
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
D_00_20a7::
    INCBIN "assets/bank_00/20a7.bin"
D_00_20b7::
    INCBIN "assets/bank_00/20b7.bin"
D_00_20c7::
    INCBIN "assets/bank_00/20c7.bin"
D_00_20d7::
    INCBIN "assets/bank_00/20d7.bin"
D_00_2117::
    INCBIN "assets/bank_00/2117.bin"
D_00_2157::
    INCBIN "assets/bank_00/2157.bin"
D_00_2197::
    INCBIN "assets/bank_00/2197.bin"
D_00_21d7::
    INCBIN "assets/bank_00/21d7.bin"
D_00_2217::
    INCBIN "assets/bank_00/2217.bin"
D_00_2257::
    INCBIN "assets/bank_00/2257.bin"
D_00_2297::
    INCBIN "assets/bank_00/2297.bin"
D_00_22d7::
    INCBIN "assets/bank_00/22d7.bin"
D_00_2317::
    INCBIN "assets/bank_00/2317.bin"
D_00_2357::
    INCBIN "assets/bank_00/2357.bin"
D_00_2397::
    INCBIN "assets/bank_00/2397.bin"
D_00_23d7::
    INCBIN "assets/bank_00/23d7.bin"
D_00_2417::
    INCBIN "assets/bank_00/2417.bin"
D_00_2457::
    INCBIN "assets/bank_00/2457.bin"
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
    ld bc, $270f
    ld hl, vBGMap0
    ld a, $ff
    ld [$c7c0], a
    call L_00_051d
    ld bc, $29b1
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
    ld a, [$c75a]
    ld hl, D_00_269b
    call LookupWord
    push hl
    pop de
    ld hl, $9886
    call VramCopyStream
    ld a, [$c75a]
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
    ld hl, $253b
    call LookupWord
    jp hl
L_00_253b::
    ld b, c
    dec h
    ld [hl], h
    dec h
    ld e, b
    dec h
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
    ld [$c75a], a
    jp Mode2_Init
.L_00_25c5:
    ld [$c75a], a
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
    dw D_00_28a3
    dw D_00_28fd
    dw D_00_2957
    INCBIN "assets/bank_00/270f.bin"
D_00_28a3::
    INCBIN "assets/bank_00/28a3.bin"
D_00_28fd::
    INCBIN "assets/bank_00/28fd.bin"
D_00_2957::
    INCBIN "assets/bank_00/2957.bin"
Mode0_Title::  ; title screen: 1 PLAYER / 2 PLAYER; link-cable detection via the serial port
    ld sp, wStackTop
    call LcdOff
    di
    call LoadTilesBank3A
    ld a, SND_MUSIC_TITLE
    call PlaySound
    ld hl, vBGMapLast
    call FillBackwardsFF
    ld bc, $2b86
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
    ld hl, $c49d
    dec [hl]
    ld a, [$c49d]
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
    ld [$c49d], a
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
    ld a, [$c7bf]
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
    ld hl, $2b84
    jp SetCursorAnimation
L_00_2b84::
    rlca
    or a, [hl]
    ld c, $04
    sbc a, b
    cp a, a
    dec hl
    ld h, a
    sbc a, b
    ldh [c], a
    dec hl
    add a, e
    sbc a, b
    add sp, 43
    jp L_00_0498
    INCBIN "assets/bank_00/2b96.bin"
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
    ld bc, $3156
    ld de, D_00_31a6
    ld a, $ff
    ld [$c7c0], a
    call DrawMetatileMap
    ld hl, wEndingObject
    ld bc, $0041
    call ClearMemory
    ld a, $80
    ld [wEndingObject], a
    ld [$c78e], a
    ld hl, D_00_3143
    ld a, h
    ld [$c770], a
    ld a, l
    ld [$c76f], a
    ld a, $80
    ld [$c775], a
    ld a, $68
    ld [$c778], a
    ld a, $04
    ld [$c77f], a
    ld a, $18
    ld [$c77e], a
    ld a, $70
    ld [$c795], a
    ld a, $68
    ld [$c798], a
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
    ld a, [$c7ae]
    bit 7, a
    jr z, .L_00_2d16
    call EndingSetup
    ld a, $10
    ld [wCheatFlags], a
    ld a, $05
    ld [$c49d], a
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
    ld a, [$c49d]
    dec a
    ld [$c49d], a
    bit 7, a
    jr z, .L_00_2d33
    jp Entry
EndingCreditsWindow::  ; when the scene is done: turns the window on (rWY/rWX) and starts the credit pages
    ld a, [$c7ae]
    bit 2, a
    ret z
    ld a, [$c78e]
    bit 0, a
    jr nz, .L_00_2d89
    ld a, $5a
    ld [rWY], a
    ld a, $a5
    ld [rWX], a
    ld a, [rLCDC]
    or a, $60
    ld [rLCDC], a
    ld hl, $c78e
    set 0, [hl]
    ld a, $ff
    ld [$c78f], a
    call EndingShowCreditsPage
.L_00_2d89:
    ld a, [$c78e]
    bit 2, a
    jr nz, .L_00_2dc1
    ld a, [$c78e]
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
    ld hl, $c78e
    set 1, [hl]
    ret
.L_00_2da9:
    ld a, [wCreditsPage]
    cp a, $08
    ret z
    ld hl, $c78f
    dec [hl]
    ret nz
    ld a, $ff
    ld [$c78f], a
    ld hl, $c78e
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
    ld [$c78e], a
    ld hl, wCreditsPage
    inc [hl]
    call EndingShowCreditsPage
    ret
EndingShowCreditsPage::  ; queues the credit page $c790 from CreditsPageTable
    call EndingScrollStep
    call L_00_2df1
    call EndingScrollStep
    ld a, [wCreditsPage]
    ld hl, CreditsPageTable
    call LookupWord
    call QueueVramCopyList
    jp WaitVramCopyDone
L_00_2df1::
    ld bc, $2dff
    call QueueVramCopyList
.L_00_2df7:
    ld a, [wVramCopyFlags]
    bit 0, a
    jr nz, .L_00_2df7
    ret
    INCBIN "assets/bank_00/2dff.bin"
CreditsPageTable::  ; 9 pointers to credit pages
    dw D_00_2e21
    dw D_00_2e2d
    dw D_00_2e88
    dw D_00_2ea7
    dw D_00_2ec6
    dw D_00_2e4c
    dw D_00_2e6c
    dw D_00_2ee5
    dw D_00_2eff
D_00_2e21::
    INCBIN "assets/bank_00/2e21.bin"
D_00_2e2d::
    INCBIN "assets/bank_00/2e2d.bin"
D_00_2e4c::
    INCBIN "assets/bank_00/2e4c.bin"
D_00_2e6c::
    INCBIN "assets/bank_00/2e6c.bin"
D_00_2e88::
    INCBIN "assets/bank_00/2e88.bin"
D_00_2ea7::
    INCBIN "assets/bank_00/2ea7.bin"
D_00_2ec6::
    INCBIN "assets/bank_00/2ec6.bin"
D_00_2ee5::
    INCBIN "assets/bank_00/2ee5.bin"
D_00_2eff::
    INCBIN "assets/bank_00/2eff.bin"
EndingTick::  ; one step of the ending scene: hero movement then the object animation
    call EndingMoveHero
    jp EndingAnimateObject
EndingMoveHero::  ; moves the hero in the ending scene until it reaches $c775 = $50
    call EndingHeroFrame
    ld a, [$c7ae]
    bit 2, a
    ret nz
    ld a, [$c775]
    cp a, $50
    jr z, .L_00_2f41
    dec a
    ld [$c775], a
    ret
.L_00_2f41:
    ld hl, $c7ae
    set 2, [hl]
    ret
EndingHeroFrame::  ; chooses the hero frame and flips it by $c782 bit 0
    ld a, $02
    ld [$c77f], a
    ld a, [$c782]
    bit 0, a
    jr nz, .L_00_2f59
    xor a, a
    ld [$c77e], a
    jr .L_00_2f5e
.L_00_2f59:
    ld a, $10
    ld [$c77e], a
.L_00_2f5e:
    call L_00_307f
    call MoveObject
    call ClampObjectToRoom
    ld hl, $c781
    dec [hl]
    ret nz
    ld a, $0a
    ld [$c781], a
    ld hl, $c782
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
    ld a, [$c7ae]
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
    ld a, [$c798]
    sub a, $5a
    ld [$c798], a
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
    ld bc, $30c4
    call RunVramCopyList
    ld a, $80
    ld [wEndingObject], a
    ld a, $c8
    ld [$c775], a
    ld a, $50
    ld [$c778], a
    ld a, $0a
    ld [$c781], a
    ld bc, $3009
    call RunVramCopyList
    xor a, a
    ld [rIF], a
    ld a, IE_VBLANK
    ld [rIE], a
    ld a, LCDC_ON_BG_OBJ
    ld [rLCDC], a
    ei
    ret
    INCBIN "assets/bank_00/3009.bin"
EndingWalkStep::  ; steps the walking animation counters at $c77e-$c780
    ld a, [$c778]
    cp a, $08
    jr c, EndingAdvance
    ld hl, $c780
    inc [hl]
    ld a, [hl]
    and a, $10
    jr z, .L_00_3070
    ld hl, $c77f
    inc [hl]
    ld hl, $c77e
    inc [hl]
    xor a, a
    ld [$c780], a
.L_00_3070:
    call L_00_307f
    call MoveObject
    call ClampObjectToRoom
    call L_00_307f
    jp DrawObject
L_00_307f::
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
    ld [$c78f], a
    ld a, [hl]
    ld [wCreditsPage], a
    ld hl, $c78e
    call SetObjPtr
    jp DrawObject
EndingAdvance::  ; advances $c781/$c782 by $10 per call; sets $c7ae bit 7 at 5
    ld a, [$c781]
    add a, $10
    ld [$c781], a
    ld a, [$c782]
    adc a, $00
    ld [$c782], a
    and a, a
    cp a, $05
    ret nz
    ld hl, $c7ae
    set 7, [hl]
    ret
    INCBIN "assets/bank_00/30c4.bin"
D_00_30df::
    INCBIN "assets/bank_00/30df.bin"
D_00_3111::
    INCBIN "assets/bank_00/3111.bin"
D_00_3143::
    INCBIN "assets/bank_00/3143.bin"
D_00_3148::
    INCBIN "assets/bank_00/3148.bin"
D_00_31a6::
    INCBIN "assets/bank_00/31a6.bin"
TickObjectTimer::  ; increments $ffd0; Z flag from bit 7 of $ffd1
    ld hl, hEnemyTick
    inc [hl]
    inc hl
    ld a, [hl]
    bit 7, a
    ret
L_00_31eb::
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
    ld [$c481], a
    ld a, h
    ld [$c482], a
    ld a, [hl]
    ld [$c485], a
    ld d, a
    ld a, [wSpawnIndex]
    dec a
    cp a, d
    jr nz, .L_00_3229
    ld hl, wSpawnWave
    inc [hl]
    ld a, $01
    ld [wSpawnIndex], a
    ld [$c486], a
.L_00_3229:
    ld a, [wPlayerStatus]
    bit 5, a
    jr nz, .L_00_324a
    ld hl, $c481
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
    ldh [$ffe9], a
    ld hl, wPlayerStatus
    set 5, [hl]
.L_00_324a:
    ldh a, [$ffe9]
    ld e, a
    ldh a, [hTimeSeconds]
    ld d, a
    ldh a, [$ffe3]
    sub a, e
    cp a, d
    ret c
    ld a, [wEnemyCount]
    cp a, $03
    ret nc
    ld hl, $c481
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
    ldh [$ffee], a
    jr .L_00_328e
.L_00_3289:
    ld a, [hl]
    and a, $01
    ldh [$ffee], a
.L_00_328e:
    ld hl, wSpawnIndex
    inc [hl]
    ld hl, $c486
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
    ld hl, $ffd3
    inc [hl]
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_32f3
    ld hl, $c4bc
    inc [hl]
.L_00_32f3:
    ld a, $0c
    ldh [hScratch06], a
    ld a, $02
    ldh [hScratch07], a
    ldh a, [$ffd3]
    ldh [hScratch08], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_330b
    ld a, [$c4bc]
    ldh [hScratch08], a
.L_00_330b:
    ld a, $03
    call CounterToFrame
    ldh a, [hScratch08]
    ldh [$ffd3], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_3320
    ldh a, [hScratch08]
    ld [$c4bc], a
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
    ld hl, $36c6
.L_00_333b:
    push hl
    ld a, l
    ldh [$ffb6], a
    ld a, h
    ldh [$ffb7], a
    call SelectObject2
    call DrawObject
    pop hl
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, .L_00_3361
    ld a, l
    ld [$c49f], a
    ld a, h
    ld [$c4a0], a
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
    ld hl, $33fd
    call LookupByte
    ld e, a
    ld d, $00
    call AddScore
    ld hl, wProjectile
    res 7, [hl]
    jp RemoveEnemy
L_00_33fd::
    dec b
    dec b
    rrca
    rrca
    nop
    dec b
    dec b
    dec b
    ld a, [bc]
    rrca
    rrca
    dec b
    rrca
    nop
    dec b
L_00_340c::
    ld a, $04
    ldh [$ffb9], a
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
L_00_352f::
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
L_00_3603::
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
    ldh [hEnemyAnimState], a
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
    ldh [$ffc5], a
    ret
D_00_363d::
    INCBIN "assets/bank_00/363d.bin"
MoveAndClampObject::  ; MoveObject then ClampObjectToRoom
    call MoveObject
    jp ClampObjectToRoom
SetAnimationVariant::  ; DE = BC when bit 3 of $ffd0 is set; then SetObjectAnimation
    ldh a, [hEnemyTick]
    and a, $08
    jr z, L_00_3651
    push bc
    pop de
L_00_3651::
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
    ldh [$ffb6], a
    ld a, d
    ldh [$ffb7], a
    ret
EnemyRequestTurn::  ; sets hEnemyDir bit 6 and clears the movement variables
    ld hl, hEnemyDir
    set 6, [hl]
    xor a, a
    ldh [hEnemyAnimState], a
    ldh [$ffc2], a
    ldh [$ffc4], a
    ret
EnemyTileUnder::  ; A = room map tile under the enemy (Y aligned to the grid)
    ldh a, [hEnemyX]
    call PixelXToColumn
    ldh a, [hEnemyY]
    and a, $f0
    add a, $08
    jp LookupMapTile
L_00_3681::
    ld hl, hEnemyX
    ld c, [hl]
    ld hl, hEnemyY
    ld b, [hl]
    ret
L_00_368a::
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
    call L_00_31eb
    xor a, a
    ld [wMagicState], a
    ld hl, wPlayerStatus
    set 3, [hl]
    ret
D_00_36bc::
    INCBIN "assets/bank_00/36bc.bin"
D_00_36c1::
    INCBIN "assets/bank_00/36c1.bin"
L_00_36c6::
    inc c
    ld c, d
    ld c, e
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
    ld [$c53e], a
.L_00_36ff:
    ld hl, EnemySlotTable
    call SelectEnemySlot
    xor a, a
    ld [hl], a
    ld a, [$c53e]
    dec a
    ld [$c53e], a
    bit 7, a
    jr z, .L_00_36ff
    ret
UpdateAllEnemies::  ; starts the enemy loop with $c53f incremented and $c53e = 15
    ld hl, $c53f
    inc [hl]
    ld a, $0f
    ld [$c53e], a
UpdateEnemyLoop::  ; for each slot index: load the slot into HRAM; run UpdateEnemy; store it back
    ld a, [$c53f]
    ld b, a
    ld a, [$c53e]
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
    ld a, [$c53e]
    dec a
    ld [$c53e], a
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
    ldh a, [$ffee]
    ldh [$ffcf], a
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
    ldh a, [$ffb6]
    ld [hl+], a
    ldh a, [$ffb7]
    ld [hl+], a
    ldh a, [$ffb8]
    ld [hl+], a
    ldh a, [$ffb9]
    ld [hl+], a
    ldh a, [$ffba]
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
    ldh a, [$ffc1]
    ld [hl+], a
    ldh a, [$ffc2]
    ld [hl+], a
    ldh a, [$ffc3]
    ld [hl+], a
    ldh a, [$ffc4]
    ld [hl+], a
    ldh a, [$ffc5]
    ld [hl+], a
    ldh a, [hEnemyAnimState]
    ld [hl+], a
    ldh a, [hEnemyBlocked]
    ld [hl+], a
    ldh a, [$ffc8]
    ld [hl+], a
    ldh a, [hEnemyCounter]
    ld [hl+], a
    ldh a, [hEnemyStep]
    ld [hl+], a
    ldh a, [$ffcb]
    ld [hl+], a
    ldh a, [hEnemyAux]
    ld [hl+], a
    ldh a, [$ffcd]
    ld [hl+], a
    ldh a, [$ffce]
    ld [hl+], a
    ldh a, [$ffcf]
    ld [hl+], a
    ldh a, [hEnemyTick]
    ld [hl+], a
    ldh a, [hEnemyDir]
    ld [hl+], a
    ldh a, [hEnemyKind]
    ld [hl+], a
    ldh a, [$ffd3]
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
    ldh [$ffb6], a
    ld a, [hl+]
    ldh [$ffb7], a
    ld a, [hl+]
    ldh [$ffb8], a
    ld a, [hl+]
    ldh [$ffb9], a
    ld a, [hl+]
    ldh [$ffba], a
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
    ldh [$ffc1], a
    ld a, [hl+]
    ldh [$ffc2], a
    ld a, [hl+]
    ldh [$ffc3], a
    ld a, [hl+]
    ldh [$ffc4], a
    ld a, [hl+]
    ldh [$ffc5], a
    ld a, [hl+]
    ldh [hEnemyAnimState], a
    ld a, [hl+]
    ldh [hEnemyBlocked], a
    ld a, [hl+]
    ldh [$ffc8], a
    ld a, [hl+]
    ldh [hEnemyCounter], a
    ld a, [hl+]
    ldh [hEnemyStep], a
    ld a, [hl+]
    ldh [$ffcb], a
    ld a, [hl+]
    ldh [hEnemyAux], a
    ld a, [hl+]
    ldh [$ffcd], a
    ld a, [hl+]
    ldh [$ffce], a
    ld a, [hl+]
    ldh [$ffcf], a
    ld a, [hl+]
    ldh [hEnemyTick], a
    ld a, [hl+]
    ldh [hEnemyDir], a
    ld a, [hl+]
    ldh [hEnemyKind], a
    ld a, [hl+]
    ldh [$ffd3], a
    ld a, [hl]
    ldh [hEnemyFlags], a
    ret
EnemyKindIdle::  ; kinds 0 6 8: stationary enemy (kind 0 = the armoured guards standing in the corridor rooms 13-15 and 29-31)
    call TickObjectTimer
    jr nz, .L_00_3906
    jp L_00_3a75
.L_00_3906:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call L_00_39f9
    call EnemyChooseDirection
    call L_00_39b1
    call L_00_352f
    call L_00_392e
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call L_00_3956
    call SelectObject2
    jp DrawObject
L_00_392e::
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
L_00_394d::
    ld a, [wPlayerDir]
    bit 5, a
    ret z
    jp RemoveEnemy
L_00_3956::
    ldh a, [hEnemyKind]
    cp a, $06
    jr z, .L_00_3963
    cp a, $08
    jr z, .L_00_396c
    jp .L_00_3975
.L_00_3963:
    ld de, D_00_3acf
    ld bc, $3ad4
    jp SetAnimationVariant
.L_00_396c:
    ld de, D_00_3ad9
    ld bc, $3ade
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
    ld bc, $3aab
    jp SetAnimationVariant
.L_00_398c:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3ab0
    ld bc, $3ab5
    jp SetAnimationVariant
.L_00_399a:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3ab0
    ld bc, $3ab5
    jp SetAnimationVariant
.L_00_39a8:
    ld de, D_00_3aba
    ld bc, $3abf
    jp SetAnimationVariant
L_00_39b1::
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
    ld hl, $3aed
    jr .L_00_39ec
.L_00_39e4:
    ldh a, [$ffcf]
    and a, a
    jr z, .L_00_39ec
    ld hl, $3aed
.L_00_39ec:
    add hl, bc
    ld a, [hl+]
    ldh [$ffc2], a
    ld a, [hl]
    ldh [$ffc4], a
    call SelectObject2
    jp ClampObjectToRoom
L_00_39f9::
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
L_00_3a75::
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $04
    ldh [$ffb9], a
    ldh a, [hEnemyKind]
    cp a, $06
    jr z, .L_00_3a90
    cp a, $08
    jr z, .L_00_3a99
    ld de, D_00_3aa6
    call SetObjectAnimation
    jp L_00_340c
.L_00_3a90:
    ld de, D_00_3acf
    call SetObjectAnimation
    jp L_00_340c
.L_00_3a99:
    ld de, D_00_3ad9
    call SetObjectAnimation
    jp L_00_340c
D_00_3aa2::
    INCBIN "assets/bank_00/3aa2.bin"
D_00_3aa6::
    INCBIN "assets/bank_00/3aa6.bin"
D_00_3ab0::
    INCBIN "assets/bank_00/3ab0.bin"
D_00_3aba::
    INCBIN "assets/bank_00/3aba.bin"
D_00_3ac4::
    INCBIN "assets/bank_00/3ac4.bin"
D_00_3aca::
    INCBIN "assets/bank_00/3aca.bin"
D_00_3acf::
    INCBIN "assets/bank_00/3acf.bin"
D_00_3ad9::
    INCBIN "assets/bank_00/3ad9.bin"
D_00_3ae3::
    INCBIN "assets/bank_00/3ae3.bin"
L_00_3aed::
    ld [bc], a
    nop
    cp a, $00
    nop
    cp a, $00
    ld [bc], a
    nop
    ld [bc], a
EnemyKind1::  ; enemy kind 1: ticks the object timer then moves on the tile grid
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3b02
    jp L_00_3bad
.L_00_3b02:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call L_00_39f9
    call EnemyEdgeBlockedDirs
    call EnemyChooseDirection
    call L_00_3b99
    ldh a, [hEnemyFlags]
    bit 1, a
    jr z, .L_00_3b26
    ld hl, hEnemyCounter
    inc [hl]
    ld a, [hl]
    and a, $08
    ret z
.L_00_3b26:
    call L_00_39b1
    call L_00_352f
    call L_00_392e
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call SetEnemyAnimation
    jp DrawObject
L_00_3b3b::
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
    ld bc, $3bc3
    jp SetAnimationVariant
.L_00_3b74:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3bc8
    ld bc, $3bcd
    jp SetAnimationVariant
.L_00_3b82:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3bc8
    ld bc, $3bcd
    jp SetAnimationVariant
.L_00_3b90:
    ld de, D_00_3bd2
    ld bc, $3bd7
    jp SetAnimationVariant
L_00_3b99::
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
L_00_3bad::
    ld a, $05
    ldh [hEnemyAnimState], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld de, D_00_3bbe
    call SetObjectAnimation
    jp L_00_340c
D_00_3bbe::
    INCBIN "assets/bank_00/3bbe.bin"
D_00_3bc8::
    INCBIN "assets/bank_00/3bc8.bin"
D_00_3bd2::
    INCBIN "assets/bank_00/3bd2.bin"
EnemyKind11::  ; enemy kind 11 (rounds 5 6 9 11 and the same rounds +16)
    call TickObjectTimer
    jr nz, .L_00_3be4
    jp L_00_3c57
.L_00_3be4:
    ldh a, [hEnemyFlags]
    bit 2, a
    jr z, .L_00_3bfb
    ldh a, [hEnemyDir]
    bit 1, a
    jp nz, EnemyDefeated
    set 1, a
    ldh [hEnemyDir], a
    call L_00_3c6e
    jp EnemyDefeated
.L_00_3bfb:
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_00_3c09
    call L_00_3c75
    ld hl, hEnemyDir
    set 0, [hl]
.L_00_3c09:
    ldh a, [$ffcb]
    sub a, $01
    ldh [$ffcb], a
    jr nc, .L_00_3c1a
    call L_00_3c7d
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
    call L_00_3c7d
    ldh a, [hEnemyAux]
    ld [hl], a
    jr .L_00_3c45
.L_00_3c42:
    call L_00_3c75
.L_00_3c45:
    call L_00_3c4e
    call SelectObject2
    jp DrawObject
L_00_3c4e::
    ld de, $3c87
    ld bc, $3c8c
    jp SetAnimationVariant
L_00_3c57::
    ld a, $20
    ldh [hEnemyCounter], a
    call L_00_3c7d
    ldh [hEnemyAux], a
    ld a, $fe
    ldh [$ffcb], a
    ld a, $90
    ldh [hEnemyDir], a
    ld de, $3c87
    jp SetObjectAnimation
L_00_3c6e::
    call L_00_3c7d
    ldh a, [hEnemyAux]
    ld [hl], a
    ret
L_00_3c75::
    call L_00_3c7d
    ldh [hEnemyStep], a
    xor a, a
    ld [hl], a
    ret
L_00_3c7d::
    ldh a, [hEnemyX]
    call PixelXToColumn
    ldh a, [hEnemyY]
    jp LookupMapTile
L_00_3c87::
    ld bc, $c9c8
    ret c
    reti
    INCBIN "assets/bank_00/3c8c.bin"
EnemyKind7::  ; enemy kind 7 (round 5-7 and 21-23): follows a scripted path from $c533
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3c9c
    jp L_00_3e20
.L_00_3c9c:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call L_00_3d18
    call MoveAndClampObject
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call L_00_3cb5
    jp DrawObject
L_00_3cb5::
    ldh a, [hEnemyDir]
    bit 0, a
    jr z, .L_00_3ccd
    ldh a, [hEnemyAux]
    and a, a
    jp z, .L_00_3d15
    dec a
    ldh [hEnemyAux], a
    ld de, D_00_3aca
    ld bc, $3e4d
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
    ld bc, $3e52
    jp SetAnimationVariant
.L_00_3cf5:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3e57
    ld bc, $3e5c
    jp SetAnimationVariant
.L_00_3d03:
    ld de, D_00_3e4d
    ld bc, $3e52
    jp SetAnimationVariant
.L_00_3d0c:
    ld de, D_00_3e57
    ld bc, $3e5c
    jp SetAnimationVariant
.L_00_3d15:
    jp RemoveEnemy
L_00_3d18::
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
    ldh [hEnemyAnimState], a
.L_00_3d2f:
    ld a, [wEnemyPathPtr]
    ld l, a
    ld a, [$c534]
    ld h, a
    ld a, [hl]
    cp a, $01
    jp z, .L_00_3d4b
    ldh [hEnemyCounter], a
    ldh [$ffc5], a
    inc hl
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [$c534], a
    ret
.L_00_3d4b:
    ld hl, hEnemyDir
    set 0, [hl]
    xor a, a
    ldh [hEnemyAnimState], a
    ret
.L_00_3d54:
    xor a, a
    ldh [hEnemyAnimState], a
    ld a, [wEnemyPathPtr]
    ld l, a
    ld a, [$c534]
    ld h, a
    dec hl
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [$c534], a
    jr .L_00_3d2f
D_00_3d6a::
    dw D_00_3d6e
    dw D_00_3dc7
D_00_3d6e::
    INCBIN "assets/bank_00/3d6e.bin"
D_00_3dc7::
    INCBIN "assets/bank_00/3dc7.bin"
L_00_3e20::
    ld a, $05
    ldh [hEnemyAnimState], a
    ld a, $20
    ldh [hEnemyCounter], a
    ldh [hEnemyAux], a
    ld hl, hObject2
    set 6, [hl]
    ld de, D_00_3e4d
    call SetObjectAnimation
    call L_00_340c
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld hl, D_00_3d6a
    call LookupWord
    ld a, l
    ld [wEnemyPathPtr], a
    ld a, h
    ld [$c534], a
    ret
D_00_3e4d::
    INCBIN "assets/bank_00/3e4d.bin"
D_00_3e57::
    INCBIN "assets/bank_00/3e57.bin"
EnemyKind5::  ; enemy kind 5
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_00_3e6c
    jp L_00_3ef9
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
    call L_00_3e90
    call L_00_3ed1
    jp DrawObject
L_00_3e90::
    ldh a, [hEnemyDir]
    bit 1, a
    jr nz, .L_00_3eb0
    ldh a, [hEnemyCounter]
    cp a, $a0
    jr z, .L_00_3ea8
    inc a
    ldh [hEnemyCounter], a
    ld de, D_00_3f3a
    ld bc, $3f3f
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
    jp L_00_3651
.L_00_3ec5:
    ld de, D_00_3aca
    jp L_00_3651
.L_00_3ecb:
    ld hl, hEnemyDir
    set 0, [hl]
    ret
L_00_3ed1::
    ldh a, [hEnemyDir]
    bit 0, a
    ret z
    ld a, $02
    ldh [$ffb9], a
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
L_00_3ef9::
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

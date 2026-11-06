INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank00", ROM0[$0000]

L_00_0000::
    jp RstJumpTable
    INCBIN "orig/painter_momopie.gb", $00003, 61
VBlankVector::  ; jp to VBlankHandler
    jp VBlankHandler
    INCBIN "orig/painter_momopie.gb", $00043, 5
    reti
    INCBIN "orig/painter_momopie.gb", $00049, 7
    reti
    INCBIN "orig/painter_momopie.gb", $00051, 7
    jp SerialHandler
    INCBIN "orig/painter_momopie.gb", $0005b, 5
    reti
    INCBIN "orig/painter_momopie.gb", $00061, 159
Entry::  ; nop; jp Start
    nop
    jp Start
    INCBIN "orig/painter_momopie.gb", $00104, 76
Start::  ; sets SP=$dfff; clears WRAM and HRAM; inits LCD and palettes; enters mode 0
    ld sp, $dfff
    call LcdOff
    di
    ld a, $01
    ld [$3fff], a
    ld hl, $c000
    ld bc, $1fef
    call ClearMemory
    ld hl, $ff80
    ld bc, $007e
    call ClearMemory
    call CopyOamDmaRoutine
    ld hl, $9bff
    call FillBackwardsFF
    call ClearOamShadow
    ld a, $e4
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
    ld a, $01
    ldh [rIE], a
    ld a, $93
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
    ld de, $8000
    ld bc, $0700
    call CopyMemory
    ld hl, RoomSpriteSetTable
    ld a, [wRoomIndex]
L_00_01d5::
    call TableIndexFromRound
    ld de, $8700
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
    ld de, $8000
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
    jr z, L_00_0241
    ld hl, hSerialByte
    set 2, [hl]
    set 0, [hl]
    pop hl
    pop de
    pop bc
    pop af
    reti
L_00_0241::
    ld hl, $c49c
    bit 3, [hl]
    jr nz, L_00_02b3
    ld a, [rSB]
    bit 7, a
    jr z, L_00_025b
    and a, $7f
    ld [$c7bf], a
    ld hl, hSerialByte
    set 4, [hl]
    jr L_00_029f
L_00_025b::
    ld a, [rSB]
    bit 2, a
    jr z, L_00_0270
    ld hl, hLinkFlags
    set 1, [hl]
    ld hl, hSerialByte
    set 6, [hl]
    set 7, [hl]
    jr L_00_029f
L_00_0270::
    ld a, [rSB]
    bit 3, a
    jr z, L_00_0283
    ld hl, hLinkFlags
    set 2, [hl]
    ld hl, hSerialByte
    set 3, [hl]
    jr L_00_029f
L_00_0283::
    ld a, [rSB]
    bit 1, a
    jr z, L_00_0291
    ld hl, hSerialByte
    set 5, [hl]
    jr L_00_029f
L_00_0291::
    ld a, [rSB]
    bit 4, a
    jr z, L_00_029f
    ld hl, hLinkFlags
    set 3, [hl]
    jr L_00_029f
L_00_029f::
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
L_00_02b3::
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
    jr nz, L_00_02dd
    ld hl, rLCDC
    set 7, [hl]
    xor a, a
    ld [rIF], a
    ld [rIE], a
    ld [rSC], a
    di
    jp Entry
L_00_02dd::
    ldh a, [hVBlankTasks]
    bit 1, a
    jp z, L_00_02e7
    call $ff80
L_00_02e7::
    nop
    ldh a, [hVBlankTasks]
    bit 0, a
    jp z, L_00_02f7
    call VramCopyList
    ld hl, hVBlankTasks
    res 0, [hl]
L_00_02f7::
    ldh a, [hVBlankTasks]
    bit 2, a
    jp z, L_00_0306
    call VramCopyRows
    ld hl, hVBlankTasks
    res 2, [hl]
L_00_0306::
    ld a, [wScrollX]
    ld [rSCX], a
    ld a, [wScrollY]
    ld [rSCY], a
    ldh a, [hVBlankTasks]
    bit 1, a
    jp z, L_00_0321
    ld hl, hVBlankTasks
    res 1, [hl]
    call ClearOamShadowY
L_00_0321::
    call SoundUpdate
    ldh a, [hVBlankTasks]
    bit 4, a
    jr z, L_00_0348
    ldh a, [hCountdownHi]
    and a, a
    jr z, L_00_0348
    ldh a, [hCountdownLo]
    sub a, $01
    ldh [hCountdownLo], a
    jr nc, L_00_0348
    ldh a, [hCountdownHi]
    sbc a, $00
    ldh [hCountdownHi], a
    jr nc, L_00_0344
    ld hl, hVBlankTasks
    res 4, [hl]
L_00_0344::
    ld a, $3c
    ldh [hCountdownLo], a
L_00_0348::
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
L_00_0361::
    ldh a, [hSerialByte]
    and a, a
    jr z, L_00_0361
    xor a, a
    ld [rIF], a
    ld a, $09
    ldh [rIE], a
    ret
WaitFrameAndSyncOam::  ; waits one frame; requests OAM DMA
    push hl
    ld hl, hFrameSpin
L_00_0373::
    inc [hl]
    ldh a, [hFrameCounter]
    cp a, $01
    jr c, L_00_0373
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
L_00_038d::
    inc [hl]
    ldh a, [hVBlankFlag]
    bit 0, a
    jr z, L_00_038d
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
L_00_03a1::
    ldh a, [hFrameCounter]
    inc [hl]
    cp a, b
    jr nz, L_00_03a1
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
L_00_03b5::
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, $94
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, L_00_03b5
    ld b, $05
L_00_03da::
    ld a, $94
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, $50
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, L_00_03da
    ld b, $05
L_00_03ff::
    ld a, $50
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, $40
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, L_00_03ff
    ld b, $05
L_00_0424::
    ld a, $40
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    ld a, $00
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $02
    call DelayFrames
    dec b
    jr nz, L_00_0424
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
L_00_048b::
    ld a, [hl+]
    ldh [c], a
    inc c
    dec b
    jr nz, L_00_048b
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
    ld hl, $9800
    ld b, $20
L_00_04af::
    add hl, de
    dec b
    jr nz, L_00_04af
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
L_00_04dd::
    ld a, [rLY]
    cp a, $91
    jr nz, L_00_04dd
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
L_00_0510::
    xor a, a
    ld [hl+], a
    dec b
    jr nz, L_00_0510
    ret
SetObjPtr::  ; hObjPtr = HL
    ld a, h
    ldh [hObjPtrHi], a
    ld a, l
    ldh [hObjPtrLo], a
    ret
L_00_051d::
    ld a, $09
    ld [$ff97], a
    ld a, $0a
    ld [$ff96], a
DrawMetatileMap::  ; draws a map of 2x2 tile metatiles: HL VRAM dest; BC metatile table; DE cell map; mask in $c7c0
    ld a, l
    ldh [$ff9c], a
    ldh [$ff9e], a
    ld a, h
    ldh [$ff9d], a
    ldh [$ff9f], a
    ld a, c
    ldh [$ffa0], a
    ld a, b
    ldh [$ffa1], a
    ld a, e
    ldh [$ffa2], a
    ld a, d
    ldh [$ffa3], a
    ldh a, [$ff96]
    ldh [$ffa6], a
    xor a, a
    ldh [$ff99], a
    ldh [$ff9a], a
    ldh [$ff9b], a
L_00_0548::
    ldh a, [$ffa2]
    ld l, a
    ldh a, [$ffa3]
    ld h, a
    ldh a, [$ff9a]
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
    ldh a, [$ffa0]
    ld l, a
    ldh a, [$ffa1]
    ld h, a
    add hl, bc
    ld a, l
    ldh [$ffa4], a
    ld a, h
    ldh [$ffa5], a
    ldh a, [$ff9b]
    ld c, a
    ldh a, [$ff99]
    ld b, a
    ld de, $ff9c
    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
    add hl, bc
    push hl
    ld hl, $ffa4
    ld a, [hl]
    ld e, a
    inc hl
    ld a, [hl]
    ld d, a
    pop hl
    ld c, $02
L_00_0588::
    ld b, $02
L_00_058a::
    ld a, [de]
    push hl
    ld hl, $c7c0
    and a, [hl]
    pop hl
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, L_00_058a
    dec c
    jr z, L_00_05a3
    push bc
    ld c, $1e
    ld b, $00
    add hl, bc
    pop bc
    jr L_00_0588
L_00_05a3::
    ldh a, [$ff96]
    dec a
    jr z, L_00_05c0
    ldh [$ff96], a
    ld hl, $ff9a
    inc [hl]
    ldh a, [$ff9b]
    inc a
    inc a
    jr z, L_00_05b9
    ldh [$ff9b], a
    jp L_00_0548
L_00_05b9::
    ld hl, $ff99
    inc [hl]
    jp L_00_0548
L_00_05c0::
    ldh a, [$ff97]
    dec a
    ret z
    ldh [$ff97], a
    ld de, $0040
    ldh a, [$ff9e]
    ld l, a
    ldh a, [$ff9f]
    ld h, a
    add hl, de
    ld a, l
    ldh [$ff9c], a
    ldh [$ff9e], a
    ld a, h
    ldh [$ff9d], a
    ldh [$ff9f], a
    xor a, a
    ldh [$ff9b], a
    ldh a, [$ffa6]
    ldh [$ff96], a
    ld hl, $ff9a
    inc [hl]
    jp L_00_0548
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
L_00_0628::
    ld a, [de]
    ldh [$ffa8], a
    inc de
    ld a, [de]
    ld c, a
    inc de
L_00_062f::
    ldh a, [$ffa8]
    res 7, a
    ld b, a
L_00_0634::
    ld a, [de]
    ld [hl+], a
    ldh a, [$ffa8]
    bit 7, a
    jr nz, L_00_063d
    inc de
L_00_063d::
    dec b
    jr nz, L_00_0634
    dec c
    jr z, L_00_0657
    ld a, l
    add a, $20
    ld l, a
    jr nc, L_00_064a
    inc h
L_00_064a::
    ldh a, [$ffa8]
    res 7, a
    ld b, a
    ld a, l
    sub a, b
    ld l, a
    jr nc, L_00_0655
    dec h
L_00_0655::
    jr L_00_062f
L_00_0657::
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
    ldh [$ffab], a
    inc bc
L_00_066f::
    ld a, b
    ldh [$ffaa], a
    ld a, c
    ldh [$ffa9], a
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
    call L_00_0628
    ldh a, [$ffab]
    dec a
    jr z, L_00_0696
    ldh [$ffab], a
    ldh a, [$ffa9]
    ld c, a
    ldh a, [$ffaa]
    ld b, a
    inc bc
    inc bc
    inc bc
    inc bc
    jr L_00_066f
L_00_0696::
    ld hl, wVramCopyFlags
    res 0, [hl]
    ret
WaitVramCopyDone::  ; waits until the VBlank task bit 2 is cleared
    ld a, [hVBlankTasks]
    bit 2, a
    jr nz, WaitVramCopyDone
    ret
ObjectShapeTable::  ; word pointers indexed by animation frame; each entry points at {count; dy; dx; tile; attr} sprite parts used by DrawObject
    INCBIN "orig/painter_momopie.gb", $006a4, 323
ClearOamShadowY::  ; clears Y of every OAM shadow entry
    ld hl, $c000
L_00_07ea::
    xor a, a
    ld [hl], a
    inc hl
    inc hl
    inc hl
    inc hl
    ld a, l
    cp a, $a0
    jr nz, L_00_07ea
    xor a, a
    ldh [hOamCount], a
    ret
ClearOamShadow::  ; zero fills the 160 byte OAM shadow at $c000
    ld b, $a0
    xor a, a
    ldh [hOamCount], a
    ld hl, $c000
L_00_0801::
    ld [hl+], a
    dec b
    jr nz, L_00_0801
    ret
RequestOamDma::  ; sets the OAM DMA bit in hVBlankTasks
    ld hl, hVBlankTasks
    set 1, [hl]
    ret
L_00_080c::
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
    ldh [$ff97], a
    ld a, $00
    ldh [$ff98], a
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    ld d, $00
    ld e, $07
    add hl, de
    ld a, [hl]
    ldh [$ff99], a
    ld a, $00
    ldh [$ff9a], a
    jr L_00_0866
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
    ldh [$ff97], a
    ld a, [hl]
    ldh [$ff98], a
    push bc
    pop hl
    ld d, $00
    ld e, $0a
    add hl, de
    ld a, [hl+]
    ldh [$ff99], a
    ld a, [hl]
    ldh [$ff9a], a
L_00_0866::
    push bc
    pop hl
    ld a, [hl]
    and a, $fb
    ldh [$ff96], a
    and a, $02
    jr z, L_00_0895
    ld a, [$c1ac]
    ld l, a
    ldh a, [$ff97]
    sub a, l
    ldh [$ff97], a
    ld a, [$c1ad]
    ld l, a
    ldh a, [$ff98]
    sbc a, l
    ldh [$ff98], a
    ld a, [$c1ae]
    ld l, a
    ldh a, [$ff99]
    sub a, l
    ldh [$ff99], a
    ld a, [$c1af]
    ld l, a
    ldh a, [$ff9a]
    sbc a, l
    ldh [$ff9a], a
L_00_0895::
    ldh a, [$ff96]
    bit 5, a
    jr z, L_00_08a7
    ldh a, [$ff97]
    sub a, $08
    ldh [$ff97], a
    ldh a, [$ff98]
    sbc a, $00
    ldh [$ff98], a
L_00_08a7::
    ldh a, [$ff96]
    bit 6, a
    jr z, L_00_08b9
    ldh a, [$ff99]
    sub a, $08
    ldh [$ff99], a
    ldh a, [$ff9a]
    sbc a, $00
    ldh [$ff9a], a
L_00_08b9::
    push bc
    pop hl
    ld d, $00
    ld e, $01
    add hl, de
    ld a, [hl+]
    ldh [$ff9b], a
    ld a, [hl]
    ldh [$ff9c], a
    or a, $9b
    jr nz, L_00_08cb
    ret
L_00_08cb::
    push bc
    pop hl
    ld d, $00
    ld e, $05
    add hl, de
    ld a, [hl]
    ldh [$ffa4], a
    ldh a, [$ff9c]
    ld h, a
    ldh a, [$ff9b]
    ld l, a
    ld a, [hl]
    sla a
    ld e, a
    ld d, $00
    ld hl, ObjectShapeTable
    add hl, de
    ld a, [hl+]
    ldh [$ff9d], a
    ld a, [hl]
    ldh [$ff9e], a
    ldh a, [$ff9e]
    ld h, a
    ldh a, [$ff9d]
    ld l, a
    ld a, [hl]
    ldh [$ff9f], a
    ldh [$ffa5], a
L_00_08f6::
    ldh a, [$ffa4]
    ld hl, $ff9f
    cp a, [hl]
    jr c, L_00_0901
    xor a, a
    ldh [$ffa4], a
L_00_0901::
    ld hl, $ffa4
    inc [hl]
    sla a
    ld c, a
    inc c
    ld b, $00
    ldh a, [$ff96]
    sla a
    sla a
    sla a
    push af
    ld e, $00
    ldh a, [$ff9d]
    ld l, a
    ldh a, [$ff9e]
    ld h, a
    add hl, bc
    pop af
    ld a, [hl]
    jr nc, L_00_0924
    ld a, $00
    sub a, [hl]
L_00_0924::
    bit 7, a
    jr z, L_00_0929
    dec e
L_00_0929::
    ld hl, $ff97
    add a, [hl]
    ldh [$ffa0], a
    ld a, e
    ld hl, $ff98
    adc a, [hl]
    jr nz, L_00_098a
    inc c
    ldh a, [$ff96]
    sla a
    sla a
    push af
    ld de, $0000
    ldh a, [$ff9d]
    ld l, a
    ldh a, [$ff9e]
    ld h, a
    add hl, bc
    pop af
    ld a, [hl]
    jr nc, L_00_094e
    ld a, e
    sub a, [hl]
L_00_094e::
    bit 7, a
    jr z, L_00_0953
    dec e
L_00_0953::
    ld hl, $ff99
    add a, [hl]
    ldh [$ffa1], a
    ld a, e
    ld hl, $ff9a
    adc a, [hl]
    jr nz, L_00_098a
    ldh a, [$ff9b]
    ld l, a
    ldh a, [$ff9c]
    ld h, a
    ld d, $00
    ldh a, [$ffa4]
    ld e, a
    add hl, de
    ld a, [hl]
    ldh [$ffa2], a
    ldh a, [$ff96]
    or a, $04
    ldh [$ff96], a
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
    ldh [$ffa3], a
    call L_00_09ab
L_00_098a::
    ld hl, $ffa5
    dec [hl]
    jp nz, L_00_08f6
    ldh a, [hObjPtrLo]
    ld l, a
    ld c, a
    ldh a, [hObjPtrHi]
    ld h, a
    ld b, a
    ldh a, [$ff96]
    ld [hl], a
    ld hl, $ffa4
    dec [hl]
    ld e, $05
    ld d, $00
    push bc
    pop hl
    add hl, de
    ldh a, [$ffa4]
    ld [hl], a
L_00_09aa::
    ret
L_00_09ab::
    ldh a, [hOamCount]
    cp a, $27
    jr c, L_00_09b4
    xor a, a
    ldh [hOamCount], a
L_00_09b4::
    sla a
    sla a
    ld c, a
    ld b, $00
    ldh a, [$ffa1]
    ld hl, $c000
    add hl, bc
    ld [hl+], a
    ldh a, [$ffa0]
    ld [hl+], a
    ldh a, [$ffa2]
    ld [hl+], a
    ldh a, [$ffa3]
    ld [hl], a
    ldh a, [hOamCount]
    inc a
    ldh [hOamCount], a
    ret
L_00_09d1::
    ld e, $06
    ld a, e
    ldh [$ff96], a
    ld e, $08
    ld a, e
    ldh [$ff97], a
    call L_00_0a13
    jr L_00_0a13
L_00_09e0::
    ld e, $06
    ld a, e
    ldh [$ff96], a
    ld e, $0c
    ld a, e
    ldh [$ff97], a
    call L_00_09ed
L_00_09ed::
    and a, a
    call L_00_0a13
    call L_00_0a13
    ld c, $00
    ldh a, [$ff98]
    bit 7, a
    jr z, L_00_09fd
    dec c
L_00_09fd::
    ldh a, [$ff96]
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
    ld hl, $ff96
    inc [hl]
    ret
L_00_0a13::
    ldh a, [$ff97]
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
    ldh [$ff98], a
    ldh a, [$ff96]
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
    ld hl, $ff96
    inc [hl]
    ld hl, $ff97
    inc [hl]
    ret
L_00_0a3f::
    dec b
    dec b
    inc b
    inc b
    jr L_00_0a5d
    INCBIN "orig/painter_momopie.gb", $00a45, 4
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
    ldh [$ff96], a
    ld a, c
    ldh [$ff97], a
    xor a, a
    ldh [$ff98], a
    ldh [$ff99], a
    ldh a, [$ff97]
    and a, a
    jr z, L_00_0a86
    ldh a, [$ff96]
    add a, $38
    ldh [$ff96], a
    ldh a, [$ff99]
    add a, $02
    ldh [$ff99], a
L_00_0a86::
    ldh a, [$ff96]
    cp a, $0a
    jr c, L_00_0a9f
    sub a, $0a
    ldh [$ff96], a
    ldh a, [$ff98]
    add a, $10
    daa
    ldh [$ff98], a
    ldh a, [$ff99]
    adc a, $00
    ldh [$ff99], a
    jr L_00_0a86
L_00_0a9f::
    push de
    ldh a, [$ff96]
    ld d, a
    ldh a, [$ff98]
    add a, d
    ldh [$ff98], a
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
L_00_0abf::
    ldh a, [$ffb9]
    sla a
    ldh [$ff98], a
    ld e, $04
    ld d, $00
    ldh a, [$ffa5]
    ld h, a
    ldh a, [$ffa4]
    ld l, a
    add hl, de
    ld a, [hl]
    sla a
    ldh [$ff99], a
    ldh a, [$ffbd]
    and a, a
    jr nz, L_00_0b03
    ld e, $08
    ld d, $00
    ldh a, [$ffa5]
    ld h, a
    ldh a, [$ffa4]
    ld l, a
    add hl, de
    ld a, [hl]
    and a, a
    jr nz, L_00_0b03
    ld e, $07
    ld d, $00
    call L_00_0b0a
    jr nc, L_00_0b03
    ld hl, $ff98
    inc [hl]
    ld hl, $ff99
    inc [hl]
    ld e, $0a
    ld d, $00
    call L_00_0b0a
    jr c, L_00_0b06
L_00_0b03::
    xor a, a
    ld c, a
    ret
L_00_0b06::
    ld a, $80
    ld c, a
    ret
L_00_0b0a::
    ldh a, [hObjPtrHi]
    ld h, a
    ldh a, [hObjPtrLo]
    ld l, a
    add hl, de
    ld a, [hl]
    push af
    ldh a, [$ffa5]
    ld h, a
    ldh a, [$ffa4]
    ld l, a
    add hl, de
    pop af
    sub a, [hl]
    ldh [$ff9a], a
    jp nc, L_00_0b27
    ld hl, $ff9a
    xor a, a
    sub a, [hl]
    ld [hl], a
L_00_0b27::
    ldh a, [$ff98]
    ld e, a
    ld d, $00
    ldh a, [$ff99]
    ld c, a
    ld b, $00
    ld hl, $0a3f
    add hl, de
    ld a, [hl]
    ld hl, $0a3f
    add hl, bc
    add a, [hl]
    ldh [$ff9c], a
    ldh a, [$ff9a]
    ld hl, $ff9c
    cp a, [hl]
    ret
L_00_0b44::
    ldh a, [hFrameSpin]
    and a, $10
    jr z, L_00_0b55
    ldh a, [hFrameSpin]
    sla a
    jr c, L_00_0b5b
L_00_0b50::
    and a, $fe
    jp L_00_0b5d
L_00_0b55::
    ldh a, [hFrameSpin]
    sla a
    jr c, L_00_0b50
L_00_0b5b::
    or a, $01
L_00_0b5d::
    ldh [hFrameSpin], a
    ld b, a
    ldh a, [hRngCounter]
    add a, b
    ldh [hRngCounter], a
    ret
L_00_0b66::
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
    ldh a, [$ff96]
    ld [hl], a
    inc hl
    ldh a, [$ff97]
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
    ldh a, [$ff96]
    ld [hl], a
    inc hl
    ldh a, [$ff97]
    ld [hl], a
    ret
D_00_0bb6::
    INCBIN "orig/painter_momopie.gb", $00bb6, 66
MultiplyByDE::  ; signed multiply of A by DE (shift and add)
    push af
    bit 7, a
    jr z, L_00_0c00
    cpl
    add a, $01
L_00_0c00::
    ld h, $00
    ld l, h
    ld d, h
    ld c, $08
L_00_0c06::
    srl a
    jr nc, L_00_0c0b
    add hl, de
L_00_0c0b::
    sla e
    rl d
    dec c
    jr nz, L_00_0c06
    pop af
    bit 7, a
    jp z, L_00_0c23
    ld a, $00
    sub a, l
    ldh [$ff96], a
    ld a, $00
    sbc a, h
    ldh [$ff97], a
    ret
L_00_0c23::
    ld a, h
    ldh [$ff97], a
    ld a, l
    ldh [$ff96], a
    ret
L_00_0c2a::
    dec a
    ldh [$ff9b], a
    ld hl, $ff9c
    ldh a, [$ff9e]
    and a, [hl]
L_00_0c33::
    srl a
    ld hl, $ff9d
    dec [hl]
    jr nz, L_00_0c33
    ld b, a
    ldh a, [$ff9b]
    cp a, b
    jr nc, L_00_0c45
    ld a, $00
    ldh [$ff9e], a
L_00_0c45::
    sla b
    ld c, b
    ret
D_00_0c49::
    INCBIN "orig/painter_momopie.gb", $00c49, 197
UnpackRoomMap::  ; HL = packed map (2 bits per cell; 4 cells per byte) unpacked to the 256 byte wRoomMap
    ld c, $00
    ld b, $01
    ld de, wRoomMap
L_00_0d15::
    push hl
    ld a, $04
    ld [$c1b5], a
    pop hl
    ld a, [hl]
    ldh [$ff98], a
L_00_0d1f::
    ldh a, [$ff98]
    rlc a
    rlc a
    ldh [$ff98], a
    and a, $03
    ld [de], a
    inc de
    push hl
    ld hl, $c1b5
    dec [hl]
    pop hl
    jr nz, L_00_0d1f
    inc hl
    dec bc
    dec bc
    dec bc
    dec bc
    ld a, c
    or a, b
    jr nz, L_00_0d15
    ret
D_00_0d3d::
    INCBIN "orig/painter_momopie.gb", $00d3d, 599
    dw L_00_0fa0
    dw L_00_0fa0
    dw L_00_0fa0
    dw L_00_0fa0
    dw L_00_0fa0
    dw L_00_0fa0
L_00_0fa0::
    rlca
    nop
    ld h, c
    ld e, d
    inc b
    nop
    ret c
    jr z, L_00_0fb5
    dec c
    ld d, h
    ld hl, sp + 16
    ld a, [bc]
    ldh a, [c]
    ret z
    inc d
    nop
    or a, d
    ld e, b
    rla
L_00_0fb5::
    dec c
    ret z
    ld hl, sp + 40
    nop
    adc a, b
    sbc a, d
    ld sp, $0fc9
    ret
    INCBIN "orig/painter_momopie.gb", $00fc0, 75
L_00_100b::
    ld bc, $0000
    ld hl, $c464
    ld a, e
    add a, [hl]
    ld [$c47a], a
    call ByteToBCD
    ldh a, [$ff99]
    and a, a
    jr z, L_00_1027
    inc d
    ld a, [$c47a]
    sub a, $64
    ld [$c47a], a
L_00_1027::
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
    jp L_00_11b4
DrawDecimalDigits::  ; draws a byte as decimal digits using ByteToBCD
    push hl
    ld a, [hl]
    push bc
    ld c, $00
    call ByteToBCD
    pop bc
    ldh a, [$ff98]
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
    INCBIN "orig/painter_momopie.gb", $010ab, 10
Mode1_Play::  ; gameplay in a room (paint the floor); loads tiles of bank 2
    ld sp, $dfff
    call LcdOff
    di
    ld hl, $9bff
    call FillBackwardsFF
    call LoadGfxBank2
    call ClearOamShadow
    ld hl, RoomMapTable
    ld a, [wRound]
    call TableIndexFromRoundDec
    call UnpackRoomMap
    ld a, $10
    ld [$ff97], a
    ld a, $10
    ld [$ff96], a
    ld a, [wRoomIndex]
    ld hl, RoomMetatileTable
    call TableIndexFromRound
    ld hl, $9800
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
    jr nz, L_00_110e
    jp L_00_1111
L_00_110e::
    and a, $0f
    ld c, a
L_00_1111::
    ld hl, D_00_0c49
    call LookupByte
    ld [$c520], a
    call RequestOamDma
    call ClearOamShadowY
    call L_00_1973
    call L_00_1438
    call L_01_536a
    ld a, [$c51f]
    bit 2, a
    jr nz, L_00_1138
    set 2, a
    ld [$c51f], a
    call L_00_14a6
L_00_1138::
    ld a, [wGameFlags]
    bit 7, a
    jr nz, L_00_1147
    set 7, a
    ld [wGameFlags], a
    call L_01_51ad
L_00_1147::
    call L_00_36fa
    ld hl, $c49e
    call Clear32Bytes
    call SerialStartTransfer
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    xor a, a
    ld [rIF], a
    ld a, $09
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    call L_00_13e6
    ld hl, wGameFlags
    res 5, [hl]
    ld a, $3c
    ldh [hCountdownLo], a
    ld a, [wRound]
    cp a, $21
    jr nz, L_00_117f
    ld a, $5a
    jr L_00_118a
L_00_117f::
    srl a
    srl a
    ld c, a
    ld hl, D_00_14f0
    call LookupByte
L_00_118a::
    ldh [hCountdownHi], a
    ldh [$ffe3], a
    ld hl, hVBlankTasks
    set 4, [hl]
L_00_1193::
    call WaitFrameAndSyncOam
    call ReadJoypad
    call PlayFrame
    call L_00_121c
    call L_01_5301
    call L_00_31f1
    call L_00_3713
    call L_00_11ec
    call L_00_11b4
    ld hl, $ffde
    inc [hl]
    jr L_00_1193
L_00_11b4::
    ld a, [$c51f]
    bit 1, a
    jr nz, L_00_11c6
    ld a, [$c465]
    cp a, $02
    ret c
    ld hl, $c51f
    set 1, [hl]
L_00_11c6::
    ld a, [$c46a]
    ld d, a
    ld a, [$c488]
    cp a, $05
    jr nz, L_00_11d5
    xor a, a
    ld [$c488], a
L_00_11d5::
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
L_00_11ec::
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_00_11f8
    ldh a, [hSerialByte]
    bit 5, a
    jr nz, L_00_11ff
L_00_11f8::
    ldh a, [hCountdownHi]
    ld b, a
    ldh a, [$ffe2]
    or a, b
    ret nz
L_00_11ff::
    ld a, [wGameFlags]
    bit 5, a
    ret nz
    set 5, a
    ld [wGameFlags], a
    ld a, $04
    ldh [$ff9d], a
    ld a, $a0
    ldh [$ff9e], a
    ld a, $98
    ldh [$ffa0], a
    call L_00_37f5
    jp SerialStartTransfer
L_00_121c::
    ld a, [wPlayerDir]
    bit 5, a
    ret nz
    ld a, [wSubState]
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
L_00_1265::
    ld a, $98
    ld [hl], a
    dec hl
    dec bc
    ld a, b
    or a, c
    jr nz, L_00_1265
    call L_00_1973
    ld hl, $9c66
    ld de, $c46d
    call L_00_0628
    ld a, [$c44b]
    ld c, a
    ld a, [$c44a]
    call ByteToBCD
    ldh a, [$ff98]
    and a, $0f
    call L_00_10a4
    ld [$c450], a
    ldh a, [$ff98]
    swap a
    and a, $0f
    call L_00_10a4
    ld [$c44f], a
    ldh a, [$ff99]
    call L_00_10a4
    ld [$c44e], a
    ld a, $03
    ld [$c44c], a
    ld a, $01
    ld [$c44d], a
    ld hl, $9ca5
    ld de, $c44c
    call L_00_0628
    ldh a, [hCountdownHi]
    ld c, $00
    call ByteToBCD
    ldh a, [$ff98]
    and a, $0f
    call L_00_10a4
    ld [$ffe8], a
    ldh a, [$ff98]
    swap a
    and a, $0f
    call L_00_10a4
    ld [$ffe7], a
    ldh a, [$ff99]
    call L_00_10a4
    ld [$ffe6], a
    ld a, $03
    ld [$ffe4], a
    ld a, $01
    ld [$ffe5], a
    ld hl, $9cb0
    ld de, $ffe4
    call L_00_0628
    ld a, [wRound]
    ld b, a
    ld hl, $9c71
    call DrawTwoDigitNumber
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    call ClearOamShadowY
    call RequestOamDma
    ld a, $09
    ldh [rIE], a
    ld a, $9b
    ld [rLCDC], a
    ei
    xor a, a
    ldh [$ff96], a
    call L_00_18a3
    ld bc, $0002
    ld a, [$c44b]
    and a, a
    jr z, L_00_1325
    ld e, $01
    jr L_00_1327
L_00_1325::
    ld e, $00
L_00_1327::
    ld a, [$c44a]
    ldh [$ff96], a
L_00_132c::
    ldh a, [$ff96]
    sub a, $64
    ld d, a
    jr c, L_00_1338
    ldh [$ff96], a
    jp L_00_1409
L_00_1338::
    ld a, e
    and a, a
    jr z, L_00_1344
    ld a, d
    ldh [$ff96], a
    ld e, $00
    jp L_00_1409
L_00_1344::
    ldh a, [$ff96]
    and a, a
    jr z, L_00_1371
    cp a, $0a
    jr z, L_00_1364
    sub a, $14
    ldh [$ff96], a
    ld a, [$c463]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $b8
    ld [hl], a
    ld hl, $c463
    inc [hl]
    jr L_00_1344
L_00_1364::
    ld a, [$c463]
    ld c, a
    ld b, $00
    ld hl, $c453
    add hl, bc
    ld a, $a8
    ld [hl], a
L_00_1371::
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
L_00_1396::
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 2, a
    jr z, L_00_13a9
    bit 7, a
    jp nz, L_01_50b1
    bit 3, a
    jp nz, L_01_50b1
L_00_13a9::
    call ReadJoypad
    ld hl, $c769
    inc [hl]
    call L_00_1770
    call L_00_1740
    ldh a, [hJoyNew]
    bit 1, a
    jr z, L_00_1396
    ld hl, $c53b
    res 1, [hl]
    call LcdOff
    di
    call LoadGfxBank2
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    call ClearOamShadow
    call RequestOamDma
    call ClearOamShadowY
    ld a, $09
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
L_00_13e6::
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
    jr nz, L_00_1433
    ld a, c
    jr L_00_1435
L_00_1433::
    and a, $0f
L_00_1435::
    jp LookupWord
L_00_1438::
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_00_144a
    ld a, $40
    ld [$c44a], a
    ld a, $01
    ld [$c44b], a
    jr L_00_145e
L_00_144a::
    ld a, [wRound]
    sla a
    ld c, a
    ld b, $00
    ld hl, TimerValueTable
    add hl, bc
    ld a, [hl+]
    ld [$c44b], a
    ld a, [hl]
    ld [$c44a], a
L_00_145e::
    xor a, a
    ldh [$ffea], a
    ret
TimerValueTable::  ; 16-bit values indexed by $c522 loaded into $c44a/$c44b
    INCBIN "orig/painter_momopie.gb", $01462, 68
L_00_14a6::
    xor a, a
    ld [$c488], a
    ld [$c464], a
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
    INCBIN "orig/painter_momopie.gb", $014e4, 12
D_00_14f0::
    INCBIN "orig/painter_momopie.gb", $014f0, 9
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
    INCBIN "orig/painter_momopie.gb", $0151b, 29
D_00_1538::
    INCBIN "orig/painter_momopie.gb", $01538, 25
D_00_1551::
    INCBIN "orig/painter_momopie.gb", $01551, 25
D_00_156a::
    INCBIN "orig/painter_momopie.gb", $0156a, 25
D_00_1583::
    INCBIN "orig/painter_momopie.gb", $01583, 21
D_00_1598::
    INCBIN "orig/painter_momopie.gb", $01598, 25
D_00_15b1::
    INCBIN "orig/painter_momopie.gb", $015b1, 17
D_00_15c2::
    INCBIN "orig/painter_momopie.gb", $015c2, 21
D_00_15d7::
    INCBIN "orig/painter_momopie.gb", $015d7, 25
D_00_15f0::
    INCBIN "orig/painter_momopie.gb", $015f0, 25
D_00_1609::
    INCBIN "orig/painter_momopie.gb", $01609, 21
D_00_161e::
    INCBIN "orig/painter_momopie.gb", $0161e, 25
D_00_1637::
    INCBIN "orig/painter_momopie.gb", $01637, 9
D_00_1640::
    INCBIN "orig/painter_momopie.gb", $01640, 9
D_00_1649::
    INCBIN "orig/painter_momopie.gb", $01649, 145
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
    dw SpriteTilesPart2
    dw SpriteTilesPart2
    dw SpriteTilesPart2
    dw D_02_6200
    dw D_02_6200
    dw D_02_6200
    dw D_02_6200
    dw D_02_6b00
    dw D_02_5900
    dw D_02_5900
    dw D_02_5900
    dw D_02_6200
    dw D_02_5000
    dw D_02_5000
    dw D_02_5000
    dw D_02_6b00
    dw D_02_5000
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
L_00_1740::
    ld a, [$c53b]
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
    jr L_00_1760
L_00_175d::
    ld hl, D_00_1a30
L_00_1760::
    ld a, l
    ld [$c74f], a
    ld a, h
    ld [$c750], a
    ret
L_00_1769::
    ld hl, $c53b
    res 2, [hl]
    jr L_00_175d
L_00_1770::
    ld a, [$c53b]
    bit 1, a
    jr nz, L_00_17a9
    ldh a, [hJoyNew]
    and a, $f1
    jr z, L_00_179c
    bit 0, a
    jr nz, L_00_17b2
    ld a, $8f
    call PlaySound
    ldh a, [hJoyNew]
    bit 4, a
    call nz, L_00_180f
    bit 5, a
    call nz, L_00_1839
    bit 6, a
    call nz, L_00_185f
    bit 7, a
    call nz, L_00_1876
L_00_179c::
    ld a, [$c43c]
    ld c, a
    ld hl, D_00_2630
    call LookupByte
    ld [$c754], a
L_00_17a9::
    ld hl, $c74e
    call SetObjPtr
    jp L_00_080c
L_00_17b2::
    ld a, [$c43d]
    ld e, $03
    call MultiplyByDE
    ldh a, [$ff96]
    ld d, a
    ld a, [$c43c]
    add a, d
    ld c, a
    ld hl, $c43e
    call LookupByte
    ld c, a
    ld b, $00
    ld hl, RoomTypeTable
    add hl, bc
    ld d, [hl]
    ld a, [$c44a]
    cp a, d
    jr nc, L_00_17e2
    ld a, [$c44b]
    and a, a
    jr nz, L_00_17e2
    ld hl, $c53b
    res 2, [hl]
    ret
L_00_17e2::
    ld a, $90
    call PlaySound
    ld a, [$c43d]
    ld e, $03
    call MultiplyByDE
    ldh a, [$ff96]
    ld d, a
    ld a, [$c43c]
    add a, d
    ld c, a
    ld hl, $c43e
    call LookupByte
    ld [wRoomType], a
    ld a, [$c53b]
    or a, $06
    ld [$c53b], a
    ld hl, hJoyNew
    res 7, [hl]
    jr L_00_179c
L_00_180f::
    ld a, [$c43c]
    cp a, $02
    jr z, L_00_1834
    ld a, [$c43d]
    ld e, $03
    call MultiplyByDE
    ldh a, [$ff96]
    ld e, a
    ld a, [$c43c]
    inc a
    add a, e
    ld c, a
    ld hl, $c43e
    call LookupByte
    or a, a
    ret z
    ld hl, $c43c
    inc [hl]
    ret
L_00_1834::
    xor a, a
    ld [$c43c], a
    ret
L_00_1839::
    ld a, [$c43c]
    or a, a
    jr z, L_00_1844
    ld hl, $c43c
    dec [hl]
    ret
L_00_1844::
    ld a, [$c43d]
    ld e, $03
    call MultiplyByDE
    ldh a, [$ff96]
    add a, $02
    ld c, a
    ld hl, $c43e
    call LookupByte
    or a, a
    ret z
    ld a, $02
    ld [$c43c], a
    ret
L_00_185f::
    ld a, [$c43d]
    or a, a
    jr z, L_00_1871
    ld hl, $c43d
    dec [hl]
    ld a, [hl]
    ld e, $03
    call MultiplyByDE
    jr L_00_18a3
L_00_1871::
    xor a, a
    ld [$c43d], a
    ret
L_00_1876::
    ld a, [$c43d]
    cp a, $02
    jp z, L_00_196f
    ld a, [$c43d]
    inc a
    ld e, $03
    call MultiplyByDE
    ldh a, [$ff96]
    ld d, a
    ld a, [$c43c]
    add a, d
    ld c, a
    ld hl, $c43e
    call LookupByte
    or a, a
    ret z
    ld hl, $c43d
    inc [hl]
    ld a, [$c43d]
    ld e, $03
    call MultiplyByDE
L_00_18a3::
    ldh a, [$ff96]
    ld c, a
    ld hl, $c43e
    call LookupByte
    ldh [$ff98], a
    ld hl, D_00_19a5
    call LookupWord
    push hl
    pop de
    ld hl, $9d02
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19b9
    call LookupWord
    push hl
    pop de
    ld hl, $9d42
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19cd
    call LookupWord
    push hl
    pop de
    ld hl, $9de2
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff96]
    inc a
    ldh [$ff96], a
    ld c, a
    ld hl, $c43e
    call LookupByte
    ldh [$ff98], a
    ld hl, D_00_19a5
    call LookupWord
    push hl
    pop de
    ld hl, $9d08
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19b9
    call LookupWord
    push hl
    pop de
    ld hl, $9d48
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19cd
    call LookupWord
    push hl
    pop de
    ld hl, $9de8
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff96]
    inc a
    ldh [$ff96], a
    ld c, a
    ld hl, $c43e
    call LookupByte
    ldh [$ff98], a
    ld hl, D_00_19a5
    call LookupWord
    push hl
    pop de
    ld hl, $9d0e
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19b9
    call LookupWord
    push hl
    pop de
    ld hl, $9d4e
    call QueueVramCopyRows
    call WaitVramCopyDone
    ldh a, [$ff98]
    ld hl, D_00_19cd
    call LookupWord
    push hl
    pop de
    ld hl, $9dee
    call QueueVramCopyRows
    jp WaitVramCopyDone
L_00_196f::
    ld [$c43d], a
    ret
L_00_1973::
    xor a, a
    ld [$c43c], a
    ld [$c43d], a
    ld [$c47d], a
    ld [$c53b], a
    ld hl, $c74e
    call Clear32Bytes
    ld a, $a0
    ld [$c74e], a
    ld a, $28
    ld [$c754], a
    ld a, $68
    ld [$c755], a
    ld hl, D_00_1a30
    jp L_00_1760
RoomTypeTable::  ; per room-type data indexed by wRoomType
    INCBIN "orig/painter_momopie.gb", $0199b, 10
D_00_19a5::
    INCBIN "orig/painter_momopie.gb", $019a5, 20
D_00_19b9::
    INCBIN "orig/painter_momopie.gb", $019b9, 20
D_00_19cd::
    INCBIN "orig/painter_momopie.gb", $019cd, 74
D_00_1a17::
    INCBIN "orig/painter_momopie.gb", $01a17, 25
D_00_1a30::
    INCBIN "orig/painter_momopie.gb", $01a30, 551
Mode3_RoundIntro::  ; ROUND nn / room name / lives / READY !!
    ld sp, $dfff
    call LcdOff
    di
    ld a, $ff
    call PlaySound
    ld hl, $9bff
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
    jr z, L_00_1c8d
    ld b, $01
    jr L_00_1c91
L_00_1c8d::
    ld a, [wLives]
    ld b, a
L_00_1c91::
    ld hl, $992c
    call DrawTwoDigitNumber
    ld a, [wRound]
    ld hl, D_00_1d39
    call TableIndexFromRoundDec
    ld hl, $98c3
    call L_00_0628
    call RequestOamDma
    call ClearOamShadowY
    call L_00_1ce7
    call L_01_492f
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    xor a, a
    ld [rIF], a
    ld a, $01
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    ld a, $97
    ldh [$ff96], a
L_00_1cd6::
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, $ff96
    dec [hl]
    jr nz, L_00_1cd6
    ld a, $01
    jp GameModeDispatch
L_00_1ce7::
    xor a, a
    ld [wRoomType], a
    ld [wSubState], a
    ld [$c47e], a
    ld [$c486], a
    ld [$c483], a
    ld a, $01
    ld [$c484], a
    ret
DrawTwoDigitNumber::  ; B = value drawn as two BCD digits at HL
    ld a, $02
    ldh [$ffa0], a
    ld a, $01
    ldh [$ffa1], a
    ld a, b
    call ByteToBCD
    ldh [$ff96], a
    and a, $f0
    swap a
    call L_00_1d23
    ldh [$ffa2], a
    ldh a, [$ff96]
    and a, $0f
    call L_00_1d23
    ldh [$ffa3], a
    ld de, $ffa0
    jp L_00_0628
L_00_1d23::
    push hl
    push bc
    ld c, a
    ld hl, D_00_1d2f
    call LookupByte
    pop bc
    pop hl
    ret
D_00_1d2f::
    INCBIN "orig/painter_momopie.gb", $01d2f, 10
D_00_1d39::
    INCBIN "orig/painter_momopie.gb", $01d39, 135
Mode7_LinkLose::  ; SORRY YOU LOSE / TRY AGAIN (2 player loser)
    ld sp, $dfff
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
    jr nz, L_00_1de6
    ld bc, $1e2e
    call RunVramCopyList
    jr L_00_1dec
L_00_1de6::
    ld bc, $1e57
    call RunVramCopyList
L_00_1dec::
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $09
    ldh [rIE], a
    ld a, $9b
    ld [rLCDC], a
    ei
    ld a, $ff
    ldh [$ff96], a
L_00_1e12::
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, $ff96
    dec [hl]
    jr nz, L_00_1e12
    ld a, [$c49b]
    and a, a
    jr z, L_00_1e29
    ld a, $05
    jp GameModeDispatch
L_00_1e29::
    ld a, $04
    jp GameModeDispatch
    INCBIN "orig/painter_momopie.gb", $01e2e, 118
Mode4_GameOver::  ; GAME OVER screen
    ld sp, $dfff
    call LcdOff
    di
    ld hl, $9bff
    call FillBackwardsFF
    call LoadTilesBank3A
    call ClearOamShadow
    ld a, $84
    call PlaySound
    ld hl, $9905
    ld de, D_00_1f10
    call L_00_0628
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, $09
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    ld hl, $c51f
    res 0, [hl]
    ld hl, wGameFlags
    res 2, [hl]
    ld a, $ff
    ldh [$ff96], a
    ld a, $02
    ldh [$ff97], a
L_00_1eee::
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, $ff96
    dec [hl]
    jr nz, L_00_1eee
    ldh a, [$ff97]
    dec a
    ldh [$ff97], a
    bit 7, a
    jr z, L_00_1eee
    ldh a, [hLinkFlags]
    bit 0, a
    jr nz, L_00_1f0d
    xor a, a
    jp GameModeDispatch
L_00_1f0d::
    jp Entry
D_00_1f10::
    INCBIN "orig/painter_momopie.gb", $01f10, 12
Mode5_Continue::  ; CONTINUE? countdown with YES/NO
    ld sp, $dfff
    call LcdOff
    di
    ld hl, $9bff
    call FillBackwardsFF
    ld hl, $c74e
    call Clear32Bytes
    call LoadTilesBank3A
    call ClearOamShadow
    ld bc, $2085
    call RunVramCopyList
    ld hl, D_00_2083
    call L_00_1760
    ld a, $3c
    ld [$c754], a
    ld a, $50
    ld [$c755], a
    ld a, $80
    ld [$c74e], a
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld [$c43c], a
    call RequestOamDma
    call ClearOamShadowY
    ld a, [$c49c]
    bit 0, a
    jr z, L_00_1f82
    ld a, $ff
    ld [$c49b], a
    ld a, $02
    ld [$c44c], a
    ld a, $01
    ld [$c44d], a
    ld a, $cd
    ld [$c44e], a
    ld a, $ce
    ld [$c44f], a
    jr L_00_1f93
L_00_1f82::
    ld a, $01
    ld [$c44c], a
    ld [$c44d], a
    ld a, [$c49b]
    call L_00_10a4
    ld [$c44e], a
L_00_1f93::
    ld de, $c44c
    ld hl, $98a9
    call L_00_0628
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $ee
    ld [rSB], a
    call SerialStartTransfer
    xor a, a
    ld [rIF], a
    ld a, $09
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    ld a, $f0
    ld [$c43b], a
L_00_1fc2::
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 4, a
    jp nz, L_00_2050
    ldh a, [hLinkFlags]
    bit 3, a
    jr nz, L_00_2024
    call ReadJoypad
    call L_00_2065
    ld hl, $c74e
    call SetObjPtr
    call L_00_080c
    ld hl, $c43b
    dec [hl]
    jp z, Entry
    ldh a, [hJoyNew]
    bit 0, a
    jr z, L_00_1fc2
    ld a, [$c43c]
    and a, a
    jr z, L_00_2029
    xor a, a
    ld [wRoomIndex], a
    ld a, $01
    ld [wRound], a
    ld [wRoundBackup], a
    ld hl, $c43e
    ld bc, $0008
    call ClearMemory
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_00_2014
    ld c, $10
    call SerialSendByte
L_00_2014::
    ld a, [$c49c]
    bit 0, a
    jr z, L_00_201f
    ld a, $ff
    jr L_00_2021
L_00_201f::
    ld a, $05
L_00_2021::
    ld [$c49b], a
L_00_2024::
    ld a, $04
    jp GameModeDispatch
L_00_2029::
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_00_2042
    call L_00_2b0a
    ld a, [rSC]
    bit 7, a
    jr z, L_00_2050
    ld a, [wRound]
    or a, $80
    ld c, a
    call SerialSendByte
L_00_2042::
    ld hl, $c51f
    res 2, [hl]
    ld hl, $c49b
    dec [hl]
    ld a, $03
    jp GameModeDispatch
L_00_2050::
    xor a, a
    ld [rSB], a
    ldh [hSerialByte], a
    ld a, [$c7bf]
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr L_00_2042
L_00_2065::
    ldh a, [hJoyNew]
    and a, $30
    ret z
    bit 4, a
    jr nz, L_00_2078
    ld a, $3c
    ld [$c754], a
    xor a, a
    ld [$c43c], a
    ret
L_00_2078::
    ld a, $74
    ld [$c754], a
    ld a, $01
    ld [$c43c], a
    ret
D_00_2083::
    INCBIN "orig/painter_momopie.gb", $02083, 36
D_00_20a7::
    INCBIN "orig/painter_momopie.gb", $020a7, 16
D_00_20b7::
    INCBIN "orig/painter_momopie.gb", $020b7, 16
D_00_20c7::
    INCBIN "orig/painter_momopie.gb", $020c7, 16
D_00_20d7::
    INCBIN "orig/painter_momopie.gb", $020d7, 64
D_00_2117::
    INCBIN "orig/painter_momopie.gb", $02117, 64
D_00_2157::
    INCBIN "orig/painter_momopie.gb", $02157, 64
D_00_2197::
    INCBIN "orig/painter_momopie.gb", $02197, 64
D_00_21d7::
    INCBIN "orig/painter_momopie.gb", $021d7, 64
D_00_2217::
    INCBIN "orig/painter_momopie.gb", $02217, 64
D_00_2257::
    INCBIN "orig/painter_momopie.gb", $02257, 64
D_00_2297::
    INCBIN "orig/painter_momopie.gb", $02297, 64
D_00_22d7::
    INCBIN "orig/painter_momopie.gb", $022d7, 64
D_00_2317::
    INCBIN "orig/painter_momopie.gb", $02317, 64
D_00_2357::
    INCBIN "orig/painter_momopie.gb", $02357, 64
D_00_2397::
    INCBIN "orig/painter_momopie.gb", $02397, 64
D_00_23d7::
    INCBIN "orig/painter_momopie.gb", $023d7, 64
D_00_2417::
    INCBIN "orig/painter_momopie.gb", $02417, 64
D_00_2457::
    INCBIN "orig/painter_momopie.gb", $02457, 64
Mode2_BonusSelect::  ; SELECT JUST ONE! choose A/B/C
    ld sp, $dfff
    ld hl, $c487
    inc [hl]
    xor a, a
    ld [$c43b], a
    ld a, $89
    call PlaySound
    call LcdOff
    di
    call LoadTilesBank3C
    ld a, $93
    ld [rLCDC], a
    ei
    call L_00_2633
Mode2_Init::  ; bonus select setup after LcdOff
    call LcdOff
    di
    ld a, [$c43b]
    ld hl, D_00_2709
    call LookupWord
    push hl
    pop de
    ld bc, $270f
    ld hl, $9800
    ld a, $ff
    ld [$c7c0], a
    call L_00_051d
    ld bc, $29b1
    call RunVramCopyList
    ld a, [$c43b]
    and a, a
    jr nz, L_00_24e9
    ld de, D_00_264a
    ld hl, $988c
    call L_00_0628
L_00_24e9::
    cp a, $02
    jr nz, L_00_250f
    ld a, [$c75a]
    ld hl, D_00_269b
    call LookupWord
    push hl
    pop de
    ld hl, $9886
    call L_00_0628
    ld a, [$c75a]
    ld hl, D_00_2651
    call LookupWord
    push hl
    pop de
    ld hl, $98c9
    call L_00_0628
L_00_250f::
    call RequestOamDma
    call ClearOamShadow
    xor a, a
    ld [wScrollX], a
    ld [wScrollY], a
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $01
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    ld a, [$c43b]
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
    ldh [$ff96], a
L_00_2545::
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, $ff96
    dec [hl]
    jr nz, L_00_2545
    ld hl, $c43b
    inc [hl]
    jp Mode2_Init
L_00_2558::
    ld d, $01
    ld e, $00
    call L_00_100b
    ld a, $e0
    ldh [$ff96], a
L_00_2563::
    call WaitVBlankFlag
    call ReadJoypad
    ld hl, $ff96
    dec [hl]
    jr nz, L_00_2563
    ld a, $03
    jp GameModeDispatch
L_00_2574::
    ld a, $10
    call DelayFrames
    ld hl, $c43b
    inc [hl]
L_00_257d::
    call WaitFrameAndSyncOam
    call ReadJoypad
    call L_00_25e0
    ld a, [$c759]
    bit 7, a
    jr z, L_00_257d
    ld a, [$c487]
    ld e, $03
    call MultiplyByDE
    ld c, a
    ld b, $00
    ld hl, D_00_25cb
    add hl, bc
    ldh a, [hFrameSpin]
    cp a, $7f
    jr c, L_00_25a8
    inc hl
    cp a, $cd
    jr c, L_00_25a8
    inc hl
L_00_25a8::
    ld a, [hl]
    ldh [$ff96], a
    ld hl, $c43e
L_00_25ae::
    ld a, [hl]
    and a, a
    jr z, L_00_25bc
    ld c, a
    ldh a, [$ff96]
    cp a, c
    jp z, L_00_25c5
    inc hl
    jr L_00_25ae
L_00_25bc::
    ldh a, [$ff96]
    ld [hl], a
    ld [$c75a], a
    jp Mode2_Init
L_00_25c5::
    ld [$c75a], a
    jp Mode2_Init
D_00_25cb::
    INCBIN "orig/painter_momopie.gb", $025cb, 21
L_00_25e0::
    ldh a, [hJoyNew]
    bit 5, a
    jr z, L_00_25f8
    ld a, $8f
    call PlaySound
    ld a, [$c758]
    dec a
    bit 7, a
    jr z, L_00_25f5
    ld a, $02
L_00_25f5::
    ld [$c758], a
L_00_25f8::
    ldh a, [hJoyNew]
    bit 4, a
    jr z, L_00_260f
    ld a, $8f
    call PlaySound
    ld a, [$c758]
    inc a
    cp a, $03
    jr c, L_00_260c
    xor a, a
L_00_260c::
    ld [$c758], a
L_00_260f::
    ldh a, [hJoyNew]
    bit 0, a
    jr z, L_00_261a
    ld hl, $c759
    set 7, [hl]
L_00_261a::
    ld a, [$c758]
    ld c, a
    ld hl, D_00_2630
    call LookupByte
    ld [$c754], a
    ld hl, $c74e
    call SetObjPtr
    jp L_00_080c
D_00_2630::
    INCBIN "orig/painter_momopie.gb", $02630, 3
L_00_2633::
    xor a, a
    ld [$c758], a
    ld [$c759], a
    ld a, $50
    ld [$c755], a
    ld a, $80
    ld [$c74e], a
    ld hl, D_00_2704
    jp L_00_1760
D_00_264a::
    INCBIN "orig/painter_momopie.gb", $0264a, 7
D_00_2651::
    INCBIN "orig/painter_momopie.gb", $02651, 74
D_00_269b::
    INCBIN "orig/painter_momopie.gb", $0269b, 105
D_00_2704::
    INCBIN "orig/painter_momopie.gb", $02704, 5
D_00_2709::
    INCBIN "orig/painter_momopie.gb", $02709, 737
Mode0_Title::  ; title screen: 1 PLAYER / 2 PLAYER; link-cable detection via the serial port
    ld sp, $dfff
    call LcdOff
    di
    call LoadTilesBank3A
    ld a, $81
    call PlaySound
    ld hl, $9bff
    call FillBackwardsFF
    ld bc, $2b86
    call RunVramCopyList
    call RequestOamDma
    ld hl, $c74e
    call Clear32Bytes
    call L_00_2b46
    ld a, $ee
    ld [rSB], a
    call SerialStartTransfer
    xor a, a
    ld [rIF], a
    ld a, $09
    ldh [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
TitleLoop::  ; title screen loop: serial check; joypad; button codes; Start sends the round over the link port
    call WaitFrameAndSyncOam
    ldh a, [hSerialByte]
    bit 4, a
    jp nz, L_00_2ac4
    call ReadJoypad
    ldh a, [hJoyHeld]
    cp a, $93
    jr nz, L_00_2a3f
    ld a, $06
    jp GameModeDispatch
L_00_2a3f::
    cp a, $47
    jr nz, L_00_2a48
    ld hl, $c49c
    set 0, [hl]
L_00_2a48::
    call L_00_2b23
    ld a, [$c49c]
    bit 5, a
    jr z, L_00_2a61
    ld hl, $c49d
    dec [hl]
    ld a, [$c49d]
    and a, a
    jr nz, L_00_2ad8
    ld hl, $c49c
    res 5, [hl]
L_00_2a61::
    ldh a, [hJoyNew]
    cp a, $08
    jr nz, TitleLoop
    ld a, [$c755]
    cp a, $64
    jr z, L_00_2ae7
    call L_00_2b0a
    ld a, [wRound]
    or a, $80
    ld c, a
    call SerialSendByte
    ld a, [rSB]
    cp a, $ee
    jr z, L_00_2a8b
    cp a, $ff
    jr z, L_00_2a94
    cp a, $88
    jr z, L_00_2a9b
    jr L_00_2abc
L_00_2a8b::
    ld hl, $c49c
    res 1, [hl]
    res 5, [hl]
    jr L_00_2aa5
L_00_2a94::
    ld hl, $c49c
    set 1, [hl]
    jr L_00_2aa5
L_00_2a9b::
    ld a, $a0
    ld [$c49d], a
    ld hl, $c49c
    set 5, [hl]
L_00_2aa5::
    ld a, [$c49c]
    bit 1, a
    jp nz, L_00_2abc
    bit 5, a
    jp nz, L_00_2abc
    ld hl, hLinkFlags
    set 0, [hl]
L_00_2ab7::
    ld a, $03
    jp GameModeDispatch
L_00_2abc::
    ld a, $64
    ld [$c755], a
    jp TitleLoop
L_00_2ac4::
    ld hl, hLinkFlags
    set 0, [hl]
    ld a, [$c7bf]
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr L_00_2ab7
L_00_2ad8::
    ld a, [$c755]
    cp a, $64
    jp nz, TitleLoop
    ldh a, [hJoyNew]
    cp a, $08
    jp nz, TitleLoop
L_00_2ae7::
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    ld a, $88
    ld [rSB], a
    call SerialStartTransfer
    ld hl, $c49c
    set 3, [hl]
    ld a, $01
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    jr L_00_2ab7
L_00_2b0a::
    call L_00_0b44
    ldh a, [hRngCounter]
    and a, $1f
    jr z, L_00_2b0a
    cp a, $1f
    jr nz, L_00_2b18
    dec a
L_00_2b18::
    ld [wRound], a
    ld [wRoundBackup], a
    dec a
    ld [wRoomIndex], a
    ret
L_00_2b23::
    ldh a, [hJoyNew]
    cp a, $04
    jr nz, L_00_2b2b
    jr L_00_2b34
L_00_2b2b::
    ld hl, $c74e
    call SetObjPtr
    jp L_00_080c
L_00_2b34::
    ld a, [$c755]
    cp a, $64
    jr z, L_00_2b3f
    ld a, $64
    jr L_00_2b41
L_00_2b3f::
    ld a, $74
L_00_2b41::
    ld [$c755], a
    jr L_00_2b2b
L_00_2b46::
    xor a, a
    ldh [hLinkFlags], a
    ld [$c49c], a
    ld [$c43e], a
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
    ld [$c49b], a
    ld a, $34
    ld [$c754], a
    ld a, $64
    ld [$c755], a
    ld a, $80
    ld [$c74e], a
    ld hl, $2b84
    jp L_00_1760
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
    INCBIN "orig/painter_momopie.gb", $02b96, 218
Mode6_Ending::  ; castle scene after the last round
    ld sp, $dfff
    call LcdOff
    di
    call LoadTilesBank3D
    ld hl, $9bff
    call FillBackwardsFF
    ld hl, $9fff
    call FillBackwardsFF
    call ClearOamShadowY
    call RequestOamDma
    ld a, $06
    ldh [$ff97], a
    ld a, $0a
    ldh [$ff96], a
    ld hl, $98c0
    ld bc, $3156
    ld de, D_00_31a6
    ld a, $ff
    ld [$c7c0], a
    call DrawMetatileMap
    ld hl, $c76e
    ld bc, $0041
    call ClearMemory
    ld a, $80
    ld [$c76e], a
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
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    xor a, a
    ld [rIF], a
    ld a, $01
    ld [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    call L_00_3085
    call L_00_3054
    ld a, $85
    call PlaySound
    ld a, $46
    call DelayFrames
    call L_00_3085
    call L_00_3054
L_00_2d16::
    call WaitFrameAndSyncOam
    call L_00_3085
    call L_00_3054
    ld a, [$c7ae]
    bit 7, a
    jr z, L_00_2d16
    call L_00_2fb9
    ld a, $10
    ld [$c49c], a
    ld a, $05
    ld [$c49d], a
L_00_2d33::
    call WaitFrameAndSyncOam
    call L_00_2fa5
    call L_00_2f26
    call L_00_2d5d
    call ReadJoypad
    ld a, [$c790]
    cp a, $08
    jr nz, L_00_2d33
    ld hl, $c49c
    dec [hl]
    jr nz, L_00_2d33
    ld a, [$c49d]
    dec a
    ld [$c49d], a
    bit 7, a
    jr z, L_00_2d33
    jp Entry
L_00_2d5d::
    ld a, [$c7ae]
    bit 2, a
    ret z
    ld a, [$c78e]
    bit 0, a
    jr nz, L_00_2d89
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
    call L_00_2dd9
L_00_2d89::
    ld a, [$c78e]
    bit 2, a
    jr nz, L_00_2dc1
    ld a, [$c78e]
    bit 1, a
    jr nz, L_00_2da9
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
L_00_2da9::
    ld a, [$c790]
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
L_00_2dc1::
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
    ld hl, $c790
    inc [hl]
    call L_00_2dd9
    ret
L_00_2dd9::
    call L_00_2fa5
    call L_00_2df1
    call L_00_2fa5
    ld a, [$c790]
    ld hl, D_00_2e0f
    call LookupWord
    call QueueVramCopyList
    jp WaitVramCopyDone
L_00_2df1::
    ld bc, $2dff
    call QueueVramCopyList
L_00_2df7::
    ld a, [wVramCopyFlags]
    bit 0, a
    jr nz, L_00_2df7
    ret
    INCBIN "orig/painter_momopie.gb", $02dff, 16
D_00_2e0f::
    INCBIN "orig/painter_momopie.gb", $02e0f, 279
L_00_2f26::
    call L_00_2f2c
    jp L_00_2f76
L_00_2f2c::
    call L_00_2f47
    ld a, [$c7ae]
    bit 2, a
    ret nz
    ld a, [$c775]
    cp a, $50
    jr z, L_00_2f41
    dec a
    ld [$c775], a
    ret
L_00_2f41::
    ld hl, $c7ae
    set 2, [hl]
    ret
L_00_2f47::
    ld a, $02
    ld [$c77f], a
    ld a, [$c782]
    bit 0, a
    jr nz, L_00_2f59
    xor a, a
    ld [$c77e], a
    jr L_00_2f5e
L_00_2f59::
    ld a, $10
    ld [$c77e], a
L_00_2f5e::
    call L_00_307f
    call L_00_0b66
    call L_00_09e0
    ld hl, $c781
    dec [hl]
    ret nz
    ld a, $0a
    ld [$c781], a
    ld hl, $c782
    inc [hl]
    ret
L_00_2f76::
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
    jr z, L_00_2f91
    ld hl, D_00_3111
L_00_2f91::
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ld [$c76f], a
    ld a, [hl]
    ld [$c770], a
    ld hl, $c76e
    call SetObjPtr
    jp DrawObject
L_00_2fa5::
    ld a, [$c798]
    sub a, $5a
    ld [$c798], a
    ld a, [$c799]
    sbc a, $00
    ld [$c799], a
    ld [wScrollX], a
    ret
L_00_2fb9::
    call LcdOff
    di
    ld hl, $9bff
    call FillBackwardsFF
    call ClearOamShadowY
    call RequestOamDma
    ld hl, $c76e
    ld bc, $0041
    call ClearMemory
    xor a, a
    ld [$c1ac], a
    ld [$c1ae], a
    ld bc, $30c4
    call RunVramCopyList
    ld a, $80
    ld [$c76e], a
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
    ld a, $01
    ld [rIE], a
    ld a, $93
    ld [rLCDC], a
    ei
    ret
    INCBIN "orig/painter_momopie.gb", $03009, 75
L_00_3054::
    ld a, [$c778]
    cp a, $08
    jr c, L_00_30aa
    ld hl, $c780
    inc [hl]
    ld a, [hl]
    and a, $10
    jr z, L_00_3070
    ld hl, $c77f
    inc [hl]
    ld hl, $c77e
    inc [hl]
    xor a, a
    ld [$c780], a
L_00_3070::
    call L_00_307f
    call L_00_0b66
    call L_00_09e0
    call L_00_307f
    jp DrawObject
L_00_307f::
    ld hl, $c76e
    jp SetObjPtr
L_00_3085::
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
    ld [$c790], a
    ld hl, $c78e
    call SetObjPtr
    jp DrawObject
L_00_30aa::
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
    INCBIN "orig/painter_momopie.gb", $030c4, 27
D_00_30df::
    INCBIN "orig/painter_momopie.gb", $030df, 50
D_00_3111::
    INCBIN "orig/painter_momopie.gb", $03111, 50
D_00_3143::
    INCBIN "orig/painter_momopie.gb", $03143, 5
D_00_3148::
    INCBIN "orig/painter_momopie.gb", $03148, 94
D_00_31a6::
    INCBIN "orig/painter_momopie.gb", $031a6, 60
TickObjectTimer::  ; increments $ffd0; Z flag from bit 7 of $ffd1
    ld hl, $ffd0
    inc [hl]
    inc hl
    ld a, [hl]
    bit 7, a
    ret
L_00_31eb::
    ld hl, $ffd4
    set 2, [hl]
    ret
L_00_31f1::
    ld a, [wRound]
    dec a
    ld hl, D_00_0d3d
    call LookupWord
    ld a, [$c483]
    cp a, $06
    jr nz, L_00_3206
    xor a, a
    ld [$c483], a
L_00_3206::
    call LookupWord
    ld a, l
    ld [$c481], a
    ld a, h
    ld [$c482], a
    ld a, [hl]
    ld [$c485], a
    ld d, a
    ld a, [$c484]
    dec a
    cp a, d
    jr nz, L_00_3229
    ld hl, $c483
    inc [hl]
    ld a, $01
    ld [$c484], a
    ld [$c486], a
L_00_3229::
    ld a, [wPlayerStatus]
    bit 5, a
    jr nz, L_00_324a
    ld hl, $c481
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    pop hl
    ld a, [$c484]
    sla a
    sla a
    ld c, a
    call LookupByte
    ldh [$ffe9], a
    ld hl, wPlayerStatus
    set 5, [hl]
L_00_324a::
    ldh a, [$ffe9]
    ld e, a
    ldh a, [hCountdownHi]
    ld d, a
    ldh a, [$ffe3]
    sub a, e
    cp a, d
    ret c
    ld a, [$c47e]
    cp a, $03
    ret nc
    ld hl, $c481
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    pop hl
    ld a, [$c484]
    sla a
    sla a
    sub a, $03
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ldh [$ff9d], a
    ld a, [hl+]
    ldh [$ff9e], a
    ld a, [hl]
    and a, $f8
    ldh [$ffa0], a
    ld a, [wRound]
    cp a, $11
    jr c, L_00_3289
    ld a, [hl]
    and a, $02
    ldh [$ffee], a
    jr L_00_328e
L_00_3289::
    ld a, [hl]
    and a, $01
    ldh [$ffee], a
L_00_328e::
    ld hl, $c484
    inc [hl]
    ld hl, $c486
    inc [hl]
    ld hl, $c47e
    inc [hl]
    ld hl, wPlayerStatus
    res 5, [hl]
    jp L_00_37f5
L_00_32a2::
    ld a, [wRoomType]
    cp a, $06
    jr nz, L_00_32af
    ld a, [wSubState]
    bit 0, a
    ret nz
L_00_32af::
    ld a, [wRoomType]
    cp a, $04
    jr nz, L_00_32bc
    ld a, [wSubState]
    bit 0, a
    ret nz
L_00_32bc::
    ld a, [$c49e]
    bit 7, a
    ret z
    ld hl, $c49e
    ld a, l
    ldh [$ffa4], a
    ld a, h
    ldh [$ffa5], a
    ld hl, wPlayer
    ld a, l
    ldh [hObjPtrLo], a
    ld a, h
    ldh [hObjPtrHi], a
    call L_00_0abf
    and a, a
    ret z
    ld hl, wPlayerDir
    set 5, [hl]
    ret
L_00_32df::
    ld a, $8e
    call PlaySound
    ld hl, $ffd3
    inc [hl]
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_32f3
    ld hl, $c4bc
    inc [hl]
L_00_32f3::
    ld a, $0c
    ldh [$ff9c], a
    ld a, $02
    ldh [$ff9d], a
    ldh a, [$ffd3]
    ldh [$ff9e], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_330b
    ld a, [$c4bc]
    ldh [$ff9e], a
L_00_330b::
    ld a, $03
    call L_00_0c2a
    ldh a, [$ff9e]
    ldh [$ffd3], a
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_3320
    ldh a, [$ff9e]
    ld [$c4bc], a
L_00_3320::
    ld a, $06
    cp a, c
    jp z, L_00_33da
    ld a, c
    and a, a
    jr nz, L_00_332f
    ld hl, D_00_36c1
    jr L_00_333b
L_00_332f::
    cp a, $02
    jr nz, L_00_3338
    ld hl, D_00_36bc
    jr L_00_333b
L_00_3338::
    ld hl, $36c6
L_00_333b::
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
    jr z, L_00_3361
    ld a, l
    ld [$c49f], a
    ld a, h
    ld [$c4a0], a
    ld hl, $c49e
    call SetObjPtr
    call DrawObject
L_00_3361::
    ld hl, hObject2
    set 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_3381
    ld hl, $c49e
    set 6, [hl]
    ld hl, $c49e
    call SetObjPtr
    call DrawObject
L_00_3381::
    ld hl, hObject2
    set 5, [hl]
    res 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_33a5
    ld hl, $c49e
    set 5, [hl]
    res 6, [hl]
    ld hl, $c49e
    call SetObjPtr
    call DrawObject
L_00_33a5::
    ld hl, hObject2
    set 6, [hl]
    call SelectObject2
    call DrawObject
    ld a, [wPlayerStatus]
    bit 4, a
    jr z, L_00_33c5
    ld hl, $c49e
    set 6, [hl]
    ld hl, $c49e
    call SetObjPtr
    call DrawObject
L_00_33c5::
    ldh a, [hObject2]
    and a, $9f
    ldh [hObject2], a
    ld a, [wPlayerStatus]
    bit 4, a
    ret z
    ld a, [$c49e]
    and a, $9f
    ld [$c49e], a
    ret
L_00_33da::
    ld hl, wPlayerStatus
    res 3, [hl]
    res 4, [hl]
    ld hl, $ffd4
    res 2, [hl]
    ldh a, [$ffd2]
    ld c, a
    ld hl, $33fd
    call LookupByte
    ld e, a
    ld d, $00
    call L_00_100b
    ld hl, $c49e
    res 7, [hl]
    jp L_00_3525
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
    ldh a, [$ffbc]
    push af
    and a, $f0
    ldh [$ffbc], a
    pop af
    and a, $0f
    or a, $90
    ldh [$ffd1], a
    ret
L_00_341f::
    ldh a, [$ffd2]
    cp a, $04
    jr z, L_00_3432
    ld a, [wRoomType]
    cp a, $04
    jr nz, L_00_3432
    ld a, [wSubState]
    bit 0, a
    ret nz
L_00_3432::
    ld hl, wPlayer
    ld a, l
    ldh [$ffa4], a
    ld a, h
    ldh [$ffa5], a
    call SelectObject2
    call L_00_0abf
    and a, a
    ret z
    ld hl, wPlayerDir
    set 5, [hl]
    ret
L_00_3449::
    push hl
    ld a, [$c1ac]
    ld l, a
    ld a, c
    sub a, l
    ldh [$ff96], a
    ld a, [$c1ae]
    ld l, a
    ld a, b
    sub a, l
    ldh [$ff97], a
    pop hl
    ldh a, [$ff96]
    cp a, $a8
    jr nc, L_00_3475
    ldh a, [$ff96]
    cp a, $08
    jr c, L_00_3475
    ldh a, [$ff97]
    cp a, $a8
    jr nc, L_00_3475
    ldh a, [$ff97]
    cp a, $10
    jr c, L_00_3475
    xor a, a
    ret
L_00_3475::
    ld a, $01
    ret
L_00_3478::
    ldh a, [$ffbc]
    ld b, a
    ldh a, [$ffbf]
    ld c, a
    jp IsOnTileGrid
L_00_3481::
    ldh a, [$ffbc]
    ld b, a
    ldh a, [$ffbf]
    ld c, a
    xor a, a
    ldh [$ffc7], a
    ld a, b
    add a, $08
    and a, $f0
    call PixelXToColumn
    ld a, c
    and a, $f0
    add a, $08
    cp a, c
    jr c, L_00_34ae
    ld a, c
    and a, $f0
    add a, $08
    sub a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, L_00_34ae
    ld a, $04
    ldh [$ffc7], a
L_00_34ae::
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
    jr c, L_00_34d5
    and a, $f0
    add a, $08
    add a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, L_00_34d5
    ldh a, [$ffc7]
    or a, $08
    ldh [$ffc7], a
L_00_34d5::
    ld a, b
    add a, $08
    and a, $f0
    cp a, b
    jr c, L_00_34fc
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
    jr nz, L_00_34fc
    ldh a, [$ffc7]
    or a, $02
    ldh [$ffc7], a
L_00_34fc::
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
    ldh a, [$ffc7]
    or a, $01
    ldh [$ffc7], a
    ret
L_00_3525::
    ld hl, hObject2
    res 7, [hl]
    ld hl, $c47e
    dec [hl]
    ret
L_00_352f::
    ldh a, [$ffd2]
    cp a, $08
    ret z
    ld a, [wRoomType]
    cp a, $05
    jr nz, L_00_3541
    ld a, [wSubState]
    bit 0, a
    ret nz
L_00_3541::
    ldh a, [$ffd1]
    bit 5, a
    ret z
    ld hl, $ffd1
    res 5, [hl]
    ldh a, [$ffbc]
    call PixelXToColumn
    ldh a, [$ffbf]
    and a, $f0
    add a, $08
    call LookupMapTile
    ld e, a
    bit 7, a
    ret nz
    bit 4, a
    ret z
    ldh a, [$ffbc]
    ld c, a
    ldh a, [$ffbf]
    ld b, a
    call L_00_3449
    and a, a
    ret nz
    ld a, e
    and a, $0f
    or a, $80
    ld [hl], a
    ldh a, [$ffbc]
    add a, $08
    and a, $f0
    ldh [hSpriteX], a
    ldh a, [$ffbf]
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
    ld hl, $c520
    inc [hl]
    ret
L_00_3599::
    ldh a, [$ffbc]
    ld b, a
    ldh a, [$ffbf]
    ld c, a
    call IsOnTileGrid
    ret nz
    ldh a, [$ffbd]
    cp a, $01
    jr z, L_00_35ba
    ldh a, [$ffbc]
    ld c, a
    ld a, [wPlayerX]
    ld e, a
    cp a, c
    jr z, L_00_35c6
    jr c, L_00_35ba
    sub a, c
    ld l, $01
    jr L_00_35be
L_00_35ba::
    ld a, c
    sub a, e
    ld l, $02
L_00_35be::
    ldh a, [$ffc7]
    and a, l
    jr nz, L_00_35f0
    ld b, l
    jr L_00_35e1
L_00_35c6::
    ldh a, [$ffbf]
    ld b, a
    ld a, [wPlayerY]
    ld d, a
    cp a, b
    jr z, L_00_35e1
    jr c, L_00_35d7
    sub a, b
    ld h, $08
    jr L_00_35db
L_00_35d7::
    ld a, b
    sub a, d
    ld h, $04
L_00_35db::
    ldh a, [$ffc7]
    and a, h
    jr nz, L_00_35f0
    ld b, h
L_00_35e1::
    ldh a, [$ffc7]
    swap a
    and a, $0f
    and a, b
    ldh a, [$ffd1]
    and a, $f0
    or a, b
    ldh [$ffd1], a
    ret
L_00_35f0::
    ld hl, $ffd1
    set 6, [hl]
    jp L_00_3a18
L_00_35f8::
    ldh a, [$ffbc]
    ld [$c525], a
    ldh a, [$ffbf]
    ld [$c526], a
    ret
L_00_3603::
    ldh a, [$ffd2]
    cp a, $04
    jr z, L_00_3620
    cp a, $03
    jr nz, L_00_3620
    ld a, [wRoomType]
    cp a, $03
    jr nz, L_00_3620
    ld a, [wSubState]
    bit 0, a
    jp nz, L_00_3666
    ld a, $05
    ldh [$ffc6], a
L_00_3620::
    ldh a, [$ffc7]
    and a, $0f
    ld d, a
    ldh a, [$ffd1]
    and a, $0f
    and a, d
    jp nz, L_00_3666
    ldh a, [$ffd1]
    and a, $0f
    srl a
    ld c, a
    ld hl, D_00_363d
    call LookupByte
    ldh [$ffc5], a
    ret
D_00_363d::
    INCBIN "orig/painter_momopie.gb", $0363d, 6
L_00_3643::
    call L_00_0b66
    jp L_00_09e0
L_00_3649::
    ldh a, [$ffd0]
    and a, $08
    jr z, L_00_3651
    push bc
    pop de
L_00_3651::
    jp SetObjectTarget
SelectObject2::  ; hObjPtr = hObject2
    ld hl, hObject2
    ld a, l
    ldh [hObjPtrLo], a
    ld a, $ff
    ldh [hObjPtrHi], a
    ret
SetObjectTarget::  ; stores DE at $ffb6/$ffb7 (movement target)
    ld a, e
    ldh [$ffb6], a
    ld a, d
    ldh [$ffb7], a
    ret
L_00_3666::
    ld hl, $ffd1
    set 6, [hl]
    xor a, a
    ldh [$ffc6], a
    ldh [$ffc2], a
    ldh [$ffc4], a
    ret
L_00_3673::
    ldh a, [$ffbc]
    call PixelXToColumn
    ldh a, [$ffbf]
    and a, $f0
    add a, $08
    jp LookupMapTile
L_00_3681::
    ld hl, $ffbc
    ld c, [hl]
    ld hl, $ffbf
    ld b, [hl]
    ret
L_00_368a::
    ld a, [wPlayerX]
    ld l, a
    ld a, [wPlayerY]
    ld h, a
    ret
L_00_3693::
    ld a, [$c4fe]
    bit 7, a
    ret z
    ld hl, $c4fe
    ld a, l
    ldh [$ffa4], a
    ld a, h
    ldh [$ffa5], a
    call SelectObject2
    call L_00_0abf
    and a, a
    ret z
    ld hl, $c4fe
    res 7, [hl]
    call L_00_31eb
    xor a, a
    ld [wSubState], a
    ld hl, wPlayerStatus
    set 3, [hl]
    ret
D_00_36bc::
    INCBIN "orig/painter_momopie.gb", $036bc, 5
D_00_36c1::
    INCBIN "orig/painter_momopie.gb", $036c1, 5
L_00_36c6::
    inc c
    ld c, d
    ld c, e
L_00_36c9::
    xor a, a
    ldh [$ffc7], a
    ldh a, [$ffbc]
    cp a, $21
    jr nc, L_00_36d6
    ld a, $02
    ldh [$ffc7], a
L_00_36d6::
    ldh a, [$ffbc]
    cp a, $f0
    jr c, L_00_36e2
    ldh a, [$ffc7]
    or a, $01
    ldh [$ffc7], a
L_00_36e2::
    ldh a, [$ffbf]
    cp a, $29
    jr nc, L_00_36ee
    ldh a, [$ffc7]
    or a, $04
    ldh [$ffc7], a
L_00_36ee::
    ldh a, [$ffbf]
    cp a, $f8
    ret c
    ldh a, [$ffc7]
    or a, $08
    ldh [$ffc7], a
    ret
L_00_36fa::
    ld a, $0f
    ld [$c53e], a
L_00_36ff::
    ld hl, D_00_37af
    call L_00_379e
    xor a, a
    ld [hl], a
    ld a, [$c53e]
    dec a
    ld [$c53e], a
    bit 7, a
    jr z, L_00_36ff
    ret
L_00_3713::
    ld hl, $c53f
    inc [hl]
    ld a, $0f
    ld [$c53e], a
L_00_371c::
    ld a, [$c53f]
    ld b, a
    ld a, [$c53e]
    add a, b
    and a, $0f
    ld hl, D_00_37af
    call L_00_379e
    ld a, [hl]
    bit 7, a
    jr z, L_00_373a
    call L_00_3897
    call L_00_3746
    call L_00_3830
L_00_373a::
    ld a, [$c53e]
    dec a
    ld [$c53e], a
    bit 7, a
    jr z, L_00_371c
    ret
L_00_3746::
    ldh a, [$ffd1]
    bit 4, a
    jr nz, L_00_375e
    ldh a, [$ffd2]
    sla a
    ld c, a
    ld b, $00
    ld hl, D_00_3782
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    push de
    pop hl
    jp hl
L_00_375e::
    ldh a, [$ffde]
    bit 2, a
    ret z
    ld hl, hObject2
    ld a, l
    ldh [hObjPtrLo], a
    ld a, $ff
    ldh [hObjPtrHi], a
    call DrawObject
    ldh a, [$ffc9]
    sub a, $01
    ldh [$ffc9], a
    bit 7, a
    ret z
    ld hl, $ffd1
    res 4, [hl]
    xor a, a
    ldh [$ffc9], a
    ret
D_00_3782::
    INCBIN "orig/painter_momopie.gb", $03782, 10
    dw L_00_3e61
    dw L_00_38fe
    dw L_00_3c91
    dw L_00_38fe
    INCBIN "orig/painter_momopie.gb", $03794, 10
L_00_379e::
    sla a
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ldh [$ffd7], a
    push af
    ld a, [hl]
    ldh [$ffd8], a
    ld h, a
    pop af
    ld l, a
    ret
D_00_37af::
    INCBIN "orig/painter_momopie.gb", $037af, 70
L_00_37f5::
    ld a, $0f
    ldh [$ff9c], a
L_00_37f9::
    ldh a, [$ff9c]
    ld hl, D_00_37af
    call L_00_379e
    ld a, [hl]
    bit 7, a
    jr z, L_00_3810
    ldh a, [$ff9c]
    dec a
    ldh [$ff9c], a
    bit 7, a
    jr z, L_00_37f9
    ret
L_00_3810::
    call L_00_382a
    ld a, $82
    ldh [hObject2], a
    ldh a, [$ff9d]
    ldh [$ffd2], a
    ldh a, [$ff9e]
    ldh [$ffbc], a
    ldh a, [$ffa0]
    ldh [$ffbf], a
    ldh a, [$ffee]
    ldh [$ffcf], a
    jp L_00_3830
L_00_382a::
    ld hl, hObject2
    jp Clear32Bytes
L_00_3830::
    ldh a, [$ffd7]
    ld l, a
    ldh a, [$ffd8]
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
    ldh a, [$ffbc]
    ld [hl+], a
    ldh a, [$ffbd]
    ld [hl+], a
    ldh a, [$ffbe]
    ld [hl+], a
    ldh a, [$ffbf]
    ld [hl+], a
    ldh a, [$ffc0]
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
    ldh a, [$ffc6]
    ld [hl+], a
    ldh a, [$ffc7]
    ld [hl+], a
    ldh a, [$ffc8]
    ld [hl+], a
    ldh a, [$ffc9]
    ld [hl+], a
    ldh a, [$ffca]
    ld [hl+], a
    ldh a, [$ffcb]
    ld [hl+], a
    ldh a, [$ffcc]
    ld [hl+], a
    ldh a, [$ffcd]
    ld [hl+], a
    ldh a, [$ffce]
    ld [hl+], a
    ldh a, [$ffcf]
    ld [hl+], a
    ldh a, [$ffd0]
    ld [hl+], a
    ldh a, [$ffd1]
    ld [hl+], a
    ldh a, [$ffd2]
    ld [hl+], a
    ldh a, [$ffd3]
    ld [hl+], a
    ldh a, [$ffd4]
    ld [hl], a
    ret
L_00_3897::
    ldh a, [$ffd7]
    ld l, a
    ldh a, [$ffd8]
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
    ldh [$ffbc], a
    ld a, [hl+]
    ldh [$ffbd], a
    ld a, [hl+]
    ldh [$ffbe], a
    ld a, [hl+]
    ldh [$ffbf], a
    ld a, [hl+]
    ldh [$ffc0], a
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
    ldh [$ffc6], a
    ld a, [hl+]
    ldh [$ffc7], a
    ld a, [hl+]
    ldh [$ffc8], a
    ld a, [hl+]
    ldh [$ffc9], a
    ld a, [hl+]
    ldh [$ffca], a
    ld a, [hl+]
    ldh [$ffcb], a
    ld a, [hl+]
    ldh [$ffcc], a
    ld a, [hl+]
    ldh [$ffcd], a
    ld a, [hl+]
    ldh [$ffce], a
    ld a, [hl+]
    ldh [$ffcf], a
    ld a, [hl+]
    ldh [$ffd0], a
    ld a, [hl+]
    ldh [$ffd1], a
    ld a, [hl+]
    ldh [$ffd2], a
    ld a, [hl+]
    ldh [$ffd3], a
    ld a, [hl]
    ldh [$ffd4], a
    ret
L_00_38fe::
    call TickObjectTimer
    jr nz, L_00_3906
    jp L_00_3a75
L_00_3906::
    ldh a, [$ffd4]
    bit 2, a
    jp nz, L_00_32df
    call L_00_3481
    call L_00_39f9
    call L_00_3a18
    call L_00_39b1
    call L_00_352f
    call L_00_392e
    call L_00_341f
    call L_00_3693
    call L_00_3956
    call SelectObject2
    jp DrawObject
L_00_392e::
    ld a, [wRoomType]
    cp a, $05
    ret nz
    ld a, [wSubState]
    bit 0, a
    ret z
    ldh a, [$ffd4]
    bit 1, a
    ret nz
    ldh a, [$ffbc]
    ld b, a
    ldh a, [$ffbf]
    ld c, a
    call IsOnTileGrid
    ret nz
    ld a, b
    jp L_01_5006
L_00_394d::
    ld a, [wPlayerDir]
    bit 5, a
    ret z
    jp L_00_3525
L_00_3956::
    ldh a, [$ffd2]
    cp a, $06
    jr z, L_00_3963
    cp a, $08
    jr z, L_00_396c
    jp L_00_3975
L_00_3963::
    ld de, D_00_3acf
    ld bc, $3ad4
    jp L_00_3649
L_00_396c::
    ld de, D_00_3ad9
    ld bc, $3ade
    jp L_00_3649
L_00_3975::
    ldh a, [$ffd1]
    bit 0, a
    jr nz, L_00_398c
    bit 1, a
    jr nz, L_00_399a
    bit 2, a
    jr nz, L_00_39a8
    ld de, D_00_3aa6
    ld bc, $3aab
    jp L_00_3649
L_00_398c::
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3ab0
    ld bc, $3ab5
    jp L_00_3649
L_00_399a::
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3ab0
    ld bc, $3ab5
    jp L_00_3649
L_00_39a8::
    ld de, D_00_3aba
    ld bc, $3abf
    jp L_00_3649
L_00_39b1::
    ld a, [wRoomType]
    cp a, $03
    jr nz, L_00_39c0
    ld a, [wSubState]
    bit 0, a
    jp nz, L_00_3666
L_00_39c0::
    ldh a, [$ffc7]
    and a, $0f
    ld d, a
    ldh a, [$ffd1]
    and a, $0f
    ld e, a
    and a, d
    jp nz, L_00_3666
    ld a, e
    srl a
    sla a
    ld c, a
    ld b, $00
    ld hl, D_00_3ae3
    ldh a, [$ffd4]
    bit 7, a
    jr z, L_00_39e4
    ld hl, $3aed
    jr L_00_39ec
L_00_39e4::
    ldh a, [$ffcf]
    and a, a
    jr z, L_00_39ec
    ld hl, $3aed
L_00_39ec::
    add hl, bc
    ld a, [hl+]
    ldh [$ffc2], a
    ld a, [hl]
    ldh [$ffc4], a
    call SelectObject2
    jp L_00_09e0
L_00_39f9::
    call L_00_3478
    jr z, L_00_3a04
    ld hl, $ffd1
    res 6, [hl]
    ret
L_00_3a04::
    ldh a, [$ffca]
    cp a, $0b
    jr z, L_00_3a0e
    inc a
    ldh [$ffca], a
    ret
L_00_3a0e::
    xor a, a
    ldh [$ffca], a
    ldh a, [$ffd1]
    or a, $60
    ldh [$ffd1], a
    ret
L_00_3a18::
    ldh a, [$ffd1]
    bit 6, a
    ret z
    ld hl, $ffd1
    res 6, [hl]
    ldh a, [$ffc7]
    ld e, a
    ldh a, [$ffd1]
    and a, $0f
    srl a
    ld c, a
    ld hl, D_00_3aa2
    call LookupByte
    or a, e
    cp a, $0f
    jr z, L_00_3a67
L_00_3a37::
    call L_00_0b44
    ldh a, [hRngCounter]
    and a, $0f
    ld b, a
    ldh a, [$ffc7]
    cpl
    and a, $0f
    and a, b
    ld c, a
    jr z, L_00_3a37
    ld a, $08
    cp a, c
    jr z, L_00_3a5f
    ld a, $04
    cp a, c
    jr z, L_00_3a5f
    ld a, $02
    cp a, c
    jr z, L_00_3a5f
    ld a, $01
    cp a, c
    jr z, L_00_3a5f
    jp L_00_3a37
L_00_3a5f::
    ldh a, [$ffd1]
    and a, $f0
    or a, c
    ldh [$ffd1], a
    ret
L_00_3a67::
    ldh a, [$ffc7]
    cpl
    and a, $0f
    ld b, a
    ldh a, [$ffd1]
    and a, $f0
    or a, b
    ldh [$ffd1], a
    ret
L_00_3a75::
    ld a, $20
    ldh [$ffc9], a
    ld a, $04
    ldh [$ffb9], a
    ldh a, [$ffd2]
    cp a, $06
    jr z, L_00_3a90
    cp a, $08
    jr z, L_00_3a99
    ld de, D_00_3aa6
    call SetObjectTarget
    jp L_00_340c
L_00_3a90::
    ld de, D_00_3acf
    call SetObjectTarget
    jp L_00_340c
L_00_3a99::
    ld de, D_00_3ad9
    call SetObjectTarget
    jp L_00_340c
D_00_3aa2::
    INCBIN "orig/painter_momopie.gb", $03aa2, 4
D_00_3aa6::
    INCBIN "orig/painter_momopie.gb", $03aa6, 10
D_00_3ab0::
    INCBIN "orig/painter_momopie.gb", $03ab0, 10
D_00_3aba::
    INCBIN "orig/painter_momopie.gb", $03aba, 10
D_00_3ac4::
    INCBIN "orig/painter_momopie.gb", $03ac4, 6
D_00_3aca::
    INCBIN "orig/painter_momopie.gb", $03aca, 5
D_00_3acf::
    INCBIN "orig/painter_momopie.gb", $03acf, 10
D_00_3ad9::
    INCBIN "orig/painter_momopie.gb", $03ad9, 10
D_00_3ae3::
    INCBIN "orig/painter_momopie.gb", $03ae3, 10
L_00_3aed::
    ld [bc], a
    nop
    cp a, $00
    nop
    cp a, $00
    ld [bc], a
    nop
    ld [bc], a
    call SelectObject2
    call TickObjectTimer
    jr nz, L_00_3b02
    jp L_00_3bad
L_00_3b02::
    ldh a, [$ffd4]
    bit 2, a
    jp nz, L_00_32df
    call L_00_3481
    call L_00_39f9
    call L_00_36c9
    call L_00_3a18
    call L_00_3b99
    ldh a, [$ffd4]
    bit 1, a
    jr z, L_00_3b26
    ld hl, $ffc9
    inc [hl]
    ld a, [hl]
    and a, $08
    ret z
L_00_3b26::
    call L_00_39b1
    call L_00_352f
    call L_00_392e
    call L_00_341f
    call L_00_3693
    call L_00_3b57
    jp DrawObject
L_00_3b3b::
    ldh a, [$ffd4]
    bit 0, a
    ret z
    set 0, a
    ldh [$ffd4], a
    ldh a, [$ffcc]
    cp a, $80
    jr z, L_00_3b4e
    inc a
    ldh [$ffcc], a
    ret
L_00_3b4e::
    ld hl, $ffd4
    res 0, [hl]
    xor a, a
    ldh [$ffcc], a
    ret
L_00_3b57::
    call L_00_3b5d
    jp L_00_3649
L_00_3b5d::
    ldh a, [$ffd1]
    bit 0, a
    jr nz, L_00_3b74
    bit 1, a
    jr nz, L_00_3b82
    bit 2, a
    jr nz, L_00_3b90
    ld de, D_00_3bbe
    ld bc, $3bc3
    jp L_00_3649
L_00_3b74::
    ld hl, hObject2
    set 5, [hl]
    ld de, D_00_3bc8
    ld bc, $3bcd
    jp L_00_3649
L_00_3b82::
    ld hl, hObject2
    res 5, [hl]
    ld de, D_00_3bc8
    ld bc, $3bcd
    jp L_00_3649
L_00_3b90::
    ld de, $3bd2
    ld bc, $3bd7
    jp L_00_3649
L_00_3b99::
    call L_00_3673
    and a, $0f
    or a, a
    jr nz, L_00_3ba7
    ld hl, $ffd4
    set 1, [hl]
    ret
L_00_3ba7::
    ld hl, $ffd4
    res 1, [hl]
    ret
L_00_3bad::
    ld a, $05
    ldh [$ffc6], a
    ld a, $20
    ldh [$ffc9], a
    ld de, D_00_3bbe
    call SetObjectTarget
    jp L_00_340c
D_00_3bbe::
    INCBIN "orig/painter_momopie.gb", $03bbe, 10
D_00_3bc8::
    INCBIN "orig/painter_momopie.gb", $03bc8, 10
L_00_3bd2::
    ld bc, $c9c8
    ret c
    reti
    INCBIN "orig/painter_momopie.gb", $03bd7, 186
L_00_3c91::
    call SelectObject2
    call TickObjectTimer
    jr nz, L_00_3c9c
    jp L_00_3e20
L_00_3c9c::
    ldh a, [$ffd4]
    bit 2, a
    jp nz, L_00_32df
    call L_00_3d18
    call L_00_3643
    call L_00_341f
    call L_00_3693
    call L_00_3cb5
    jp DrawObject
L_00_3cb5::
    ldh a, [$ffd1]
    bit 0, a
    jr z, L_00_3ccd
    ldh a, [$ffcc]
    and a, a
    jp z, L_00_3d15
    dec a
    ldh [$ffcc], a
    ld de, D_00_3aca
    ld bc, $3e4d
    jp L_00_3649
L_00_3ccd::
    ldh a, [hObject2]
    set 5, a
    set 6, a
    ldh [hObject2], a
    ldh a, [$ffc9]
    cp a, $00
    jr z, L_00_3ce7
    cp a, $08
    jr z, L_00_3cf5
    cp a, $10
    jr z, L_00_3d03
    cp a, $18
    jr z, L_00_3d0c
L_00_3ce7::
    ld hl, hObject2
    res 6, [hl]
    ld de, D_00_3e4d
    ld bc, $3e52
    jp L_00_3649
L_00_3cf5::
    ld hl, hObject2
    res 5, [hl]
    ld de, $3e57
    ld bc, $3e5c
    jp L_00_3649
L_00_3d03::
    ld de, D_00_3e4d
    ld bc, $3e52
    jp L_00_3649
L_00_3d0c::
    ld de, $3e57
    ld bc, $3e5c
    jp L_00_3649
L_00_3d15::
    jp L_00_3525
L_00_3d18::
    ldh a, [$ffd1]
    bit 0, a
    ret nz
    ld a, [wRoomType]
    cp a, $03
    jr nz, L_00_3d2b
    ld a, [wSubState]
    bit 0, a
    jr nz, L_00_3d54
L_00_3d2b::
    ld a, $05
    ldh [$ffc6], a
L_00_3d2f::
    ld a, [$c533]
    ld l, a
    ld a, [$c534]
    ld h, a
    ld a, [hl]
    cp a, $01
    jp z, L_00_3d4b
    ldh [$ffc9], a
    ldh [$ffc5], a
    inc hl
    ld a, l
    ld [$c533], a
    ld a, h
    ld [$c534], a
    ret
L_00_3d4b::
    ld hl, $ffd1
    set 0, [hl]
    xor a, a
    ldh [$ffc6], a
    ret
L_00_3d54::
    xor a, a
    ldh [$ffc6], a
    ld a, [$c533]
    ld l, a
    ld a, [$c534]
    ld h, a
    dec hl
    ld a, l
    ld [$c533], a
    ld a, h
    ld [$c534], a
    jr L_00_3d2f
D_00_3d6a::
    INCBIN "orig/painter_momopie.gb", $03d6a, 182
L_00_3e20::
    ld a, $05
    ldh [$ffc6], a
    ld a, $20
    ldh [$ffc9], a
    ldh [$ffcc], a
    ld hl, hObject2
    set 6, [hl]
    ld de, D_00_3e4d
    call SetObjectTarget
    call L_00_340c
    ldh a, [$ffd1]
    and a, $0f
    srl a
    ld hl, D_00_3d6a
    call LookupWord
    ld a, l
    ld [$c533], a
    ld a, h
    ld [$c534], a
    ret
D_00_3e4d::
    INCBIN "orig/painter_momopie.gb", $03e4d, 10
L_00_3e57::
    ld bc, $c5c4
    call nc, L_00_01d5
    add a, $c7
    sub a, $d7
L_00_3e61::
    call SelectObject2
    call TickObjectTimer
    jr nz, L_00_3e6c
    jp L_00_3ef9
L_00_3e6c::
    ldh a, [$ffd4]
    bit 2, a
    jp nz, L_00_32df
    ld a, [wRoomType]
    cp a, $06
    jr nz, L_00_3e81
    ld a, [wSubState]
    bit 0, a
    jr nz, L_00_3e84
L_00_3e81::
    call L_00_341f
L_00_3e84::
    call L_00_3693
    call L_00_3e90
    call L_00_3ed1
    jp DrawObject
L_00_3e90::
    ldh a, [$ffd1]
    bit 1, a
    jr nz, L_00_3eb0
    ldh a, [$ffc9]
    cp a, $a0
    jr z, L_00_3ea8
    inc a
    ldh [$ffc9], a
    ld de, D_00_3f3a
    ld bc, $3f3f
    jp L_00_3649
L_00_3ea8::
    xor a, a
    ldh [$ffc9], a
    ld hl, $ffd1
    set 1, [hl]
L_00_3eb0::
    ldh a, [$ffc9]
    cp a, $50
    jr z, L_00_3ecb
    inc a
    ldh [$ffc9], a
    ldh a, [$ffd0]
    and a, $04
    jr z, L_00_3ec5
    ld de, D_00_3f3a
    jp L_00_3651
L_00_3ec5::
    ld de, D_00_3aca
    jp L_00_3651
L_00_3ecb::
    ld hl, $ffd1
    set 0, [hl]
    ret
L_00_3ed1::
    ldh a, [$ffd1]
    bit 0, a
    ret z
    ld a, $02
    ldh [$ffb9], a
    ldh a, [$ffca]
    sla a
    ld c, a
    ld b, $00
    ld hl, $c489
    add hl, bc
    ld a, [hl+]
    or a, a
    jp z, L_00_3525
    ldh [$ffbc], a
    ld a, [hl]
    ldh [$ffbf], a
    ld hl, $ffca
    inc [hl]
    ld de, D_00_3f44
    jp SetObjectTarget
L_00_3ef9::
    ld a, $20
    ldh [$ffc9], a
    ldh a, [$ffbc]
    ld [$c48b], a
    ld [$c48f], a
    ld [$c491], a
    sub a, $10
    ld [$c489], a
    ldh a, [$ffbc]
    add a, $10
    ld [$c48d], a
    ldh a, [$ffbf]
    ld [$c48a], a
    ld [$c48e], a
    ld [$c492], a
    sub a, $10
    ld [$c48c], a
    ldh a, [$ffbf]
    add a, $10
    ld [$c490], a
    xor a, a
    ld [$c493], a
    ld de, D_00_3f3a
    call SetObjectTarget
    ld a, $90
    ldh [$ffd1], a
    ret
D_00_3f3a::
    INCBIN "orig/painter_momopie.gb", $03f3a, 10
D_00_3f44::
    INCBIN "orig/painter_momopie.gb", $03f44, 8
D_00_3f4c::
    INCBIN "orig/painter_momopie.gb", $03f4c, 180

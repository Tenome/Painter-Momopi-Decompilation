INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank01", ROMX[$4000], BANK[1]

    INCBIN "orig/painter_momopie.gb", $04000, 72
SoundSongTable::  ; word offsets of song data (follows the frequency table at $4000)
    INCBIN "orig/painter_momopie.gb", $04048, 172
SoundCommandDataTable::  ; per command word pointers used by SoundStartCommand
    INCBIN "orig/painter_momopie.gb", $040f4, 38
D_01_411a::
    INCBIN "orig/painter_momopie.gb", $0411a, 39
D_01_4141::
    INCBIN "orig/painter_momopie.gb", $04141, 22
SoundUpdate::  ; per-frame sound engine called from VBlankHandler
    ld a, [wSoundBusy]
    and a, a
    jr nz, .L_01_4160
    call SoundDequeue
.L_01_4160:
    call SoundStartCommand
    call SoundAssignChannels
    ld a, $08
    ld [$c30d], a
    ld bc, wSoundChannels
    ld h, b
    ld l, c
.L_01_4170:
    ld a, [hl]
    bit 7, a
    jr z, .L_01_4178
    call SoundUpdateChannel
.L_01_4178:
    ld a, [$c30d]
    dec a
    ld [$c30d], a
    jr z, .L_01_418b
    ld de, $0020
    ld h, b
    ld l, c
    add hl, de
    ld b, h
    ld c, l
    jr .L_01_4170
.L_01_418b:
    ret
SoundDequeue::  ; pops the next command from the queue into wSoundCmd
    ld a, [wSoundQueueLen]
    and a, a
    jr z, .L_01_41ac
    ld a, [wSoundQueue]
    ld [wSoundCmd], a
    ld hl, wSoundQueue
    ld de, $c318
    ld a, [wSoundQueueLen]
    ld c, a
.L_01_41a2:
    ld a, [de]
    ld [hl+], a
    inc de
    dec c
    jr nz, .L_01_41a2
    ld hl, wSoundQueueLen
    dec [hl]
.L_01_41ac:
    ret
SoundStartCommand::  ; commands >= $80 index word tables at $40f4 and $411a
    ld a, [wSoundCmd]
    bit 7, a
    jr z, .L_01_41d5
    cp a, $94
    jr nc, .L_01_41d6
    sub a, $80
    jr z, .L_01_41d5
    ld hl, SoundCommandDataTable
    ld c, a
    ld b, $00
    add hl, bc
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    ld hl, D_01_411a
    add hl, bc
    add hl, bc
    ld a, [hl+]
    ld b, a
    ld a, [hl]
    ld h, a
    ld l, b
    ld b, $00
    jp hl
.L_01_41d5:
    ret
.L_01_41d6:
    ld de, D_01_4332
    ld b, $00
    jp L_01_4271
L_01_41de::
    ld a, $00
    ld [wSoundChannels], a
    ld [$c347], a
    ld [$c367], a
    ld [$c387], a
    ld [$c3a7], a
    ld [$c3c7], a
    ld [$c3e7], a
    ld [$c407], a
    ld a, $77
    ld [$c315], a
L_01_41fd::
    ld a, $00
    ld [rNR30], a
    ld [rNR51], a
    ld a, $08
    ld [rNR10], a
    ld a, $f0
    ld [rNR12], a
    ld [rNR22], a
    ld [rNR42], a
    ld a, $80
    ld [rNR30], a
    ld a, $ff
    ld [rNR13], a
    ld [rNR23], a
    ld [rNR33], a
    ld [rNR43], a
    ld a, [$c315]
    ld [rNR50], a
    ld a, $87
    ld [rNR14], a
    ld [rNR24], a
    ld [rNR34], a
    ld [rNR44], a
L_01_423c::
    ld a, $00
    ld [$c427], a
    ld [$c428], a
    ld [$c429], a
    ld [$c42a], a
    ld [$c42b], a
    ld [$c42c], a
    ld [$c42d], a
    ld [$c42e], a
    ld [$c42f], a
    ld [$c430], a
    ld [$c431], a
    ld [$c432], a
    ret
L_01_4263::
    ld hl, D_01_4141
    add hl, bc
    ld a, [hl]
    ld b, a
    ld a, [$c30f]
    cp a, b
    jr z, L_01_4271
    jr nc, L_01_428c
L_01_4271::
    ld a, b
    ld [$c30f], a
    call L_01_41de
    ld a, $00
    ld [wSoundChannels], a
    ld [$c347], a
    ld [$c367], a
    ld [$c387], a
    ld hl, wSoundChannels
    jp L_01_4306
L_01_428c::
    ld a, $80
    ld [wSoundCmd], a
    ret
L_01_4292::
    ld hl, D_01_4141
    add hl, bc
    ld a, [hl]
    ld b, a
    ld a, [$c310]
    cp a, b
    jr z, .L_01_42a0
    jr nc, L_01_428c
.L_01_42a0:
    ld a, b
    ld [$c310], a
    call L_01_423c
    ld a, $00
    ld [$c3a7], a
    ld [$c3c7], a
    ld [$c3e7], a
    ld [$c407], a
    ld hl, $c3a7
    jp L_01_4306
L_01_42bb::
    ld a, [$c310]
    inc a
    ld [$c310], a
    ld hl, wSoundChannels
    push de
    ld de, $0020
    ld a, [hl]
    or a, $10
    ld [hl], a
    add hl, de
    ld a, [hl]
    or a, $10
    ld [hl], a
    add hl, de
    ld a, [hl]
    or a, $10
    ld [hl], a
    add hl, de
    ld a, [hl]
    or a, $10
    ld [hl], a
    pop de
    jr L_01_4292
L_01_42df::
    call L_01_423c
    ld a, [$c310]
    inc a
    ld [$c310], a
    ld hl, wSoundChannels
    push de
    ld de, $0020
    ld a, [hl]
    and a, $ef
    ld [hl], a
    add hl, de
    ld a, [hl]
    and a, $ef
    ld [hl], a
    add hl, de
    ld a, [hl]
    and a, $ef
    ld [hl], a
    add hl, de
    ld a, [hl]
    and a, $ef
    ld [hl], a
    pop de
    jr L_01_4292
L_01_4306::
    ld a, [de]
    ld [$c30b], a
    inc de
.L_01_430b:
    ld b, $0a
.L_01_430d:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .L_01_430d
    ld a, $20
    ld [hl], a
    inc hl
    ld a, $01
    ld [hl], a
    inc hl
    xor a, a
    ld b, $14
.L_01_431f:
    ld [hl+], a
    dec b
    jr nz, .L_01_431f
    ld a, [$c30b]
    dec a
    ld [$c30b], a
    jr nz, .L_01_430b
    ld a, $80
    ld [wSoundCmd], a
    ret
D_01_4332::
    INCBIN "orig/painter_momopie.gb", $04332, 44
SoundAssignChannels::
    ld d, $04
    ld hl, wSoundChannels
    ld bc, $0020
.L_01_4366:
    ld a, [hl]
    and a, $fb
    ld [hl], a
    add hl, bc
    dec d
    jr nz, .L_01_4366
    ld hl, wSoundChannels
    ld a, $04
    ld [wSoundArg], a
    ld de, $c3a7
.L_01_4379:
    ld a, [de]
    bit 7, a
    inc de
    jr z, .L_01_438b
    ld a, [de]
    and a, a
    jr z, .L_01_4387
.L_01_4383:
    add hl, bc
    dec a
    jr nz, .L_01_4383
.L_01_4387:
    ld a, [hl]
    or a, $04
    ld [hl], a
.L_01_438b:
    ld a, [wSoundArg]
    dec a
    jr z, .L_01_43a2
    ld [wSoundArg], a
    dec de
    ld h, d
    ld l, e
    ld de, $0020
    add hl, de
    ld d, h
    ld e, l
    ld hl, wSoundChannels
    jr .L_01_4379
.L_01_43a2:
    ret
SoundUpdateChannel::  ; one of 8 channel records of $20 bytes at wSoundChannels
    ld a, [bc]
    bit 4, a
    ret nz
    ld hl, $0009
    add hl, bc
    ld a, [hl]
    ld e, a
    ld hl, $0008
    add hl, bc
    ld a, [hl]
    add a, e
    inc hl
    ld [hl], a
    jr nc, .L_01_43d5
    ld hl, $000c
    add hl, bc
    ld a, [hl]
    inc a
    ld [hl], a
    ld d, a
    ld hl, $000b
    add hl, bc
    ld a, [hl]
    cp a, d
    jr nz, .L_01_43d5
    call SoundReadNextNote
    ld a, [bc]
    bit 0, a
    jr z, .L_01_43d5
    xor a, a
    ld hl, $000d
    add hl, bc
    ld [hl], a
.L_01_43d5:
    ld h, b
    ld l, c
    ld a, [hl]
    bit 2, a
    ret nz
    call SoundApplyPitchSlide
    ld hl, $0001
    add hl, bc
    ld a, [hl]
    cp a, $03
    jr nz, .L_01_43eb
    ld hl, $4572
    jp hl
.L_01_43eb:
    cp a, $02
    jr nz, .L_01_43f3
    ld hl, $4504
    jp hl
.L_01_43f3:
    cp a, $01
    jr nz, .L_01_43fb
    ld hl, $4484
    jp hl
.L_01_43fb:
    cp a, $00
    jr nz, .L_01_4403
    ld hl, $4404
    jp hl
.L_01_4403:
    ret
SoundWriteChannel1::  ; writes pulse channel 1 registers (NR11 NR12 NR13/NR14) from the channel record
    ld hl, $0015
    add hl, bc
    ld a, [hl]
    and a, $c0
    ld [rNR11], a
    ld hl, $0007
    add hl, bc
    ld a, [$c427]
    cp a, [hl]
    jr z, .L_01_441f
    ld a, [hl]
    ld [$c427], a
    ld [rNR12], a
.L_01_441f:
    ld hl, $0012
    add hl, bc
    ld a, [hl+]
    or a, [hl]
    jr z, L_01_4473
    dec hl
    push hl
    ld hl, $0002
    add hl, bc
    ld a, [rNR51]
    or a, $11
    and a, [hl]
    ld [rNR51], a
    pop hl
    ld a, [bc]
    bit 0, a
    jr nz, .L_01_4449
    ld a, [$c428]
    cp a, [hl]
    jr nz, .L_01_4449
    inc hl
    ld a, [$c429]
    cp a, [hl]
    ret z
    dec hl
.L_01_4449:
    ld a, [hl+]
    ld [rNR13], a
    ld [$c428], a
    ld a, [hl]
    ld [$c429], a
    and a, $07
    or a, $80
    ld [wSoundArg], a
    ld a, [bc]
    bit 0, a
    jr nz, .L_01_4468
    ld a, [wSoundArg]
    and a, $7f
    ld [wSoundArg], a
.L_01_4468:
    ld a, [bc]
    and a, $fe
    ld [bc], a
    ld a, [wSoundArg]
    ld [rNR14], a
    ret
L_01_4473::
    ld a, $ff
    ld [rNR13], a
    ld [$c428], a
    ld a, $87
    ld [rNR14], a
    ld [$c429], a
    ret
SoundWriteChannel2::  ; writes pulse channel 2 registers (NR21 NR22 NR23/NR24)
    ld hl, $0015
    add hl, bc
    ld a, [hl]
    and a, $c0
    ld [rNR21], a
    ld hl, $0007
    add hl, bc
    ld a, [$c42a]
    cp a, [hl]
    jr z, .L_01_449f
    ld a, [hl]
    ld [$c42a], a
    ld [rNR22], a
.L_01_449f:
    ld hl, $0012
    add hl, bc
    ld a, [hl+]
    or a, [hl]
    jr z, L_01_44f3
    dec hl
    push hl
    ld hl, $0002
    add hl, bc
    ld a, [rNR51]
    or a, $22
    and a, [hl]
    ld [rNR51], a
    pop hl
    ld a, [bc]
    bit 0, a
    jr nz, .L_01_44c9
    ld a, [$c42b]
    cp a, [hl]
    jr nz, .L_01_44c9
    inc hl
    ld a, [$c42c]
    cp a, [hl]
    ret z
    dec hl
.L_01_44c9:
    ld a, [hl+]
    ld [rNR23], a
    ld [$c42b], a
    ld a, [hl]
    ld [$c42c], a
    and a, $07
    or a, $80
    ld [wSoundArg], a
    ld a, [bc]
    bit 0, a
    jr nz, .L_01_44e8
    ld a, [wSoundArg]
    and a, $7f
    ld [wSoundArg], a
.L_01_44e8:
    ld a, [bc]
    and a, $fe
    ld [bc], a
    ld a, [wSoundArg]
    ld [rNR24], a
    ret
L_01_44f3::
    ld a, $ff
    ld [rNR23], a
    ld [$c42b], a
    ld a, $87
    ld [rNR24], a
    ld [$c42c], a
    ret
SoundWriteChannel3::  ; writes wave channel 3 registers (NR32 NR33/NR34)
    ld hl, $0012
    add hl, bc
    ld a, [hl+]
    or a, [hl]
    jr z, L_01_4561
    ld hl, $0007
    add hl, bc
    ld a, [$c42d]
    cp a, [hl]
    jr z, .L_01_451f
    ld a, [hl]
    ld [$c42d], a
    and a, $60
    ld [rNR32], a
.L_01_451f:
    ld hl, $0002
    add hl, bc
    ld a, [rNR51]
    or a, $44
    and a, [hl]
    ld [rNR51], a
    ld hl, $0012
    add hl, bc
    ld a, [$c42e]
    cp a, [hl]
    jr nz, .L_01_453d
    inc hl
    ld a, [$c42f]
    cp a, [hl]
    ret z
    dec hl
.L_01_453d:
    ld a, [hl+]
    ld [rNR33], a
    ld [$c42e], a
    ld a, [hl]
    ld [$c42f], a
    and a, $07
    ld [wSoundArg], a
    ld a, [bc]
    bit 5, a
    jr z, .L_01_455a
    ld a, [wSoundArg]
    and a, $7f
    ld [wSoundArg], a
.L_01_455a:
    ld a, [wSoundArg]
    ld [rNR34], a
    ret
L_01_4561::
    ld a, $ff
    ld [rNR33], a
    ld [$c42e], a
    ld a, $07
    ld [rNR34], a
    ld [$c42f], a
    ret
SoundWriteChannel4::  ; writes noise channel 4 registers (NR42 NR43 NR44)
    ld hl, $0007
    add hl, bc
    ld a, [$c430]
    cp a, [hl]
    jr z, .L_01_4583
    ld a, [hl]
    ld [$c430], a
    ld [rNR42], a
.L_01_4583:
    ld hl, $0012
    add hl, bc
    ld a, [hl]
    and a, a
    jr z, L_01_45c3
    push hl
    ld hl, $0002
    add hl, bc
    ld a, [rNR51]
    or a, $88
    and a, [hl]
    ld [rNR51], a
    pop hl
    ld a, [$c431]
    cp a, [hl]
    ret z
    ld a, [hl]
    ld [rNR43], a
    ld [$c431], a
    ld a, $80
    ld [wSoundArg], a
    ld a, [bc]
    bit 0, a
    jr z, .L_01_45b8
    ld a, [wSoundArg]
    and a, $7f
    ld [wSoundArg], a
.L_01_45b8:
    ld a, [bc]
    and a, $fe
    ld [bc], a
    ld a, [wSoundArg]
    ld [rNR44], a
    ret
L_01_45c3::
    ld a, $ff
    ld [rNR43], a
    ld [$c431], a
    ld a, $80
    ld [rNR44], a
    ret
L_01_45d1::
    and a, $1f
    cp a, $03
    jr z, L_01_45ef
    sla a
    push de
    ld e, a
    ld d, $00
    ld hl, $467b
    add hl, de
    ld d, h
    ld e, l
    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
    pop de
    call L_01_467a
    jp L_01_461f
L_01_45ef::
    ld a, $00
    ld [$c30f], a
L_01_45f4::
    ld [bc], a
    ld hl, $0001
    add hl, bc
    ld a, [hl]
    cp a, $03
    call z, L_01_45c3
    ld a, [hl]
    cp a, $02
    call z, L_01_4561
    ld a, [hl]
    cp a, $01
    call z, L_01_44f3
    ld a, [hl]
    cp a, $00
    call z, L_01_4473
    pop hl
    ret
SoundReadNextNote::  ; reads the next note byte from the channel's song pointer (+3/+4); bytes >= $e0 are commands
    ld a, [bc]
    or a, $01
    ld [bc], a
    ld hl, $0003
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
L_01_461f::
    ld a, [de]
    inc de
    cp a, $e0
    jr nc, L_01_45d1
    bit 7, a
    jr z, .L_01_4666
    cp a, $80
    jr z, .L_01_4632
    ld hl, $0005
    add hl, bc
    add a, [hl]
.L_01_4632:
    sla a
    push de
    ld e, a
    ld d, $00
    ld hl, SoundSongTable
    add hl, de
    ld d, h
    ld e, l
    ld a, [de]
    inc de
    ld hl, $000e
    add hl, bc
    ld [hl+], a
    ld a, [de]
    ld [hl], a
    pop de
    ld hl, $000e
    add hl, bc
    ld a, [hl+]
    inc hl
    ld [hl-], a
    ld a, [hl+]
    inc hl
    ld [hl], a
    ld a, [bc]
    bit 5, a
    jr z, .L_01_465e
    ld a, [de]
    inc de
    ld hl, $0014
    add hl, bc
    ld [hl], a
.L_01_465e:
    ld a, [de]
    bit 7, a
    jr z, .L_01_4665
    jr .L_01_466b
.L_01_4665:
    inc de
.L_01_4666:
    ld hl, $000b
    add hl, bc
    ld [hl], a
.L_01_466b:
    ld a, e
    ld hl, $0003
    add hl, bc
    ld [hl+], a
    ld a, d
    ld [hl], a
    xor a, a
    ld hl, $000c
    add hl, bc
    ld [hl], a
    ret
L_01_467a::
    jp hl
    dw L_01_469f
    dw L_01_469f
    dw L_01_46bf
    dw L_01_45ef
    dw L_01_46d7
    dw L_01_46ed
    dw L_01_46fd
    dw L_01_4705
    dw L_01_470e
    INCBIN "orig/painter_momopie.gb", $0468d, 2
    dw L_01_4728
    dw L_01_4776
    dw L_01_478e
    dw L_01_4793
    dw L_01_4798
    dw L_01_479d
    dw L_01_4718
    INCBIN "orig/painter_momopie.gb", $0469d, 2
L_01_469f::
    ld hl, $000a
    add hl, bc
    dec [hl]
    ld a, [hl]
    dec [hl]
    ld l, a
    ld h, $00
    add hl, bc
    inc de
    inc de
    ld a, d
    ld [hl-], a
    ld a, e
    ld [hl], a
    ld hl, $0003
    add hl, bc
    dec de
    dec de
    ld a, [de]
    inc de
    ld [hl+], a
    ld a, [de]
    ld [hl-], a
    ld d, a
    ld a, [hl]
    ld e, a
    ret
L_01_46bf::
    ld hl, $000a
    add hl, bc
    ld a, [hl]
    inc [hl]
    inc [hl]
    ld l, a
    ld h, $00
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    ld hl, $0003
    add hl, bc
    ld a, e
    ld [hl+], a
    ld a, d
    ld [hl], a
    ret
L_01_46d7::
    ld hl, $0017
    add hl, bc
    ld a, [de]
    inc de
    add a, l
    ld l, a
    ld a, h
    adc a, $00
    ld h, a
    ld a, [hl]
    and a, a
    jr nz, .L_01_46e9
    ld a, [de]
    ld [hl], a
.L_01_46e9:
    inc de
    dec [hl]
    jr z, L_01_46fa
L_01_46ed::
    ld a, [de]
    inc de
    ld hl, $0003
    add hl, bc
    ld [hl+], a
    ld a, [de]
    ld [hl-], a
    ld d, a
    ld a, [hl]
    ld e, a
    ret
L_01_46fa::
    inc de
    inc de
    ret
L_01_46fd::
    ld hl, $0007
L_01_4700::
    add hl, bc
    ld a, [de]
    inc de
    ld [hl], a
    ret
L_01_4705::
    ld hl, $0005
    add hl, bc
    ld a, [de]
    inc de
    add a, [hl]
    ld [hl], a
    ret
L_01_470e::
    ld hl, $0015
    jr L_01_4700
    INCBIN "orig/painter_momopie.gb", $04713, 5
L_01_4718::
    ld hl, $0006
    jr L_01_4700
    INCBIN "orig/painter_momopie.gb", $0471d, 5
L_01_4722::
    ld a, [de]
    inc de
    ld [$c312], a
    ret
L_01_4728::
    ld a, [bc]
    bit 2, a
    jr nz, L_01_4722
    ld a, [de]
    inc de
    ld hl, $c314
    cp a, [hl]
    jr z, L_01_4775
    ld [hl], a
    ld hl, wSoundChannels
    ld a, c
    sub a, l
    cp a, $60
    jr nc, .L_01_4747
    ld a, [$c314]
    ld [$c312], a
    jr L_01_474d
.L_01_4747:
    ld a, [$c314]
    ld [$c313], a
L_01_474d::
    push bc
    ld bc, $3fb8
    sla a
    ld l, a
    ld h, $00
    add hl, bc
    xor a, a
    ld [rNR30], a
    ld b, h
    ld c, l
    ld a, [bc]
    ld l, a
    inc bc
    ld a, [bc]
    ld h, a
    ld c, $30
    ld b, $10
.L_01_4766:
    ld a, [hl+]
    ldh [c], a
    inc c
    dec b
    jr nz, .L_01_4766
    pop bc
    ld a, $80
    ld [rNR30], a
    call L_01_41fd
L_01_4775::
    ret
L_01_4776::
    ld a, $00
    ld [$c310], a
    ld a, [$c312]
    ld hl, $c314
    cp a, [hl]
    jr z, .L_01_4788
    ld [hl], a
    call L_01_474d
.L_01_4788:
    ld a, $00
    pop hl
    jp L_01_45f4
L_01_478e::
    ld a, [bc]
    or a, $20
    ld [bc], a
    ret
L_01_4793::
    ld a, [bc]
    and a, $df
    ld [bc], a
    ret
L_01_4798::
    ld a, [bc]
    and a, $fe
    ld [bc], a
    ret
L_01_479d::
    ld a, [de]
    inc de
    ld [rNR50], a
    ld [$c315], a
    ret
SoundApplyPitchSlide::  ; copies the pitch word at +$e into +$12 (frequency) for the channel writers
    ld hl, $000e
    add hl, bc
    ld a, [hl+]
    ld d, a
    ld a, [hl]
    ld hl, $0013
    add hl, bc
    ld [hl-], a
    ld a, d
    ld [hl], a
    ld hl, $000e
    add hl, bc
    ld a, [hl+]
    or a, [hl]
    ret z
    ld a, [bc]
    bit 5, a
    call nz, L_01_4820
    ld hl, $0006
    add hl, bc
    ld a, [hl]
    and a, a
    call nz, L_01_47cb
    ret
L_01_47cb::
    ld hl, $0006
    add hl, bc
    ld a, [hl]
    sla a
    ld e, a
    ld d, $00
    ld hl, D_00_3f4c
    add hl, de
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    ld hl, $000d
    add hl, bc
    ld a, [hl]
    inc [hl]
    ld l, a
    ld h, $00
    add hl, de
    ld a, [hl]
    ld [$c30b], a
    cp a, $80
    jr z, .L_01_4809
    cp a, $81
    jr z, .L_01_4812
    cp a, $82
    jr z, .L_01_481a
    cp a, $83
    jr z, .L_01_4800
    ld hl, $0012
    jr L_01_4837
.L_01_4800:
    inc hl
    ld a, [hl]
    ld hl, $000d
    add hl, bc
    ld [hl], a
    jr L_01_47cb
.L_01_4809:
    ld a, $00
    ld hl, $000d
    add hl, bc
    ld [hl], a
    jr L_01_47cb
.L_01_4812:
    ld hl, $000d
    add hl, bc
    dec [hl]
    dec [hl]
    jr L_01_47cb
.L_01_481a:
    ld hl, $000d
    add hl, bc
    dec [hl]
    ret
L_01_4820::
    ld hl, $0014
    add hl, bc
    ld a, [hl]
    ld [$c30b], a
    ld hl, $0010
    call L_01_4837
    ld hl, $0011
    add hl, bc
    ld a, d
    ld [hl-], a
    ld a, e
    ld [hl], a
    ret
L_01_4837::
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    ld a, [$c30b]
    and a, a
    bit 7, a
    jr nz, .L_01_484c
    add a, e
    ld e, a
    ld a, $00
    adc a, d
    ld d, a
    jr .L_01_4853
.L_01_484c:
    add a, e
    ld e, a
    ld a, d
    ccf
    sbc a, $00
    ld d, a
.L_01_4853:
    ld hl, $0013
    add hl, bc
    ld [hl-], a
    ld a, e
    ld [hl], a
    ret
PlaySound_Bank1::  ; appends wSoundArg to the sound command queue
    ld a, $01
    ld [wSoundBusy], a
    push hl
    push de
    ld hl, wSoundQueue
    ld a, [wSoundQueueLen]
    ld e, a
    ld d, $00
    add hl, de
    inc a
    ld [wSoundQueueLen], a
    ld a, [wSoundArg]
    ld [hl], a
    pop de
    pop hl
    xor a, a
    ld [wSoundBusy], a
    ret
    INCBIN "orig/painter_momopie.gb", $0487b, 17
D_01_488c::
    INCBIN "orig/painter_momopie.gb", $0488c, 56
PlayerAnimPtrs::  ; player animation pointers (down/up/side) chosen by SelectPlayerAnimation
    INCBIN "orig/painter_momopie.gb", $048c4, 8
PlayerAnimPtrsFlipped::  ; pointers for the side animation drawn flipped
    INCBIN "orig/painter_momopie.gb", $048cc, 8
D_01_48d4::
    INCBIN "orig/painter_momopie.gb", $048d4, 71
D_01_491b::
    INCBIN "orig/painter_momopie.gb", $0491b, 6
D_01_4921::
    INCBIN "orig/painter_momopie.gb", $04921, 6
D_01_4927::
    INCBIN "orig/painter_momopie.gb", $04927, 2
L_01_4929::
    rlca
    ld c, l
    rlca
    inc b
    rlca
    dec b
L_01_492f::
    ld hl, wGameFlags
    res 7, [hl]
    res 0, [hl]
    ret
L_01_4937::
    ld a, [wRound]
    cp a, $04
    jr z, .L_01_4951
    cp a, $08
    jr z, .L_01_4951
    cp a, $0c
    jr z, .L_01_4951
    cp a, $14
    jr z, .L_01_4951
    cp a, $18
    jr z, .L_01_4951
    cp a, $1c
    ret nz
.L_01_4951:
    ld hl, wGameFlags
    set 6, [hl]
    ret
L_01_4957::
    ld a, $82
    call PlaySound
    ld hl, wSubState
    set 1, [hl]
    ret
L_01_4962::
    ld hl, $ffdf
    dec [hl]
    ret nz
L_01_4967::
    xor a, a
    ld [wSubState], a
    ret
L_01_496c::
    ld hl, $c4fe
    call Clear32Bytes
    ld a, $08
    ld [$c1f7], a
    ld a, $07
    ldh [$ffdf], a
    ld hl, wPlayerStatus
    set 4, [hl]
    ld a, $2a
    ld [$c50f], a
    ld hl, $4929
    ld a, l
    ld [$c4ff], a
    ld a, h
    ld [$c500], a
    ld a, $08
    ld [$c449], a
    ld a, $82
    ld [$c4fe], a
    call L_01_4a9d
    jp L_01_4957
L_01_49a0::
    ld a, $0f
    ldh [$ff96], a
.L_01_49a4:
    ldh a, [$ff96]
    ld hl, EnemySlotTable
    sla a
    ld c, a
    ld b, $00
    add hl, bc
    ld a, [hl+]
    push af
    ld a, [hl]
    ld h, a
    pop af
    ld l, a
    ld a, [hl]
    bit 7, a
    jr z, .L_01_49cc
    push hl
    ld e, $1f
    ld d, $00
    add hl, de
    ld a, [hl]
    set 2, a
    ld [hl], a
    pop hl
    ld e, $14
    ld d, $00
    add hl, de
    xor a, a
    ld [hl], a
.L_01_49cc:
    ld hl, $ff96
    dec [hl]
    ld a, [hl]
    bit 7, a
    ret nz
    jr .L_01_49a4
L_01_49d6::
    ld hl, $c4fe
    call Clear32Bytes
    ld hl, $492b
    ld a, l
    ld [$c4ff], a
    ld a, h
    ld [$c500], a
    ld a, $20
    ld [$c50f], a
    ld a, [$c4ce]
    ld [$c50e], a
    ld a, $86
    ld [$c4fe], a
    ld a, [$c4c4]
    ld [$c504], a
    ld a, [wPlayerX]
    ld [$c505], a
    ld a, [$c4c6]
    ld [$c506], a
    ld a, [$c4c7]
    ld [$c507], a
    ld a, [wPlayerY]
    ld [$c508], a
    ld a, [$c4c9]
    ld [$c509], a
    ld a, $01
    ld [$c502], a
    ld a, $8d
    call PlaySound
    ld a, $d0
    ldh [$ffdf], a
    ld hl, wSubState
    set 4, [hl]
    set 1, [hl]
    ret
L_01_4a31::
    ld a, [$c519]
    and a, $02
    jr z, .L_01_4a3d
    ld hl, D_01_4927
    jr .L_01_4a40
.L_01_4a3d:
    ld hl, $4929
.L_01_4a40:
    ld a, l
    ld [$c4ff], a
    ld a, h
    ld [$c500], a
    ret
L_01_4a49::
    ld a, [$c1b6]
    ld e, $07
    call MultiplyByDE
    ld c, a
    ld b, $00
    ld hl, $c1b7
    add hl, bc
    ld a, [hl+]
    ld [$c504], a
    ld a, [hl+]
    ld [$c505], a
    ld a, [hl+]
    ld [$c506], a
    ld a, [hl+]
    ld [$c507], a
    ld a, [hl+]
    ld [$c508], a
    ld a, [hl+]
    ld [$c509], a
    ld a, [hl]
    ld [$c50e], a
    ret
L_01_4a75::
    ld a, [$c1b6]
    ld e, $07
    call MultiplyByDE
    ld c, a
    ld b, $00
    ld hl, $c1b7
    add hl, bc
    ld a, [$c504]
    ld [hl+], a
    ld a, [$c505]
    ld [hl+], a
    ld a, [$c506]
    ld [hl+], a
    ld a, [$c507]
    ld [hl+], a
    ld a, [$c508]
    ld [hl+], a
    ld a, [$c509]
    ld [hl], a
    ret
L_01_4a9d::
    ld bc, $0040
    ld hl, $c1b7
    call ClearMemory
    ld hl, $c1b7
    ld d, $10
    ld e, $00
    ld a, $08
    call L_01_4b03
    ld hl, $c1be
    ld d, $10
    ld e, $f0
    ld a, $04
    call L_01_4b03
    ld hl, $c1c5
    ld d, $00
    ld e, $f0
    ld a, $00
    call L_01_4b03
    ld hl, $c1cc
    ld d, $f0
    ld e, $00
    ld a, $1c
    call L_01_4b03
    ld hl, $c1d3
    ld d, $f0
    ld e, $00
    ld a, $18
    call L_01_4b03
    ld hl, $c1da
    ld d, $f0
    ld e, $10
    ld a, $14
    call L_01_4b03
    ld hl, $c1e1
    ld d, $00
    ld e, $10
    ld a, $10
    call L_01_4b03
    ld hl, $c1e8
    ld d, $10
    ld e, $10
    ld a, $0c
L_01_4b03::
    push hl
    ld bc, $0006
    add hl, bc
    ld [hl], a
    pop hl
    push hl
    ld a, [wPlayerX]
    add a, d
    ld bc, $0001
    add hl, bc
    ld [hl], a
    pop hl
    ld a, [wPlayerY]
    add a, e
    ld bc, $0004
    add hl, bc
    ld [hl], a
    ret
SelectPlayerAnimation::  ; picks the animation table by direction
    ld a, [wPlayerDir]
    bit 0, a
    jr nz, .L_01_4b38
    bit 1, a
    jr nz, .L_01_4b42
    bit 2, a
    jr nz, .L_01_4b4c
    ld hl, PlayerAnimPtrs
    jr .L_01_4b4f
    INCBIN "orig/painter_momopie.gb", $04b33, 5
.L_01_4b38:
    ld hl, wPlayer
    set 5, [hl]
    ld hl, PlayerAnimPtrsFlipped
    jr .L_01_4b4f
.L_01_4b42:
    ld hl, wPlayer
    res 5, [hl]
    ld hl, PlayerAnimPtrsFlipped
    jr .L_01_4b4f
.L_01_4b4c:
    ld hl, D_01_48d4
.L_01_4b4f:
    ld a, l
    ld [$c4e3], a
    ld a, h
    ld [$c4e4], a
    ret
PixelXToColumn::  ; E = (X+8)/16 - 1
    add a, $08
    and a, $f0
    swap a
    sub a, $01
    ld e, a
    ret
LookupMapTile::  ; A = wRoomMap tile at pixel Y with column E
    push bc
    sub a, $18
    add a, e
    ld hl, wRoomMap
    ld c, a
    call LookupByte
    pop bc
    ret
IsOnTileGrid::  ; B = X and C = Y: Z when both are multiples of 16
    ld a, b
    and a, $0f
    ret nz
    ld a, c
    and a, $0f
    cp a, $08
    ret
L_01_4b79::
    xor a, a
    ld [$c43b], a
    call IsOnTileGrid
    ret nz
    ld a, b
    call PixelXToColumn
    ld a, c
    sub a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_01_4b98
    ld a, $04
    ld [$c43b], a
    ldh [$ffc7], a
.L_01_4b98:
    ld a, c
    add a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_01_4bae
    ld a, [$c43b]
    or a, $08
    ld [$c43b], a
    ldh [$ffc7], a
.L_01_4bae:
    ld a, e
    sub a, $01
    ld e, a
    ld a, c
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_01_4bc6
    ld a, [$c43b]
    or a, $02
    ld [$c43b], a
    ldh [$ffc7], a
.L_01_4bc6:
    ld a, e
    add a, $02
    ld e, a
    ld a, c
    call LookupMapTile
    and a, $0f
    or a, $00
    ret nz
    ld a, [$c43b]
    or a, $01
    ld [$c43b], a
    ldh [$ffc7], a
    ret
PlayFrame::  ; one frame of play mode: input; movement; collisions; drawing the player
    ld a, [wGameFlags]
    bit 0, a
    jp nz, RoundCleared
    ldh a, [hSerialByte]
    bit 2, a
    jr z, .L_01_4bf6
    bit 7, a
    jp nz, L_01_50b1
    bit 3, a
    jp nz, L_01_50b1
.L_01_4bf6:
    ld a, [wPlayerDir]
    bit 5, a
    jp z, .L_01_4c01
    jp PlayerDeath
.L_01_4c01:
    call PlayerAction
    ld a, [wRoomType]
    cp a, $02
    jr nz, .L_01_4c12
    ld a, [wSubState]
    bit 0, a
    jr nz, .L_01_4c1b
.L_01_4c12:
    call L_01_4c4e
    call LoadPlayerXY
    call L_01_4b79
.L_01_4c1b:
    call HoldDirectionUntilAligned
    call PlayerSetDirection
    call ClampPlayerPosition
    call CheckPlayerTileCollision
    call SelectPlayerAnimation
    call L_00_32a2
    ld a, [wRoomType]
    or a, a
    jr z, .L_01_4c42
    ld a, [wSubState]
    bit 0, a
    jr z, .L_01_4c42
    ld hl, $c4d3
    inc [hl]
    ld a, [hl]
    and a, $02
    ret z
.L_01_4c42:
    call L_01_4f5a
    ld hl, wPlayer
    call SetObjPtr
    jp DrawObject
L_01_4c4e::
    ld a, [wPlayerX]
    ld b, a
    ld a, [wPlayerY]
    ld c, a
    call IsOnTileGrid
    ret nz
    ld a, [wPlayerX]
    call PixelXToColumn
    ld a, [wPlayerY]
    call LookupMapTile
    and a, $0f
    ret nz
    ld hl, wPlayerDir
    set 5, [hl]
    ret
PlayerAction::  ; handles the A button (paint action)
    ld a, [wSubState]
    bit 0, a
    jr nz, L_01_4cbc
    ldh a, [hJoyNew]
    bit 0, a
    ret z
    ld hl, wPlayerDir
    set 6, [hl]
    ld hl, wSubState
    res 1, [hl]
    ld a, [wRoomType]
    and a, a
    ret z
    ld a, [wPlayerStatus]
    bit 0, a
    ret z
    ld hl, wSubState
    set 0, [hl]
    ld hl, RoomTypeTable
    ld a, [wRoomType]
    ld c, a
    call LookupByte
    ld c, a
    ld a, [$c44a]
    sub a, c
    ld e, a
    jr z, L_01_4cf3
L_01_4ca7::
    jr c, .L_01_4cae
    ld [$c44a], a
    jr L_01_4cbc
.L_01_4cae:
    ld a, [$c44b]
    and a, a
    jr z, L_01_4ceb
    ld a, e
    ld [$c44a], a
    xor a, a
    ld [$c44b], a
L_01_4cbc::
    ld a, [wSubState]
    res 2, a
    ld [wSubState], a
    ld hl, $4cd7
    ld a, [wRoomType]
    sla a
    ld c, a
    call LookupByte
    inc hl
    ld e, a
    ld a, [hl]
    ld d, a
    push de
    pop hl
    jp hl
L_01_4cd7::
    ld d, l
    ld c, l
    ld d, l
    ld c, l
    ld h, [hl]
    ld c, l
    ld a, e
    ld c, l
    sub a, c
    ld c, l
    and a, d
    ld c, l
    ld b, h
    ld c, l
    ld b, $4e
    ld [hl], a
    ld c, [hl]
    cp a, b
    ld c, l
L_01_4ceb::
    xor a, a
    ld [wRoomType], a
    ld [wSubState], a
    ret
L_01_4cf3::
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_01_4ca7
    ld a, [$c44b]
    and a, a
    jr nz, L_01_4ca7
    ldh a, [hSerialByte]
    and a, $20
    ld [$c7bf], a
    ld a, [rSC]
    res 7, a
    ld [rSC], a
    ld a, $02
    ld [rSB], a
    ld a, [rSC]
    set 0, a
    ld [rSC], a
    ld a, [rSC]
    set 7, a
    ld [rSC], a
    call WaitSerialByte
    ld a, [rSB]
    cp a, $02
    call z, L_01_4d3e
    ld a, [$c7bf]
    bit 5, a
    call nz, L_01_4d3e
    call SerialStartTransfer
    xor a, a
    ld [$c44a], a
    ret
L_01_4d3e::
    ld hl, hSerialByte
    set 5, [hl]
    ret
L_01_4d44::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4d52
    ld a, $a0
    ldh [$ffdf], a
    call L_01_4957
.L_01_4d52:
    jp L_01_4962
L_01_4d55::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4d63
    ld a, $f0
    ldh [$ffdf], a
    call L_01_4957
.L_01_4d63:
    jp L_01_4962
L_01_4d66::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4d74
    ld a, $d0
    ldh [$ffdf], a
    call L_01_4957
.L_01_4d74:
    xor a, a
    ld [$c43b], a
    jp L_01_4962
L_01_4d7b::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4d8e
    ld a, $d0
    ldh [$ffdf], a
    call L_01_4957
    ld hl, $c49e
    res 7, [hl]
.L_01_4d8e:
    jp L_01_4962
L_01_4d91::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4d9f
    ld a, $b0
    ldh [$ffdf], a
    call L_01_4957
.L_01_4d9f:
    jp L_01_4962
L_01_4da2::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4db5
    ld a, $b0
    ldh [$ffdf], a
    call L_01_4957
    ld hl, $c49e
    res 7, [hl]
.L_01_4db5:
    jp L_01_4962
L_01_4db8::
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4dc2
    call L_01_49d6
.L_01_4dc2:
    ld hl, $c4fe
    call SetObjPtr
    ld hl, $c519
    inc [hl]
    call L_01_4e53
    ld a, [wPlayerX]
    ld c, a
    ld a, [wPlayerY]
    ld b, a
    call L_00_3449
    and a, a
    jr z, .L_01_4de2
    ld hl, $c4fe
    res 7, [hl]
.L_01_4de2:
    call L_01_4dee
    call L_00_0b66
    call L_00_09e0
    jp DrawObject
L_01_4dee::
    ld a, [$c519]
    and a, $02
    jr z, .L_01_4dfa
    ld hl, $492b
    jr .L_01_4dfd
.L_01_4dfa:
    ld hl, $492d
.L_01_4dfd:
    ld a, l
    ld [$c4ff], a
    ld a, h
    ld [$c500], a
    ret
L_01_4e06::
    ld hl, $c519
    ld a, [wSubState]
    bit 1, a
    jr nz, .L_01_4e16
    call L_01_496c
    call L_01_49a0
.L_01_4e16:
    call L_01_4a49
    ld hl, $c4fe
    call SetObjPtr
    call L_00_0b66
    call L_00_09e0
    call DrawObject
    call L_01_4a75
    call L_01_4a31
    ld hl, $c449
    dec [hl]
    jr z, .L_01_4e3a
    ld hl, $c1b6
    inc [hl]
    jr .L_01_4e16
.L_01_4e3a:
    call L_01_4e47
    ld a, $08
    ld [$c449], a
    xor a, a
    ld [$c1b6], a
    ret
L_01_4e47::
    ldh a, [$ffdf]
    dec a
    ldh [$ffdf], a
    ret nz
    xor a, a
    ld [wSubState], a
    jr L_01_4e59
L_01_4e53::
    ld a, [$c4fe]
    bit 2, a
    ret nz
L_01_4e59::
    ld hl, $c4fe
    res 7, [hl]
    ld a, [wRoomType]
    cp a, $09
    jr nz, .L_01_4e6e
    ld a, [wSubState]
    and a, $f8
    ld [wSubState], a
    ret
.L_01_4e6e:
    ld a, [wSubState]
    and a, $08
    ld [wSubState], a
    ret
L_01_4e77::
    ld a, [wSubState]
    bit 1, a
    jp nz, .L_01_4e86
    xor a, a
    ld [$c1f8], a
    call L_01_4957
.L_01_4e86:
    ld hl, $c519
    inc [hl]
    ld a, [$c1f8]
    cp a, $50
    jr z, .L_01_4ea5
    inc a
    ld [$c1f8], a
    ld a, $e4
    ld [rBGP], a
    ld a, [$c519]
    and a, $02
    ret nz
    xor a, a
    ld [rBGP], a
    ret
.L_01_4ea5:
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld bc, $00ff
.L_01_4eb3:
    ld hl, wRoomMap
    add hl, bc
    ld a, [hl]
    bit 7, a
    jr nz, .L_01_4ec5
.L_01_4ebc:
    dec bc
    ld a, c
    cp a, $ff
    jp z, L_01_4967
    jr .L_01_4eb3
.L_01_4ec5:
    and a, $0f
    or a, $10
    ld [hl], a
    ldh [$ff98], a
    push bc
    call L_01_4edd
    call L_01_4f07
    pop bc
    ld hl, wPaintRemaining
    dec [hl]
    jp z, RoundCleared
    jr .L_01_4ebc
L_01_4edd::
    xor a, a
    ldh [$ff96], a
    ld a, $98
    ldh [$ff97], a
.L_01_4ee4:
    ld a, c
    sub a, $10
    jr c, .L_01_4ef8
    ld c, a
    ldh a, [$ff96]
    add a, $40
    ldh [$ff96], a
    ldh a, [$ff97]
    adc a, $00
    ldh [$ff97], a
    jr .L_01_4ee4
.L_01_4ef8:
    sla c
    ld e, c
    ldh a, [$ff96]
    add a, e
    ldh [$ff96], a
    ldh a, [$ff97]
    adc a, $00
    ldh [$ff97], a
    ret
L_01_4f07::
    ld de, D_01_4921
    ldh a, [$ff98]
    and a, $0f
    cp a, $01
    jr z, .L_01_4f15
    ld de, D_01_491b
.L_01_4f15:
    ldh a, [$ff96]
    ld l, a
    ldh a, [$ff97]
    ld h, a
    call QueueVramCopyRows
    jp WaitVramCopyDone
ClampPlayerPosition::  ; keeps the player inside X $20-$f0 and Y $28-$f8
    ld a, [wPlayerX]
    cp a, $21
    jr nc, .L_01_4f2d
    ld a, $20
    ld [wPlayerX], a
.L_01_4f2d:
    ld a, [wPlayerX]
    cp a, $f0
    jr c, .L_01_4f39
    ld a, $f0
    ld [wPlayerX], a
.L_01_4f39:
    ld a, [wPlayerY]
    cp a, $29
    jr nc, .L_01_4f45
    ld a, $28
    ld [wPlayerY], a
.L_01_4f45:
    ld a, [wPlayerY]
    cp a, $f8
    ret c
    ld a, $f8
    ld [wPlayerY], a
    ret
LoadPlayerXY::  ; B = wPlayerX and C = wPlayerY
    ld hl, wPlayerX
    ld b, [hl]
    ld hl, wPlayerY
    ld c, [hl]
    ret
L_01_4f5a::
    ld a, [hJoyHeld]
    and a, $f0
    ret z
    ld hl, $c4d9
    inc [hl]
    ld a, $0c
    ldh [$ff9c], a
    ld a, $02
    ldh [$ff9d], a
    ld a, [$c4d9]
    ldh [$ff9e], a
    ld a, $04
    call L_00_0c2a
    ldh a, [$ff9e]
    ld [$c4d9], a
    ld a, [$c4e3]
    ld e, a
    ld a, [$c4e4]
    ld d, a
    push de
    pop hl
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ld [$c4bf], a
    ld a, [hl]
    ld [$c4c0], a
    ret
HoldDirectionUntilAligned::  ; keeps hJoyHeld direction until the player reaches the next tile
    ld hl, wPlayerX
    ld b, [hl]
    ld hl, wPlayerY
    ld c, [hl]
    call IsOnTileGrid
    ret z
    ld a, [wPlayerDir]
    and a, $0f
    swap a
    ld d, a
    ldh a, [hJoyHeld]
    or a, d
    cp a, $30
    ret z
    cp a, $c0
    ret z
    ldh a, [hJoyHeld]
    and a, $f0
    jr z, .L_01_4fba
    and a, $0f
    or a, d
    ldh [hJoyHeld], a
    ret
.L_01_4fba:
    ld hl, wPlayerX
    ld b, [hl]
    ld hl, wPlayerY
    ld c, [hl]
    call IsOnTileGrid
    ret z
    ld a, [wPlayerDir]
    and a, $0f
    swap a
    ld d, a
    ldh a, [hJoyHeld]
    and a, $0f
    or a, d
    ldh [hJoyHeld], a
    ret
CheckPlayerTileCollision::
    ld a, [wRoomType]
    cp a, $09
    jr nz, .L_01_4fe3
    ld a, [wSubState]
    bit 0, a
    ret nz
.L_01_4fe3:
    ld a, [wRoomType]
    cp a, $02
    jp z, L_01_50fa
L_01_4feb::
    ld a, [wPlayerX]
    call PixelXToColumn
    ld a, [wPlayerY]
    call LookupMapTile
    or a, a
    ret z
    ld hl, wPlayerX
    ld b, [hl]
    ld hl, wPlayerY
    ld c, [hl]
    call IsOnTileGrid
    ret nz
    ld a, b
L_01_5006::
    call PixelXToColumn
    ld a, c
    call LookupMapTile
    ldh [$ff96], a
    and a, $10
    ret nz
    ldh a, [$ff96]
    and a, $0f
    or a, $10
    ld [hl], a
    ld a, b
    ldh [hSpriteX], a
    ld a, c
    sub a, $08
    ldh [hSpriteY], a
    call PixelToTilemapAddr
    ldh a, [hTilemapAddrLo]
    ld l, a
    dec l
    ldh a, [hTilemapAddrHi]
    ld h, a
    ld de, D_01_4921
    ldh a, [$ff96]
    and a, $0f
    cp a, $01
    jr z, .L_01_5039
    ld de, D_01_491b
.L_01_5039:
    call QueueVramCopyRows
    call WaitVramCopyDone
    ld hl, wPaintRemaining
    dec [hl]
    ret nz
RoundCleared::  ; runs when every path cell is painted ($c520 reached 0): restores palettes; plays sound $8a; clear animation
    ld a, [wPlayerStatus]
    bit 2, a
    jr nz, .L_01_506f
    ld a, $e4
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, $8a
    call PlaySound
    ld hl, wPlayer
    call SetObjPtr
    call DrawObject
    ld hl, wPlayerStatus
    set 2, [hl]
    ld hl, wGameFlags
    set 0, [hl]
    ret
.L_01_506f:
    ld a, $97
    ldh [$ff96], a
.L_01_5073:
    call WaitVBlankFlag
    ldh a, [hSerialByte]
    bit 7, a
    jp nz, L_01_50b1
    bit 3, a
    jp nz, L_01_50b1
    ld hl, $ff96
    dec [hl]
    jr nz, .L_01_5073
    call FadeOut
    ldh a, [hLinkFlags]
    bit 2, a
    jr z, .L_01_509b
    ld hl, hSerialByte
    res 6, [hl]
    ld a, $07
    jp GameModeDispatch
.L_01_509b:
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, L_01_50b6
    ld c, $08
    call SerialSendByte
    ldh a, [hSerialByte]
    bit 1, a
    ret nz
    ldh a, [hSerialByte]
    set 6, a
    ldh [hSerialByte], a
L_01_50b1::
    ld a, $07
    jp GameModeDispatch
L_01_50b6::
    ld a, [wRound]
    cp a, $21
    jr z, .L_01_50f5
    ld hl, $c47b
    inc [hl]
    ld hl, wRound
    inc [hl]
    ld hl, wRoundBackup
    inc [hl]
    ld hl, $c1a8
    inc [hl]
    ld hl, wRoomIndex
    inc [hl]
    ld hl, wPlayerStatus
    res 5, [hl]
    call L_01_4937
    ld a, [wGameFlags]
    bit 6, a
    jp z, .L_01_50eb
    and a, $be
    ld [wGameFlags], a
    ld a, $02
    jp GameModeDispatch
.L_01_50eb:
    ld hl, wGameFlags
    res 0, [hl]
    ld a, $03
    jp GameModeDispatch
.L_01_50f5:
    ld a, $06
    jp GameModeDispatch
L_01_50fa::
    ld a, [wPlayerX]
    call PixelXToColumn
    ld a, [wPlayerY]
    and a, $f0
    add a, $08
    call LookupMapTile
    or a, a
    ret z
    jp L_01_4feb
PlayerSetDirection::  ; dpad to wPlayerDir and the animation index
    ldh a, [hJoyHeld]
    ld e, a
    ld a, [$c43b]
    swap a
    and a, e
    jp nz, L_01_5183
    ldh a, [hJoyHeld]
    and a, $f0
    jp z, L_01_5183
    swap a
    ld d, a
    ld a, [wPlayerDir]
    and a, $f0
    or a, d
    ld [wPlayerDir], a
    and a, $0f
    ld c, a
    ld hl, DirectionToAnimIndex
    call LookupByte
    ld [$c4ce], a
    srl a
    ld c, a
    ld b, $00
    ld hl, D_01_518d
    ld a, [wRoomType]
    cp a, $01
    jr nz, .L_01_5153
    ld a, [wSubState]
    bit 0, a
    jr z, .L_01_5153
    ld hl, D_01_519d
.L_01_5153:
    add hl, bc
    ld a, [hl+]
    ld [$c4cc], a
    ld a, [hl+]
    ld [wPlayerVelY], a
    ld a, [hl+]
    ld [$c4ca], a
    ld a, [hl]
    ld [wPlayerVelX], a
    ld a, $09
    ld [$c4cf], a
    ld hl, wPlayer
    call SetObjPtr
    call L_00_09e0
    ld hl, wPlayerStatus
    res 0, [hl]
    ret
DirectionToAnimIndex::  ; dpad direction nibble to animation index
    INCBIN "orig/painter_momopie.gb", $05178, 11
L_01_5183::
    ld hl, wPlayerStatus
    set 0, [hl]
    xor a, a
    ld [$c4cf], a
    ret
D_01_518d::
    INCBIN "orig/painter_momopie.gb", $0518d, 16
D_01_519d::
    INCBIN "orig/painter_momopie.gb", $0519d, 16
L_01_51ad::
    ld hl, wPlayer
    call Clear32Bytes
    ld a, $10
    ld [$c4ce], a
    ld a, $a2
    ld [wPlayer], a
    ld a, $80
    ld [wPlayerX], a
    ld a, $78
    ld [wPlayerY], a
    xor a, a
    ld [$c4d2], a
    ld [$c4c2], a
    ld [$c43b], a
    ld [$c1b6], a
    ld [wPlayerDir], a
    ld [wPlayerStatus], a
    ldh [$ffdf], a
    ld hl, PlayerAnimPtrs
    ld a, [hl+]
    ld [$c4bf], a
    ld a, [hl]
    ld [$c4c0], a
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_01_5207
    ld a, $01
    ld [$c43e], a
    ld a, $02
    ld [$c43f], a
    ld a, $03
    ld [$c440], a
    ld a, $05
    ld [$c441], a
    ld a, $06
    ld [$c442], a
    ret
.L_01_5207:
    ld a, $01
    ld [$c43e], a
    ld a, [wRound]
    cp a, $02
    ret c
    ld a, $09
    ld [$c43f], a
    ld a, [wRound]
    cp a, $03
    ret c
    ld a, $06
    ld [$c440], a
    ret
PlayerDeath::  ; waits $27 frames; plays sound $8b; runs the death animation (wPlayerDir bit 5)
    ld a, [wPlayerStatus]
    bit 2, a
    jr nz, .L_01_5239
    ld a, $27
    call DelayFrames
    ld a, $8b
    call PlaySound
    ld hl, wPlayerStatus
    set 2, [hl]
.L_01_5239:
    ld hl, $c4d2
    inc [hl]
    ld a, $3c
    ldh [$ff9c], a
    ld a, $02
    ldh [$ff9d], a
    ld a, [$c4d2]
    ldh [$ff9e], a
    ld a, $0f
    call L_00_0c2a
    ldh a, [$ff9e]
    ld [$c4d2], a
    ld a, $1e
    cp a, c
    jr z, .L_01_5285
    ld a, c
    cp a, $06
    jr z, .L_01_527e
    cp a, $10
    jr z, .L_01_527e
    ld hl, wPlayer
    res 5, [hl]
.L_01_5267:
    ld hl, D_01_488c
    ld b, $00
    add hl, bc
    ld a, [hl+]
    ld [$c4bf], a
    ld a, [hl]
    ld [$c4c0], a
    ld hl, wPlayer
    call SetObjPtr
    jp DrawObject
.L_01_527e:
    ld hl, wPlayer
    set 5, [hl]
    jr .L_01_5267
.L_01_5285:
    xor a, a
    ld [wRoomType], a
    ld [$c4d2], a
    ldh a, [hLinkFlags]
    bit 1, a
    jr z, .L_01_529c
    ld hl, hSerialByte
    set 6, [hl]
    ld a, $07
    jp GameModeDispatch
.L_01_529c:
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_01_52b7
    ld c, $04
    call SerialSendByte
    ld hl, hSerialByte
    set 7, [hl]
    ldh a, [hSerialByte]
    bit 1, a
    jr nz, .L_01_52b7
    ld a, $07
    jp GameModeDispatch
.L_01_52b7:
    ld hl, wLives
    dec [hl]
    jr nz, .L_01_52bf
    jr .L_01_52c9
.L_01_52bf:
    ld a, $50
    call DelayFrames
    ld a, $03
    jp GameModeDispatch
.L_01_52c9:
    xor a, a
    ld [wPlayerDir], a
    ld [wPlayerStatus], a
    ld [$c47b], a
    ld [$c1a8], a
    ld a, [$c51f]
    set 0, a
    and a, $f9
    ld [$c51f], a
    ld a, $03
    ld [wLives], a
    ld a, $50
    call DelayFrames
    ld a, [$c49b]
    and a, a
    jr nz, .L_01_52fc
    ld a, [$c49c]
    bit 0, a
    jr nz, .L_01_52fc
    ld a, $04
    jp GameModeDispatch
.L_01_52fc:
    ld a, $05
    jp GameModeDispatch
L_01_5301::
    call L_01_5311
    ld a, [$c1ac]
    ld [wScrollX], a
    ld a, [$c1ae]
    ld [wScrollY], a
    ret
L_01_5311::
    ld a, [wPlayerX]
    sub a, $58
    ld [$c1ac], a
    ld a, [$c1ad]
    sbc a, $00
    ld [$c1ad], a
    bit 7, a
    jr nz, .L_01_5337
    ld a, [$c1ac]
    cp a, $60
    jr c, .L_01_533e
    ld a, $60
    ld [$c1ac], a
    xor a, a
    ld [$c1ad], a
    jr .L_01_533e
.L_01_5337:
    xor a, a
    ld [$c1ad], a
    ld [$c1ac], a
.L_01_533e:
    ld a, [wPlayerY]
    sub a, $68
    ld [$c1ae], a
    ld a, [$c1af]
    sbc a, $00
    ld [$c1af], a
    bit 7, a
    jr nz, .L_01_5362
    ld a, [$c1ae]
    cp a, $70
    ret c
    ld a, $70
    ld [$c1ae], a
    xor a, a
    ld [$c1af], a
    ret
.L_01_5362:
    xor a, a
    ld [$c1ae], a
    ld [$c1af], a
    ret
L_01_536a::
    ld a, $20
    ld [$c1ac], a
    ld [$c1ae], a
    xor a, a
    ld [$c1ad], a
    ld [$c1af], a
    ret
L_01_537a::
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_5385
    jp L_01_53c4
.L_01_5385:
    call L_00_3599
    call L_00_39b1
    call L_00_341f
    call L_01_5394
    jp DrawObject
L_01_5394::
    ldh a, [$ffd1]
    bit 0, a
    jr nz, .L_01_53a8
    bit 1, a
    jr nz, .L_01_53b3
    bit 2, a
    jr nz, .L_01_53be
    ld de, D_01_53e5
    jp L_00_3651
.L_01_53a8:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_01_53ec
    jp L_00_3651
.L_01_53b3:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_53ec
    jp L_00_3651
.L_01_53be:
    ld de, D_01_53f3
    jp L_00_3651
L_01_53c4::
    ld a, $08
    ldh [$ffc6], a
    ld a, $01
    ldh [$ffcf], a
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_01_53d6
    ld a, $50
    jr .L_01_53d8
.L_01_53d6:
    ld a, $80
.L_01_53d8:
    ldh [$ffc9], a
    ld de, D_01_53e5
    call SetObjectAnimation
    ld a, $91
    ldh [$ffd1], a
    ret
D_01_53e5::
    INCBIN "orig/painter_momopie.gb", $053e5, 7
D_01_53ec::
    INCBIN "orig/painter_momopie.gb", $053ec, 7
D_01_53f3::
    INCBIN "orig/painter_momopie.gb", $053f3, 11277

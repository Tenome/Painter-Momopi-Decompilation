INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank01", ROMX[$4000], BANK[1]

    INCBIN "orig/painter_momopie.gb", $04000, 72
SoundSongTable::  ; word offsets of song data (follows the frequency table at $4000)
    INCBIN "orig/painter_momopie.gb", $04048, 172
SoundCommandDataTable::  ; per command word pointers used by SoundStartCommand
    dw D_00_0027
    dw Sound81MusicData
    dw Sound82EffectData
    dw Sound83EffectData
    dw Sound84MusicData
    dw Sound85MusicData
    dw Sound86MusicData
    dw Sound87MusicData
    dw Sound88MusicData
    dw Sound89MusicData
    dw Sound8AMusicData
    dw Sound8BMusicData
    dw D_01_7f55
    dw Sound8DEffectData
    dw Sound8EEffectData
    dw Sound8FEffectData
    dw Sound90EffectData
    dw Sound91EffectData
    dw Sound92EffectData
SoundCommandHandlerTable::  ; per sound id: routine that starts the stream (music \$4263; effect \$4292)
    dw Sound93EffectData
    dw SoundStartMusic
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartMusic
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartEffect
    dw SoundStartEffect
    INCBIN "orig/painter_momopie.gb", $04142, 21
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
    ld hl, $411a
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
SoundClearChannels::  ; clears the first byte of all 8 channel records and sets NR50 default ($77)
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
SoundInit::  ; initialises the APU registers: NR30 NR51 NR10 NR12 NR22 NR42 NR13 NR23 NR33
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
SoundClearRegisterShadow::  ; zeroes the register shadow bytes at $c427-$c431
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
SoundStartMusic::  ; starts a music stream (priority at $4141 + id; replaces lower priority music)
    ld hl, $4141
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
    call SoundClearChannels
    ld a, $00
    ld [wSoundChannels], a
    ld [$c347], a
    ld [$c367], a
    ld [$c387], a
    ld hl, wSoundChannels
    jp SoundLoadStream
L_01_428c::
    ld a, $80
    ld [wSoundCmd], a
    ret
SoundStartEffect::  ; starts an effect stream (priority compare with $c310)
    ld hl, $4141
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
    call SoundClearRegisterShadow
    ld a, $00
    ld [$c3a7], a
    ld [$c3c7], a
    ld [$c3e7], a
    ld [$c407], a
    ld hl, $c3a7
    jp SoundLoadStream
SoundPauseMusicChannels::  ; sets the pause flag (bit 4) on the music channel records while an effect plays
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
    jr SoundStartEffect
SoundResumeMusicChannels::  ; clears the pause flag on the music channel records
    call SoundClearRegisterShadow
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
    jr SoundStartEffect
SoundLoadStream::  ; copies the stream header into a channel record
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
    jr z, SoundSilenceChannel1
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
SoundSilenceChannel1::  ; writes NR13=$ff NR14=$87 to retrigger channel 1 at the end of a note
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
    jr z, SoundSilenceChannel2
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
SoundSilenceChannel2::  ; writes NR23=$ff NR24=$87 to retrigger channel 2
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
    jr z, SoundSilenceChannel3
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
SoundSilenceChannel3::  ; writes NR33=$ff NR34=$07 to channel 3
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
    jr z, SoundSilenceChannel4
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
SoundSilenceChannel4::  ; writes NR43=$ff NR44=$80 to channel 4
    ld a, $ff
    ld [rNR43], a
    ld [$c431], a
    ld a, $80
    ld [rNR44], a
    ret
SoundRunCommand::  ; command byte $e0-$ff: index = byte and $1f into the word table at $467b; calls it through SoundJumpHL
    and a, $1f
    cp a, $03
    jr z, SoundCmdStop
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
    call SoundJumpHL
    jp SoundParseStream
SoundCmdStop::  ; command $e3: ends the stream; the channel is silenced
    ld a, $00
    ld [$c30f], a
L_01_45f4::
    ld [bc], a
    ld hl, $0001
    add hl, bc
    ld a, [hl]
    cp a, $03
    call z, SoundSilenceChannel4
    ld a, [hl]
    cp a, $02
    call z, SoundSilenceChannel3
    ld a, [hl]
    cp a, $01
    call z, SoundSilenceChannel2
    ld a, [hl]
    cp a, $00
    call z, SoundSilenceChannel1
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
SoundParseStream::  ; reads bytes of the channel's song stream; notes below $e0; commands go to SoundRunCommand
    ld a, [de]
    inc de
    cp a, $e0
    jr nc, SoundRunCommand
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
SoundJumpHL::  ; jp hl trampoline for the sound command table
    jp hl
SoundCommandTable::  ; 18 word handlers for stream commands $e0-$f1 (index = byte and $1f)
    dw SoundCmdCall
    dw SoundCmdCall
    dw SoundCmdReturn
    dw SoundCmdStop
    dw SoundCmdRepeat
    dw SoundCmdJump
    dw SoundCmdSetEnvelope
    dw SoundCmdAddTranspose
    dw SoundCmdSetDuty
    dw SoundCmdSetPan
    dw SoundCmdSetWave
    dw SoundCmdEnd
    dw SoundCmdMuteOn
    dw SoundCmdMuteOff
    dw SoundCmdClearFlag0
    dw SoundCmdSetMasterVolume
    dw SoundCmdSetField6
    dw SoundCmdSetPitch
SoundCmdCall::  ; commands $e0 and $e1: pushes the return address on the record's small stack ($a) and jumps to the address that follows
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
SoundCmdReturn::  ; command $e2: pops the return address from the record's small stack
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
SoundCmdRepeat::  ; command $e4: counted loop; operands: counter slot and jump target
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
SoundCmdJump::  ; command $e5: sets the stream pointer from the next two bytes
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
SoundCmdSetEnvelope::  ; command $e6: record +7 = next byte (volume envelope NRx2)
    ld hl, $0007
SoundSetField::  ; shared tail: record[HL] = next stream byte
    add hl, bc
    ld a, [de]
    inc de
    ld [hl], a
    ret
SoundCmdAddTranspose::  ; command $e7: record +5 += next byte (note transpose)
    ld hl, $0005
    add hl, bc
    ld a, [de]
    inc de
    add a, [hl]
    ld [hl], a
    ret
SoundCmdSetDuty::  ; command $e8: record +$15 = next byte (duty or length NRx1)
    ld hl, $0015
    jr SoundSetField
SoundCmdSetPan::  ; command $e9: record +2 = next byte (NR51 pan mask)
    ld hl, $0002
    jr SoundSetField
SoundCmdSetField6::  ; command $f0: record +6 = next byte
    ld hl, $0006
    jr SoundSetField
SoundCmdSetPitch::  ; command $f1: record +$e = next byte (pitch)
    ld hl, $000e
    jr SoundSetField
L_01_4722::
    ld a, [de]
    inc de
    ld [$c312], a
    ret
SoundCmdSetWave::  ; command $ea: selects a wave pattern (SoundLoadWave) on the wave channel
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
    jr SoundLoadWave
.L_01_4747:
    ld a, [$c314]
    ld [$c313], a
SoundLoadWave::  ; copies a 16 byte wave pattern from the table at $3fb8 into wave RAM
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
    call SoundInit
L_01_4775::
    ret
SoundCmdEnd::  ; sound command $eb: discards the caller's return address and ends the stream
    ld a, $00
    ld [$c310], a
    ld a, [$c312]
    ld hl, $c314
    cp a, [hl]
    jr z, .L_01_4788
    ld [hl], a
    call SoundLoadWave
.L_01_4788:
    ld a, $00
    pop hl
    jp L_01_45f4
SoundCmdMuteOn::  ; command $ec: sets bit 5 of the record flags
    ld a, [bc]
    or a, $20
    ld [bc], a
    ret
SoundCmdMuteOff::  ; command $ed: clears bit 5 of the record flags
    ld a, [bc]
    and a, $df
    ld [bc], a
    ret
SoundCmdClearFlag0::  ; command $ee: clears bit 0 (note started) of the record flags
    ld a, [bc]
    and a, $fe
    ld [bc], a
    ret
SoundCmdSetMasterVolume::  ; command $ef: NR50 = next byte (also saved at $c315)
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
    call nz, SoundSetFrequency
    ret
SoundSetFrequency::  ; frequency for the current note from the pitch tables at $3f4c (SoundPitchTables)
    ld hl, $0006
    add hl, bc
    ld a, [hl]
    sla a
    ld e, a
    ld d, $00
    ld hl, SoundPitchTables
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
    jr SoundSetFrequency
.L_01_4809:
    ld a, $00
    ld hl, $000d
    add hl, bc
    ld [hl], a
    jr SoundSetFrequency
.L_01_4812:
    ld hl, $000d
    add hl, bc
    dec [hl]
    dec [hl]
    jr SoundSetFrequency
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
L_01_4927::
    rlca
    ld c, h
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
    ld a, SND_SFX_82
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
    ld hl, wPaintObject
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
    ld [wPaintObject], a
    call L_01_4a9d
    jp L_01_4957
L_01_49a0::
    ld a, $0f
    ldh [hScratch00], a
.L_01_49a4:
    ldh a, [hScratch00]
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
    ld hl, hScratch00
    dec [hl]
    ld a, [hl]
    bit 7, a
    ret nz
    jr .L_01_49a4
L_01_49d6::
    ld hl, wPaintObject
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
    ld [wPaintObject], a
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
    ld a, SND_SFX_8D
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
    ld hl, $4927
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
    ldh [hEnemyBlocked], a
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
    ldh [hEnemyBlocked], a
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
    ldh [hEnemyBlocked], a
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
    ldh [hEnemyBlocked], a
    ret
PlayFrame::  ; one frame of play mode: input; movement; collisions; drawing the player
    ld a, [wGameFlags]
    bit 0, a
    jp nz, RoundCleared
    ldh a, [hSerialByte]
    bit 2, a
    jr z, .L_01_4bf6
    bit 7, a
    jp nz, GotoLinkLose
    bit 3, a
    jp nz, GotoLinkLose
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
    ld a, [wMagicPoints]
    sub a, c
    ld e, a
    jr z, LinkSyncFrame
L_01_4ca7::
    jr c, .L_01_4cae
    ld [wMagicPoints], a
    jr L_01_4cbc
.L_01_4cae:
    ld a, [$c44b]
    and a, a
    jr z, L_01_4ceb
    ld a, e
    ld [wMagicPoints], a
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
    dw L_01_4d55
    dw L_01_4d55
    dw L_01_4d66
    dw L_01_4d7b
    dw L_01_4d91
    dw L_01_4da2
    dw L_01_4d44
    dw L_01_4e06
    dw L_01_4e77
    dw L_01_4db8
L_01_4ceb::
    xor a, a
    ld [wRoomType], a
    ld [wSubState], a
    ret
LinkSyncFrame::  ; per-frame link cable exchange for the 2 player game (rSC rSB)
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
    ld [wMagicPoints], a
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
    ld hl, wPaintObject
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
    ld hl, wPaintObject
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
    ld hl, wPaintObject
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
    ld a, [wPaintObject]
    bit 2, a
    ret nz
L_01_4e59::
    ld hl, wPaintObject
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
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld a, [$c519]
    and a, $02
    ret nz
    xor a, a
    ld [rBGP], a
    ret
.L_01_4ea5:
    ld a, PAL_NORMAL
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
    ldh [hScratch02], a
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
    ldh [hScratch00], a
    ld a, $98
    ldh [hScratch01], a
.L_01_4ee4:
    ld a, c
    sub a, $10
    jr c, .L_01_4ef8
    ld c, a
    ldh a, [hScratch00]
    add a, $40
    ldh [hScratch00], a
    ldh a, [hScratch01]
    adc a, $00
    ldh [hScratch01], a
    jr .L_01_4ee4
.L_01_4ef8:
    sla c
    ld e, c
    ldh a, [hScratch00]
    add a, e
    ldh [hScratch00], a
    ldh a, [hScratch01]
    adc a, $00
    ldh [hScratch01], a
    ret
L_01_4f07::
    ld de, D_01_4921
    ldh a, [hScratch02]
    and a, $0f
    cp a, $01
    jr z, .L_01_4f15
    ld de, D_01_491b
.L_01_4f15:
    ldh a, [hScratch00]
    ld l, a
    ldh a, [hScratch01]
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
    ldh [hScratch06], a
    ld a, $02
    ldh [hScratch07], a
    ld a, [$c4d9]
    ldh [hScratch08], a
    ld a, $04
    call L_00_0c2a
    ldh a, [hScratch08]
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
PaintCell::  ; sets the painted bit ($10) of the wRoomMap cell under the player and queues the tile update
    call PixelXToColumn
    ld a, c
    call LookupMapTile
    ldh [hScratch00], a
    and a, $10
    ret nz
    ldh a, [hScratch00]
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
    ldh a, [hScratch00]
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
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld [rOBP0], a
    ld [rOBP1], a
    ld a, SND_MUSIC_ROUND_CLEAR
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
    ldh [hScratch00], a
.L_01_5073:
    call WaitVBlankFlag
    ldh a, [hSerialByte]
    bit 7, a
    jp nz, GotoLinkLose
    bit 3, a
    jp nz, GotoLinkLose
    ld hl, hScratch00
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
    jr z, NextRound
    ld c, $08
    call SerialSendByte
    ldh a, [hSerialByte]
    bit 1, a
    ret nz
    ldh a, [hSerialByte]
    set 6, a
    ldh [hSerialByte], a
GotoLinkLose::  ; jumps to game mode 7
    ld a, $07
    jp GameModeDispatch
NextRound::  ; wRound and room index advance by one (round $21 ends the game); clears the player status
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
InitPlayer::  ; clears wPlayer and sets flags $a2; X=$80; Y=$78; direction and animation start values
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
    ld a, SND_MUSIC_DEATH
    call PlaySound
    ld hl, wPlayerStatus
    set 2, [hl]
.L_01_5239:
    ld hl, $c4d2
    inc [hl]
    ld a, $3c
    ldh [hScratch06], a
    ld a, $02
    ldh [hScratch07], a
    ld a, [$c4d2]
    ldh [hScratch08], a
    ld a, $0f
    call L_00_0c2a
    ldh a, [hScratch08]
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
UpdateCamera::  ; follows the player: copies the camera to wScrollX/wScrollY
    call CameraFollowPlayerX
    ld a, [wCameraX]
    ld [wScrollX], a
    ld a, [wCameraY]
    ld [wScrollY], a
    ret
CameraFollowPlayerX::  ; wCameraX = wPlayerX - $58 clamped to 0..$60
    ld a, [wPlayerX]
    sub a, $58
    ld [wCameraX], a
    ld a, [$c1ad]
    sbc a, $00
    ld [$c1ad], a
    bit 7, a
    jr nz, .L_01_5337
    ld a, [wCameraX]
    cp a, $60
    jr c, .L_01_533e
    ld a, $60
    ld [wCameraX], a
    xor a, a
    ld [$c1ad], a
    jr .L_01_533e
.L_01_5337:
    xor a, a
    ld [$c1ad], a
    ld [wCameraX], a
.L_01_533e:
    ld a, [wPlayerY]
    sub a, $68
    ld [wCameraY], a
    ld a, [$c1af]
    sbc a, $00
    ld [$c1af], a
    bit 7, a
    jr nz, .L_01_5362
    ld a, [wCameraY]
    cp a, $70
    ret c
    ld a, $70
    ld [wCameraY], a
    xor a, a
    ld [$c1af], a
    ret
.L_01_5362:
    xor a, a
    ld [wCameraY], a
    ld [$c1af], a
    ret
ResetCamera::  ; wCameraX and wCameraY = $20; high bytes 0
    ld a, $20
    ld [wCameraX], a
    ld [wCameraY], a
    xor a, a
    ld [$c1ad], a
    ld [$c1af], a
    ret
EnemyKind4::  ; enemy kind 4
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_5385
    jp L_01_53c4
.L_01_5385:
    call L_00_3599
    call L_00_39b1
    call CheckEnemyTouchesPlayer
    call L_01_5394
    jp DrawObject
L_01_5394::
    ldh a, [hEnemyDir]
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
    ldh [hEnemyAnimState], a
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
    ldh [hEnemyCounter], a
    ld de, D_01_53e5
    call SetObjectAnimation
    ld a, $91
    ldh [hEnemyDir], a
    ret
D_01_53e5::
    INCBIN "orig/painter_momopie.gb", $053e5, 7
D_01_53ec::
    INCBIN "orig/painter_momopie.gb", $053ec, 7
D_01_53f3::
    INCBIN "orig/painter_momopie.gb", $053f3, 288
EnemyKind10::  ; enemy kind 10 (rounds 14 and 30)
    call TickObjectTimer
    jr nz, .L_01_551b
    jp L_01_56a2
.L_01_551b:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call L_00_39b1
    call L_01_5636
    call L_01_556a
    call L_01_55bc
    call L_01_553a
    call L_01_5549
    call SelectObject2
    jp DrawObject
L_01_553a::
    ldh a, [hEnemyFlags]
    and a, $0a
    cp a, $0a
    ret nz
    ld hl, $c49e
    res 7, [hl]
    jp L_00_3525
L_01_5549::
    ldh a, [$ffd0]
    and a, $04
    jr z, .L_01_5559
    ld a, [$c499]
    ld l, a
    ld a, [$c49a]
    ld h, a
    jr .L_01_5563
.L_01_5559:
    ld a, [$c499]
    ld l, a
    ld a, [$c49a]
    ld h, a
    inc hl
    inc hl
.L_01_5563:
    ld a, [hl+]
    ldh [$ffb6], a
    ld a, [hl]
    ldh [$ffb7], a
    ret
L_01_556a::
    ldh a, [hEnemyFlags]
    bit 0, a
    ret nz
    ldh a, [hEnemyFlags]
    bit 3, a
    jr z, .L_01_557b
    ld hl, $c49e
    res 7, [hl]
    ret
.L_01_557b:
    ldh a, [hEnemyX]
    ld c, a
    ldh a, [hEnemyY]
    ld b, a
    call L_00_3449
    ret nz
    ld hl, $ffca
    dec [hl]
    ret nz
    call L_01_570c
    ldh a, [hEnemyX]
    ld [$c4a5], a
    ldh a, [hEnemyY]
    ld [$c4a8], a
    ld a, $86
    ld [$c49e], a
    ldh a, [hEnemyKind]
    cp a, $0a
    jr nz, .L_01_55a7
    ld de, D_01_57ec
    jr .L_01_55aa
.L_01_55a7:
    ld de, D_01_57c9
.L_01_55aa:
    ld a, e
    ld [$c49f], a
    ld a, d
    ld [$c4a0], a
    ld a, $50
    ldh [$ffca], a
    ld hl, hEnemyFlags
    set 0, [hl]
    ret
L_01_55bc::
    ldh a, [hEnemyFlags]
    bit 0, a
    ret z
    ld a, [$c4a5]
    ldh [hScratch00], a
    ld a, [$c4a6]
    ldh [hScratch01], a
    ld a, [$c4a8]
    ldh [hScratch02], a
    ld a, [$c4a9]
    ldh [hScratch03], a
    call L_01_5677
    and a, a
    jr z, .L_01_560d
    ld hl, hEnemyDir
    set 5, [hl]
    ld a, $0b
    ld [$c4af], a
    ld a, [wRoomType]
    cp a, $03
    jr nz, .L_01_55fb
    ld a, [wSubState]
    bit 0, a
    jp z, .L_01_55fb
    xor a, a
    ldh [hEnemyAnimState], a
    xor a, a
    ld [$c4af], a
.L_01_55fb:
    call L_01_5618
    ld hl, $c49e
    call SetObjPtr
    call L_00_0b66
    call L_00_09e0
    jp DrawObject
.L_01_560d:
    ld hl, $c49e
    res 7, [hl]
    ld hl, hEnemyFlags
    set 1, [hl]
    ret
L_01_5618::
    ldh a, [hEnemyKind]
    cp a, $0a
    ret nz
    ld hl, $ffd3
    inc [hl]
    ld hl, D_01_57ec
    ldh a, [$ffd3]
    and a, $04
    jr z, .L_01_562d
    ld hl, D_01_57ee
.L_01_562d:
    ld a, l
    ld [$c49f], a
    ld a, h
    ld [$c4a0], a
    ret
L_01_5636::
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld c, a
    ld b, $00
    ld hl, D_01_5782
    add hl, bc
    ld a, [hl]
    ldh [$ffc5], a
    call SelectObject2
    call L_00_0b66
    call L_00_09e0
    ldh a, [hEnemyX]
    ldh [hScratch00], a
    ldh a, [hEnemyXHi]
    ldh [hScratch01], a
    ldh a, [hEnemyY]
    ldh [hScratch02], a
    ldh a, [hEnemyYHi]
    ldh [hScratch03], a
    call L_01_5677
    and a, a
    ret nz
    ld hl, hEnemyFlags
    set 3, [hl]
    ret
L_01_566a::
    ldh a, [hEnemyDir]
    bit 5, a
    jr nz, .L_01_5671
    ret
.L_01_5671:
    ld hl, hEnemyFlags
    set 3, [hl]
    ret
L_01_5677::
    ldh a, [hScratch01]
    cp a, $ff
    jr z, .L_01_56a0
    cp a, $01
    jr z, .L_01_568e
    ldh a, [hScratch03]
    cp a, $ff
    jr z, .L_01_56a0
    cp a, $01
    jr z, .L_01_5697
    ld a, $01
    ret
.L_01_568e:
    ldh a, [hScratch00]
    cp a, $08
    jr nc, .L_01_56a0
    ld a, $01
    ret
.L_01_5697:
    ldh a, [hScratch02]
    cp a, $20
    jr nc, .L_01_56a0
    ld a, $01
    ret
.L_01_56a0:
    xor a, a
    ret
L_01_56a2::
    ld hl, $c49e
    call Clear32Bytes
    ld a, $01
    ld [$c4a2], a
    xor a, a
    ld [hEnemyFlags], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $30
    ldh [$ffca], a
    ldh a, [hEnemyKind]
    cp a, $0a
    jr nz, .L_01_56ca
    ld bc, $5793
    ld de, D_01_579b
    ld hl, D_01_5797
    jr .L_01_56d3
.L_01_56ca:
    ld bc, $5787
    ld de, D_01_578f
    ld hl, D_01_578b
.L_01_56d3:
    call L_00_340c
    push af
    push de
    swap a
    and a, $10
    sla a
    ld e, a
    ldh a, [hObject2]
    or a, e
    or a, $86
    ldh [hObject2], a
    pop de
    pop af
    and a, $03
    jr nz, .L_01_5701
    ldh a, [hEnemyDir]
    bit 3, a
    jr z, .L_01_56f6
    push bc
    pop hl
    jr .L_01_5701
.L_01_56f6:
    bit 4, a
    jr z, .L_01_56fe
    push de
    pop hl
    jr .L_01_5701
.L_01_56fe:
    ld hl, D_01_578b
.L_01_5701:
    ld a, l
    ld [$c499], a
    ld a, h
    ld [$c49a], a
    jp L_01_5549
L_01_570c::
    ld a, [wPlayerY]
    ld e, a
    ld a, [hEnemyY]
    sub a, $10
    cp a, e
    jr nc, .L_01_5738
    ld a, [wPlayerY]
    ld e, a
    ld a, [hEnemyY]
    add a, $10
    cp a, e
    jr c, .L_01_575c
    ld a, [wPlayerX]
    ld e, a
    ld a, [hEnemyX]
    cp a, e
    jr c, .L_01_5733
    ld a, $10
    jp .L_01_577e
.L_01_5733:
    ld a, $08
    jp .L_01_577e
.L_01_5738:
    ld a, [wPlayerX]
    ld e, a
    ldh a, [hEnemyX]
    sub a, $10
    cp a, e
    jr nc, .L_01_5752
    ld a, [wPlayerX]
    ld e, a
    ldh a, [hEnemyX]
    add a, $10
    cp a, e
    jr c, .L_01_5757
    xor a, a
    jp .L_01_577e
.L_01_5752:
    ld a, $1c
    jp .L_01_577e
.L_01_5757:
    ld a, $04
    jp .L_01_577e
.L_01_575c:
    ld a, [wPlayerX]
    ld e, a
    ldh a, [hEnemyX]
    sub a, $10
    cp a, e
    jr nc, .L_01_5777
    ld a, [wPlayerX]
    ld e, a
    ldh a, [hEnemyX]
    add a, $10
    cp a, e
    jr c, .L_01_577c
    ld a, $10
    jp .L_01_577e
.L_01_5777:
    ld a, $14
    jp .L_01_577e
.L_01_577c:
    ld a, $0c
.L_01_577e:
    ld [$c4ae], a
    ret
D_01_5782::
    INCBIN "orig/painter_momopie.gb", $05782, 9
D_01_578b::
    INCBIN "orig/painter_momopie.gb", $0578b, 4
D_01_578f::
    INCBIN "orig/painter_momopie.gb", $0578f, 8
D_01_5797::
    INCBIN "orig/painter_momopie.gb", $05797, 4
D_01_579b::
    INCBIN "orig/painter_momopie.gb", $0579b, 46
D_01_57c9::
    INCBIN "orig/painter_momopie.gb", $057c9, 35
D_01_57ec::
    INCBIN "orig/painter_momopie.gb", $057ec, 2
D_01_57ee::
    INCBIN "orig/painter_momopie.gb", $057ee, 2
EnemyKind9::  ; enemy kind 9
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_57fb
    jp L_01_585e
.L_01_57fb:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call L_00_3599
    call L_00_39b1
    call L_00_392e
    call CheckEnemyTouchesPlayer
    call L_01_5821
    jp DrawObject
L_01_5817::
    ld a, $06
    ldh [hEnemyAnimState], a
    call L_00_3603
    jp L_00_3643
L_01_5821::
    ld hl, hObject2
    res 5, [hl]
    ldh a, [hEnemyDir]
    bit 2, a
    jr nz, .L_01_583e
    bit 3, a
    jr nz, .L_01_5847
    bit 0, a
    call nz, L_01_5858
    ld de, D_01_587d
    ld bc, $5884
    jp .L_01_584d
.L_01_583e:
    ld de, D_01_588b
    ld bc, $5892
    jp .L_01_584d
.L_01_5847:
    ld de, D_01_586f
    ld bc, $5876
.L_01_584d:
    ldh a, [$ffd0]
    and a, $08
    jr z, .L_01_5855
    push bc
    pop de
.L_01_5855:
    jp SetObjectAnimation
L_01_5858::
    ld hl, hObject2
    set 5, [hl]
    ret
L_01_585e::
    ld a, $06
    ldh [hEnemyAnimState], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld de, D_01_586f
    call SetObjectAnimation
    jp L_00_340c
D_01_586f::
    INCBIN "orig/painter_momopie.gb", $0586f, 14
D_01_587d::
    INCBIN "orig/painter_momopie.gb", $0587d, 14
D_01_588b::
    INCBIN "orig/painter_momopie.gb", $0588b, 14
EnemyKind2::  ; enemy kind 2
    call TickObjectTimer
    jr nz, .L_01_58a1
    jp L_01_59b6
.L_01_58a1:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call L_00_39f9
    call EnemyChooseDirection
    call L_00_39b1
    call L_01_58cf
    call L_01_58ee
    call L_00_32a2
    call L_00_392e
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call L_01_596f
    call SelectObject2
    jp DrawObject
L_01_58cf::
    ld a, [$c49e]
    bit 7, a
    ret nz
    ld hl, $ffca
    dec [hl]
    ret nz
    ld a, [$c49e]
    bit 7, a
    ret nz
    ldh a, [hEnemyX]
    ld c, a
    ldh a, [hEnemyY]
    ld b, a
    call L_00_3449
    and a, a
    ret nz
    jp L_01_5947
L_01_58ee::
    ld a, [wRoomType]
    cp a, $03
    jr nz, .L_01_58fc
    ld a, [wSubState]
    bit 0, a
    jr nz, .L_01_5938
.L_01_58fc:
    ld a, [wRoomType]
    cp a, $05
    jr nz, .L_01_590a
    ld a, [wSubState]
    bit 0, a
    jr nz, .L_01_5938
.L_01_590a:
    ld a, [$c49e]
    bit 7, a
    ret z
    ld hl, $c4b4
    dec [hl]
    jr z, .L_01_5938
    ld hl, $c4b9
    inc [hl]
    ld hl, D_01_59fa
    ld a, [$c4b9]
    and a, $10
    jr z, .L_01_5927
    ld hl, D_01_59f5
.L_01_5927:
    ld a, l
    ld [$c49f], a
    ld a, h
    ld [$c4a0], a
    ld hl, $c49e
    call SetObjPtr
    jp DrawObject
.L_01_5938:
    ld a, $05
    ldh [$ffca], a
    ld a, $a0
    ld [$c4b4], a
    ld hl, $c49e
    res 7, [hl]
    ret
L_01_5947::
    ld hl, $c49e
    call Clear32Bytes
    ld a, $04
    ld [$c4a2], a
    ld a, $a0
    ld [$c4b4], a
    ldh a, [hEnemyX]
    add a, $08
    and a, $f0
    ld [$c4a5], a
    ldh a, [hEnemyY]
    and a, $f0
    add a, $08
    ld [$c4a8], a
    ld a, $82
    ld [$c49e], a
    ret
L_01_596f::
    ld a, [hEnemyDir]
    bit 0, a
    jr nz, .L_01_5983
    bit 1, a
    jr nz, .L_01_5990
    bit 2, a
    jr nz, .L_01_599d
    bit 3, a
    jr nz, .L_01_59a5
    ret
.L_01_5983:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_01_59d9
    ld bc, $59e0
    jr .L_01_59ab
.L_01_5990:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_59d9
    ld bc, $59e0
    jr .L_01_59ab
.L_01_599d:
    ld bc, $59e7
    ld de, D_01_59ee
    jr .L_01_59ab
.L_01_59a5:
    ld bc, $59cb
    ld de, D_01_59d2
.L_01_59ab:
    ldh a, [$ffd0]
    and a, $04
    jr z, .L_01_59b3
    push bc
    pop de
.L_01_59b3:
    jp L_00_3651
L_01_59b6::
    ld a, $05
    ldh [hEnemyAnimState], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $05
    ldh [$ffca], a
    ld de, D_01_59cb
    call SetObjectAnimation
    jp L_00_340c
D_01_59cb::
    INCBIN "orig/painter_momopie.gb", $059cb, 7
D_01_59d2::
    INCBIN "orig/painter_momopie.gb", $059d2, 7
D_01_59d9::
    INCBIN "orig/painter_momopie.gb", $059d9, 21
D_01_59ee::
    INCBIN "orig/painter_momopie.gb", $059ee, 7
D_01_59f5::
    INCBIN "orig/painter_momopie.gb", $059f5, 5
D_01_59fa::
    INCBIN "orig/painter_momopie.gb", $059fa, 5
EnemyKind3::  ; enemy kind 3
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_5a0a
    jp L_01_5a65
.L_01_5a0a:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call L_00_3599
    call L_00_3b99
    call L_00_3603
    call L_00_3643
    call L_00_392e
    call CheckEnemyTouchesPlayer
    call L_01_5a29
    jp DrawObject
L_01_5a29::
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_01_5a40
    bit 1, a
    jr nz, .L_01_5a4e
    bit 2, a
    jr nz, .L_01_5a5c
    ld de, D_01_5a76
    ld bc, $5a7d
    jp SetAnimationVariant
.L_01_5a40:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_01_5a84
    ld bc, $5a8b
    jp SetAnimationVariant
.L_01_5a4e:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_5a84
    ld bc, $5a8b
    jp SetAnimationVariant
.L_01_5a5c:
    ld de, D_01_5a92
    ld bc, $5a99
    jp SetAnimationVariant
L_01_5a65::
    ld de, D_01_5a76
    call SetObjectAnimation
    ld a, $05
    ldh [hEnemyAnimState], a
    ld a, $20
    ldh [hEnemyCounter], a
    jp L_00_340c
D_01_5a76::
    INCBIN "orig/painter_momopie.gb", $05a76, 14
D_01_5a84::
    INCBIN "orig/painter_momopie.gb", $05a84, 14
D_01_5a92::
    INCBIN "orig/painter_momopie.gb", $05a92, 438
Sound8DEffectData::  ; stream of sound id $8d
    INCBIN "orig/painter_momopie.gb", $05c48, 20
Sound8EEffectData::  ; stream of sound id $8e
    INCBIN "orig/painter_momopie.gb", $05c5c, 20
Sound8FEffectData::  ; stream of sound id $8f
    INCBIN "orig/painter_momopie.gb", $05c70, 16
Sound90EffectData::  ; stream of sound id $90
    INCBIN "orig/painter_momopie.gb", $05c80, 19
Sound91EffectData::  ; stream of sound id $91
    INCBIN "orig/painter_momopie.gb", $05c93, 20
Sound92EffectData::  ; stream of sound id $92
    INCBIN "orig/painter_momopie.gb", $05ca7, 19
Sound93EffectData::  ; stream of sound id $93
    ld bc, $0380
    INCBIN "orig/painter_momopie.gb", $05cbd, 437
Sound81MusicData::  ; stream of sound id $81
    INCBIN "orig/painter_momopie.gb", $05e72, 553
Sound82EffectData::  ; stream of sound id $82
    INCBIN "orig/painter_momopie.gb", $0609b, 505
Sound83EffectData::  ; stream of sound id $83
    INCBIN "orig/painter_momopie.gb", $06294, 510
Sound84MusicData::  ; stream of sound id $84
    INCBIN "orig/painter_momopie.gb", $06492, 715
Sound85MusicData::  ; stream of sound id $85
    INCBIN "orig/painter_momopie.gb", $0675d, 1152
Sound86MusicData::  ; stream of sound id $86
    INCBIN "orig/painter_momopie.gb", $06bdd, 1230
Sound87MusicData::  ; stream of sound id $87
    INCBIN "orig/painter_momopie.gb", $070ab, 902
Sound88MusicData::  ; stream of sound id $88
    INCBIN "orig/painter_momopie.gb", $07431, 1129
Sound89MusicData::  ; stream of sound id $89
    INCBIN "orig/painter_momopie.gb", $0789a, 699
Sound8AMusicData::  ; stream of sound id $8a
    INCBIN "orig/painter_momopie.gb", $07b55, 512
Sound8BMusicData::  ; stream of sound id $8b
    INCBIN "orig/painter_momopie.gb", $07d55, 512
D_01_7f55::
    INCBIN "orig/painter_momopie.gb", $07f55, 171

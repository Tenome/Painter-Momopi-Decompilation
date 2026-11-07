INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank01", ROMX[$4000], BANK[1]

    INCBIN "assets/bank_01/4000.bin"
SoundFrequencyTable::  ; word frequency (NRx3/NRx4 value) per note index; SoundParseStream reads it with 2 * (note byte + transpose)
    INCBIN "assets/bank_01/4048_SoundFrequencyTable.bin"
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
    INCBIN "assets/bank_01/4140.bin"
D_01_4141::
    INCBIN "assets/bank_01/4141.bin"
SoundUpdate::  ; per-frame sound engine called from VBlankHandler
    ld a, [wSoundBusy]
    and a, a
    jr nz, .L_01_4160
    call SoundDequeue
.L_01_4160:
    call SoundStartCommand
    call SoundAssignChannels
    ld a, $08
    ld [wSoundChanLeft], a
    ld bc, wSoundChannels
    ld h, b
    ld l, c
.L_01_4170:
    ld a, [hl]
    bit 7, a
    jr z, .L_01_4178
    call SoundUpdateChannel
.L_01_4178:
    ld a, [wSoundChanLeft]
    dec a
    ld [wSoundChanLeft], a
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
    ld hl, SoundCommandHandlerTable
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
    jp SoundStartMusicNow
SoundClearChannels::  ; clears the first byte of all 8 channel records and sets NR50 default ($77)
    ld a, $00
    ld [wSoundChannels], a
    ld [wSoundChan1], a
    ld [wSoundChan2], a
    ld [wSoundChan3], a
    ld [wSoundChan4], a
    ld [wSoundChan5], a
    ld [wSoundChan6], a
    ld [wSoundChan7], a
    ld a, $77
    ld [wSoundMasterVol], a
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
    ld a, [wSoundMasterVol]
    ld [rNR50], a
    ld a, $87
    ld [rNR14], a
    ld [rNR24], a
    ld [rNR34], a
    ld [rNR44], a
SoundClearRegisterShadow::  ; zeroes the register shadow bytes at $c427-$c431
    ld a, $00
    ld [wShadowNR12], a
    ld [wShadowNR13], a
    ld [wShadowNR14], a
    ld [wShadowNR22], a
    ld [wShadowNR23], a
    ld [wShadowNR24], a
    ld [wShadowNR32], a
    ld [wShadowNR33], a
    ld [wShadowNR34], a
    ld [wShadowNR42], a
    ld [wShadowNR43], a
    ld [$c432], a
    ret
SoundStartMusic::  ; starts a music stream (priority at $4141 + id; replaces lower priority music)
    ld hl, D_01_4141
    add hl, bc
    ld a, [hl]
    ld b, a
    ld a, [wMusicPriority]
    cp a, b
    jr z, SoundStartMusicNow
    jr nc, SoundRequestStop
SoundStartMusicNow::  ; music accepted by the priority check: records the priority
    ld a, b
    ld [wMusicPriority], a
    call SoundClearChannels
    ld a, $00
    ld [wSoundChannels], a
    ld [wSoundChan1], a
    ld [wSoundChan2], a
    ld [wSoundChan3], a
    ld hl, wSoundChannels
    jp SoundLoadStream
SoundRequestStop::  ; sets wSoundCmd to $80 (stop request; name provisional)
    ld a, $80
    ld [wSoundCmd], a
    ret
SoundStartEffect::  ; starts an effect stream (priority compare with $c310)
    ld hl, D_01_4141
    add hl, bc
    ld a, [hl]
    ld b, a
    ld a, [wEffectPriority]
    cp a, b
    jr z, .L_01_42a0
    jr nc, SoundRequestStop
.L_01_42a0:
    ld a, b
    ld [wEffectPriority], a
    call SoundClearRegisterShadow
    ld a, $00
    ld [wSoundChan4], a
    ld [wSoundChan5], a
    ld [wSoundChan6], a
    ld [wSoundChan7], a
    ld hl, wSoundChan4
    jp SoundLoadStream
SoundPauseMusicChannels::  ; sets the pause flag (bit 4) on the music channel records while an effect plays
    ld a, [wEffectPriority]
    inc a
    ld [wEffectPriority], a
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
    ld a, [wEffectPriority]
    inc a
    ld [wEffectPriority], a
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
    ld [wSoundTmp], a
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
    ld a, [wSoundTmp]
    dec a
    ld [wSoundTmp], a
    jr nz, .L_01_430b
    ld a, $80
    ld [wSoundCmd], a
    ret
D_01_4332::
    INCBIN "assets/bank_01/4332.bin"
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
    ld de, wSoundChan4
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
    ld hl, SoundWriteChannel4
    jp hl
.L_01_43eb:
    cp a, $02
    jr nz, .L_01_43f3
    ld hl, SoundWriteChannel3
    jp hl
.L_01_43f3:
    cp a, $01
    jr nz, .L_01_43fb
    ld hl, SoundWriteChannel2
    jp hl
.L_01_43fb:
    cp a, $00
    jr nz, .L_01_4403
    ld hl, SoundWriteChannel1
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
    ld a, [wShadowNR12]
    cp a, [hl]
    jr z, .L_01_441f
    ld a, [hl]
    ld [wShadowNR12], a
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
    ld a, [wShadowNR13]
    cp a, [hl]
    jr nz, .L_01_4449
    inc hl
    ld a, [wShadowNR14]
    cp a, [hl]
    ret z
    dec hl
.L_01_4449:
    ld a, [hl+]
    ld [rNR13], a
    ld [wShadowNR13], a
    ld a, [hl]
    ld [wShadowNR14], a
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
    ld [wShadowNR13], a
    ld a, $87
    ld [rNR14], a
    ld [wShadowNR14], a
    ret
SoundWriteChannel2::  ; writes pulse channel 2 registers (NR21 NR22 NR23/NR24)
    ld hl, $0015
    add hl, bc
    ld a, [hl]
    and a, $c0
    ld [rNR21], a
    ld hl, $0007
    add hl, bc
    ld a, [wShadowNR22]
    cp a, [hl]
    jr z, .L_01_449f
    ld a, [hl]
    ld [wShadowNR22], a
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
    ld a, [wShadowNR23]
    cp a, [hl]
    jr nz, .L_01_44c9
    inc hl
    ld a, [wShadowNR24]
    cp a, [hl]
    ret z
    dec hl
.L_01_44c9:
    ld a, [hl+]
    ld [rNR23], a
    ld [wShadowNR23], a
    ld a, [hl]
    ld [wShadowNR24], a
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
    ld [wShadowNR23], a
    ld a, $87
    ld [rNR24], a
    ld [wShadowNR24], a
    ret
SoundWriteChannel3::  ; writes wave channel 3 registers (NR32 NR33/NR34)
    ld hl, $0012
    add hl, bc
    ld a, [hl+]
    or a, [hl]
    jr z, SoundSilenceChannel3
    ld hl, $0007
    add hl, bc
    ld a, [wShadowNR32]
    cp a, [hl]
    jr z, .L_01_451f
    ld a, [hl]
    ld [wShadowNR32], a
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
    ld a, [wShadowNR33]
    cp a, [hl]
    jr nz, .L_01_453d
    inc hl
    ld a, [wShadowNR34]
    cp a, [hl]
    ret z
    dec hl
.L_01_453d:
    ld a, [hl+]
    ld [rNR33], a
    ld [wShadowNR33], a
    ld a, [hl]
    ld [wShadowNR34], a
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
    ld [wShadowNR33], a
    ld a, $07
    ld [rNR34], a
    ld [wShadowNR34], a
    ret
SoundWriteChannel4::  ; writes noise channel 4 registers (NR42 NR43 NR44)
    ld hl, $0007
    add hl, bc
    ld a, [wShadowNR42]
    cp a, [hl]
    jr z, .L_01_4583
    ld a, [hl]
    ld [wShadowNR42], a
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
    ld a, [wShadowNR43]
    cp a, [hl]
    ret z
    ld a, [hl]
    ld [rNR43], a
    ld [wShadowNR43], a
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
    ld [wShadowNR43], a
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
    ld hl, SoundCommandTable
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
    ld [wMusicPriority], a
SoundSilenceRecordChannel::  ; ends a stream: silences the hardware channel of the record (1 pulse1 2 pulse2 3 wave 4 noise)
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
    ld hl, SoundFrequencyTable
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
    jr z, SoundSkipOperand2
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
SoundSkipOperand2::  ; skips two stream bytes (command with an unused 2 byte operand)
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
SoundSetPendingWave::  ; stores the next stream byte at $c312 (pending wave pattern index)
    ld a, [de]
    inc de
    ld [wWavePending], a
    ret
SoundCmdSetWave::  ; command $ea: selects a wave pattern (SoundLoadWave) on the wave channel
    ld a, [bc]
    bit 2, a
    jr nz, SoundSetPendingWave
    ld a, [de]
    inc de
    ld hl, wWaveCurrent
    cp a, [hl]
    jr z, L_01_4775
    ld [hl], a
    ld hl, wSoundChannels
    ld a, c
    sub a, l
    cp a, $60
    jr nc, .L_01_4747
    ld a, [wWaveCurrent]
    ld [wWavePending], a
    jr SoundLoadWave
.L_01_4747:
    ld a, [wWaveCurrent]
    ld [wWaveEffect], a
SoundLoadWave::  ; copies a 16 byte wave pattern from the table at $3fb8 into wave RAM
    push bc
    ld bc, D_00_3fb8
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
    ld [wEffectPriority], a
    ld a, [wWavePending]
    ld hl, wWaveCurrent
    cp a, [hl]
    jr z, .L_01_4788
    ld [hl], a
    call SoundLoadWave
.L_01_4788:
    ld a, $00
    pop hl
    jp SoundSilenceRecordChannel
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
    ld [wSoundMasterVol], a
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
    call nz, SoundPitchSlideStep
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
    ld [wSoundTmp], a
    cp a, $80
    jr z, .L_01_4809
    cp a, $81
    jr z, .L_01_4812
    cp a, $82
    jr z, .L_01_481a
    cp a, $83
    jr z, .L_01_4800
    ld hl, $0012
    jr SoundAddSigned16
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
SoundPitchSlideStep::  ; adds the signed slide in record +$14 to the 16 bit pitch at +$10
    ld hl, $0014
    add hl, bc
    ld a, [hl]
    ld [wSoundTmp], a
    ld hl, $0010
    call SoundAddSigned16
    ld hl, $0011
    add hl, bc
    ld a, d
    ld [hl-], a
    ld a, e
    ld [hl], a
    ret
SoundAddSigned16::  ; DE = word at record[HL] plus the signed byte in $c30b
    add hl, bc
    ld a, [hl+]
    ld e, a
    ld a, [hl]
    ld d, a
    ld a, [wSoundTmp]
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
    INCBIN "assets/bank_01/487b.bin"
D_01_488c::
    INCBIN "assets/bank_01/488c.bin"
AnimFrames1_48ac::  ; animation frames (typed text form)
    INCBIN "assets/bank_01/48ac_AnimFrames1_48ac.bin"
PlayerAnimPtrs::  ; player animation pointers (down/up/side) chosen by SelectPlayerAnimation
    INCBIN "assets/bank_01/48c4_PlayerAnimPtrs.bin"
PlayerAnimPtrsFlipped::  ; pointers for the side animation drawn flipped
    INCBIN "assets/bank_01/48cc_PlayerAnimPtrsFlipped.bin"
D_01_48d4::
    INCBIN "assets/bank_01/48d4.bin"
AnimFrames1_48dc::  ; animation frames (typed text form)
    INCBIN "assets/bank_01/48dc_AnimFrames1_48dc.bin"
D_01_491b::
    INCBIN "assets/bank_01/491b.bin"
D_01_4921::
    INCBIN "assets/bank_01/4921.bin"
D_01_4927::
    INCBIN "assets/bank_01/4927.bin"
D_01_4929::
    INCBIN "assets/bank_01/4929.bin"
D_01_492b::
    INCBIN "assets/bank_01/492b.bin"
D_01_492d::
    INCBIN "assets/bank_01/492d.bin"
ClearBonusFlags::  ; clears wGameFlags bits 7 and 0 (name provisional)
    ld hl, wGameFlags
    res 7, [hl]
    res 0, [hl]
    ret
CheckBonusRound::  ; sets wGameFlags bit 6 (go to the bonus screens after the clear) when wRound is 4 8 12 20 24 or 28
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
BeginMagicCast::  ; plays SND_SFX_82 and sets wMagicState bit 1
    ld a, SND_SFX_82
    call PlaySound
    ld hl, wMagicState
    set 1, [hl]
    ret
MagicTimerTick::  ; counts $ffdf down; ends the effect when it reaches 0
    ld hl, hMagicTimer
    dec [hl]
    ret nz
EndMagic::  ; clears wMagicState
    xor a, a
    ld [wMagicState], a
    ret
SpawnBombBlob::  ; creates the paint blob object for the B.O.M card ($4929 animation) and sets wPlayerStatus bit 4
    ld hl, wPaintObject
    call Clear32Bytes
    ld a, $08
    ld [$c1f7], a
    ld a, $07
    ldh [hMagicTimer], a
    ld hl, wPlayerStatus
    set 4, [hl]
    ld a, $2a
    ld [$c50f], a
    ld hl, D_01_4929
    ld a, l
    ld [wPaintAnimLo], a
    ld a, h
    ld [wPaintAnimHi], a
    ld a, $08
    ld [$c449], a
    ld a, $82
    ld [wPaintObject], a
    call InitTrailSegments
    jp BeginMagicCast
ForEachEnemySlotInit::  ; loops the 16 entries of EnemySlotTable (name provisional)
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
SpawnPaintBlob::  ; creates the paint blob object at wPaintObject at the player's position (flags $86)
    ld hl, wPaintObject
    call Clear32Bytes
    ld hl, D_01_492b
    ld a, l
    ld [wPaintAnimLo], a
    ld a, h
    ld [wPaintAnimHi], a
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
    ldh [hMagicTimer], a
    ld hl, wMagicState
    set 4, [hl]
    set 1, [hl]
    ret
SetPaintBlobAnimation::  ; picks animation $4927 or $4929 for the paint blob by $c519 bit 1
    ld a, [wBlobPhase]
    and a, $02
    jr z, .L_01_4a3d
    ld hl, D_01_4927
    jr .L_01_4a40
.L_01_4a3d:
    ld hl, D_01_4929
.L_01_4a40:
    ld a, l
    ld [wPaintAnimLo], a
    ld a, h
    ld [wPaintAnimHi], a
    ret
LoadTrailSegment::  ; copies the 7 byte trail segment $c1b6 of $c1b7.. into the paint blob object
    ld a, [wTrailIdx]
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
StoreTrailSegment::  ; copies the paint blob object back into trail segment $c1b6
    ld a, [wTrailIdx]
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
InitTrailSegments::  ; creates 8 trail segments of 7 bytes around the player at $c1b7
    ld bc, $0040
    ld hl, $c1b7
    call ClearMemory
    ld hl, $c1b7
    ld d, $10
    ld e, $00
    ld a, $08
    call InitTrailSegment
    ld hl, $c1be
    ld d, $10
    ld e, $f0
    ld a, $04
    call InitTrailSegment
    ld hl, $c1c5
    ld d, $00
    ld e, $f0
    ld a, $00
    call InitTrailSegment
    ld hl, $c1cc
    ld d, $f0
    ld e, $00
    ld a, $1c
    call InitTrailSegment
    ld hl, $c1d3
    ld d, $f0
    ld e, $00
    ld a, $18
    call InitTrailSegment
    ld hl, $c1da
    ld d, $f0
    ld e, $10
    ld a, $14
    call InitTrailSegment
    ld hl, $c1e1
    ld d, $00
    ld e, $10
    ld a, $10
    call InitTrailSegment
    ld hl, $c1e8
    ld d, $10
    ld e, $10
    ld a, $0c
InitTrailSegment::  ; sets one trail segment: HL = segment; A = type; D/E = offsets from the player
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
    INCBIN "assets/bank_01/4b33.bin"
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
PlayerComputeBlockedDirs::  ; fills wPlayerBlocked from the room map cells around the player
    xor a, a
    ld [wPlayerBlocked], a
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
    ld [wPlayerBlocked], a
    ldh [hEnemyBlocked], a
.L_01_4b98:
    ld a, c
    add a, $10
    call LookupMapTile
    and a, $0f
    or a, $00
    jr nz, .L_01_4bae
    ld a, [wPlayerBlocked]
    or a, $08
    ld [wPlayerBlocked], a
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
    ld a, [wPlayerBlocked]
    or a, $02
    ld [wPlayerBlocked], a
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
    ld a, [wPlayerBlocked]
    or a, $01
    ld [wPlayerBlocked], a
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
    ld a, [wActiveMagic]
    cp a, $02
    jr nz, .L_01_4c12
    ld a, [wMagicState]
    bit 0, a
    jr nz, .L_01_4c1b
.L_01_4c12:
    call PlayerCheckOffPath
    call LoadPlayerXY
    call PlayerComputeBlockedDirs
.L_01_4c1b:
    call HoldDirectionUntilAligned
    call PlayerSetDirection
    call ClampPlayerPosition
    call PaintUnderPlayer
    call SelectPlayerAnimation
    call ProjectileFrame
    ld a, [wActiveMagic]
    or a, a
    jr z, .L_01_4c42
    ld a, [wMagicState]
    bit 0, a
    jr z, .L_01_4c42
    ld hl, $c4d3
    inc [hl]
    ld a, [hl]
    and a, $02
    ret z
.L_01_4c42:
    call AnimatePlayerWalk
    ld hl, wPlayer
    call SetObjPtr
    jp DrawObject
PlayerCheckOffPath::  ; sets wPlayerDir bit 5 (death) when the player stands on a tile grid cell that is not a path
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
PlayerAction::  ; A button in play: casts the card selected on the magic screen (wActiveMagic): sets wMagicState bit 0
    ld a, [wMagicState]
    bit 0, a
    jr nz, RunMagicEffect
    ldh a, [hJoyNew]
    bit 0, a
    ret z
    ld hl, wPlayerDir
    set 6, [hl]
    ld hl, wMagicState
    res 1, [hl]
    ld a, [wActiveMagic]
    and a, a
    ret z
    ld a, [wPlayerStatus]
    bit 0, a
    ret z
    ld hl, wMagicState
    set 0, [hl]
    ld hl, MagicCostTable
    ld a, [wActiveMagic]
    ld c, a
    call LookupByte
    ld c, a
    ld a, [wMagicPoints]
    sub a, c
    ld e, a
    jr z, LinkSyncFrame
PayMagicCost::  ; subtracts the card cost from wMagicPoints (borrowing from the high byte) and starts the effect; cancels the cast when MP is too low
    jr c, .L_01_4cae
    ld [wMagicPoints], a
    jr RunMagicEffect
.L_01_4cae:
    ld a, [wMagicPointsHi]
    and a, a
    jr z, CancelMagic
    ld a, e
    ld [wMagicPoints], a
    xor a, a
    ld [wMagicPointsHi], a
RunMagicEffect::  ; jumps to the effect routine of wActiveMagic (clears wMagicState bit 2 first)
    ld a, [wMagicState]
    res 2, a
    ld [wMagicState], a
    ld hl, MagicEffectTable
    ld a, [wActiveMagic]
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
MagicEffectTable::  ; 10 pointers to the card effect routines (index = card id)
    dw MagicEffectSUp
    dw MagicEffectSUp
    dw MagicEffectWIn
    dw MagicEffectTStop
    dw MagicEffectGhost
    dw MagicEffectFriend
    dw MagicEffectSealed
    dw MagicEffectBom
    dw MagicEffectClear
    dw MagicEffectPyon
CancelMagic::  ; clears wActiveMagic and wMagicState
    xor a, a
    ld [wActiveMagic], a
    ld [wMagicState], a
    ret
LinkSyncFrame::  ; per-frame link cable exchange for the 2 player game (rSC rSB)
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, PayMagicCost
    ld a, [wMagicPointsHi]
    and a, a
    jr nz, PayMagicCost
    ldh a, [hSerialByte]
    and a, $20
    ld [wRemoteRound], a
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
    call z, SetLinkFlag5
    ld a, [wRemoteRound]
    bit 5, a
    call nz, SetLinkFlag5
    call SerialStartTransfer
    xor a, a
    ld [wMagicPoints], a
    ret
SetLinkFlag5::  ; sets hSerialByte bit 5 (name provisional)
    ld hl, hSerialByte
    set 5, [hl]
    ret
MagicEffectSealed::  ; card 6 SEALED: $a0 frames
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4d52
    ld a, $a0
    ldh [hMagicTimer], a
    call BeginMagicCast
.L_01_4d52:
    jp MagicTimerTick
MagicEffectSUp::  ; card 1 S.UP: the player moves faster for $f0 frames (measured: reaches the same wall in about half the time)
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4d63
    ld a, $f0
    ldh [hMagicTimer], a
    call BeginMagicCast
.L_01_4d63:
    jp MagicTimerTick
MagicEffectWIn::  ; card 2 W.IN: $d0 frames; the player is no longer stopped by walls (measured: positions leave the room map); clears wPlayerBlocked
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4d74
    ld a, $d0
    ldh [hMagicTimer], a
    call BeginMagicCast
.L_01_4d74:
    xor a, a
    ld [wPlayerBlocked], a
    jp MagicTimerTick
MagicEffectTStop::  ; card 3 T.STOP: $d0 frames; removes the object at $c49e
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4d8e
    ld a, $d0
    ldh [hMagicTimer], a
    call BeginMagicCast
    ld hl, wProjectile
    res 7, [hl]
.L_01_4d8e:
    jp MagicTimerTick
MagicEffectGhost::  ; card 4 GHOST: $b0 frames
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4d9f
    ld a, $b0
    ldh [hMagicTimer], a
    call BeginMagicCast
.L_01_4d9f:
    jp MagicTimerTick
MagicEffectFriend::  ; card 5 FRIEND: $b0 frames; removes the object at $c49e
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4db5
    ld a, $b0
    ldh [hMagicTimer], a
    call BeginMagicCast
    ld hl, wProjectile
    res 7, [hl]
.L_01_4db5:
    jp MagicTimerTick
MagicEffectPyon::  ; card 9 PYON: creates the paint blob object at the player
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4dc2
    call SpawnPaintBlob
.L_01_4dc2:
    ld hl, wPaintObject
    call SetObjPtr
    ld hl, wBlobPhase
    inc [hl]
    call MagicPaintEndUnlessBit2
    ld a, [wPlayerX]
    ld c, a
    ld a, [wPlayerY]
    ld b, a
    call EnemyScreenPosition
    and a, a
    jr z, .L_01_4de2
    ld hl, wPaintObject
    res 7, [hl]
.L_01_4de2:
    call SelectBlobAnimation
    call MoveObject
    call ClampObjectToRoom
    jp DrawObject
SelectBlobAnimation::  ; chooses the paint blob animation pointer ($492b or $492d) from $c519
    ld a, [wBlobPhase]
    and a, $02
    jr z, .L_01_4dfa
    ld hl, D_01_492b
    jr .L_01_4dfd
.L_01_4dfa:
    ld hl, D_01_492d
.L_01_4dfd:
    ld a, l
    ld [wPaintAnimLo], a
    ld a, h
    ld [wPaintAnimHi], a
    ret
MagicEffectBom::  ; card 7 B.O.M: spawns the paint blob object and draws it
    ld hl, wBlobPhase
    ld a, [wMagicState]
    bit 1, a
    jr nz, .L_01_4e16
    call SpawnBombBlob
    call ForEachEnemySlotInit
.L_01_4e16:
    call LoadTrailSegment
    ld hl, wPaintObject
    call SetObjPtr
    call MoveObject
    call ClampObjectToRoom
    call DrawObject
    call StoreTrailSegment
    call SetPaintBlobAnimation
    ld hl, $c449
    dec [hl]
    jr z, .L_01_4e3a
    ld hl, wTrailIdx
    inc [hl]
    jr .L_01_4e16
.L_01_4e3a:
    call MagicTimerCountdown
    ld a, $08
    ld [$c449], a
    xor a, a
    ld [wTrailIdx], a
    ret
MagicTimerCountdown::  ; decrements hMagicTimer; at zero clears wMagicState and ends the paint (name provisional)
    ldh a, [hMagicTimer]
    dec a
    ldh [hMagicTimer], a
    ret nz
    xor a, a
    ld [wMagicState], a
    jr EndMagicPaint
MagicPaintEndUnlessBit2::  ; ends the magic paint unless wPaintObject bit 2 is set (name provisional)
    ld a, [wPaintObject]
    bit 2, a
    ret nz
EndMagicPaint::  ; clears the paint object active bit then ends the magic state bits (name provisional)
    ld hl, wPaintObject
    res 7, [hl]
    ld a, [wActiveMagic]
    cp a, $09
    jr nz, .L_01_4e6e
    ld a, [wMagicState]
    and a, $f8
    ld [wMagicState], a
    ret
.L_01_4e6e:
    ld a, [wMagicState]
    and a, $08
    ld [wMagicState], a
    ret
MagicEffectClear::  ; card 8 CLEAR: $50 steps
    ld a, [wMagicState]
    bit 1, a
    jp nz, .L_01_4e86
    xor a, a
    ld [$c1f8], a
    call BeginMagicCast
.L_01_4e86:
    ld hl, wBlobPhase
    inc [hl]
    ld a, [$c1f8]
    cp a, $50
    jr z, .L_01_4ea5
    inc a
    ld [$c1f8], a
    ld a, PAL_NORMAL
    ld [rBGP], a
    ld a, [wBlobPhase]
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
    jp z, EndMagic
    jr .L_01_4eb3
.L_01_4ec5:
    and a, $0f
    or a, $10
    ld [hl], a
    ldh [hScratch02], a
    push bc
    call MapCellToVramAddr
    call QueueCellTileRows
    pop bc
    ld hl, wPaintRemaining
    dec [hl]
    jp z, RoundCleared
    jr .L_01_4ebc
MapCellToVramAddr::  ; hScratch00/01 = background map address of the cell at pixel position B C
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
QueueCellTileRows::  ; queues the 2x2 tile update of a cell (painted tiles D_01_4921 or normal D_01_491b)
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
AnimatePlayerWalk::  ; while a direction is held: advances the walk animation counter $c4d9 and selects the frame
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
    call CounterToFrame
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
PaintUnderPlayer::  ; when the player is on the tile grid and the map cell is a path cell: PaintCell
    ld a, [wActiveMagic]
    cp a, $09
    jr nz, .L_01_4fe3
    ld a, [wMagicState]
    bit 0, a
    ret nz
.L_01_4fe3:
    ld a, [wActiveMagic]
    cp a, $02
    jp z, PaintUnderPlayerAligned
PaintUnderPlayerCell::  ; looks up the cell under the player and paints it (shared tail of PaintUnderPlayer)
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
    call CheckBonusRound
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
PaintUnderPlayerAligned::  ; paints the cell under the player at the grid aligned Y
    ld a, [wPlayerX]
    call PixelXToColumn
    ld a, [wPlayerY]
    and a, $f0
    add a, $08
    call LookupMapTile
    or a, a
    ret z
    jp PaintUnderPlayerCell
PlayerSetDirection::  ; dpad to wPlayerDir and the animation index
    ldh a, [hJoyHeld]
    ld e, a
    ld a, [wPlayerBlocked]
    swap a
    and a, e
    jp nz, SetPlayerStatusBit0
    ldh a, [hJoyHeld]
    and a, $f0
    jp z, SetPlayerStatusBit0
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
    ld a, [wActiveMagic]
    cp a, $01
    jr nz, .L_01_5153
    ld a, [wMagicState]
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
    call ClampObjectToRoom
    ld hl, wPlayerStatus
    res 0, [hl]
    ret
DirectionToAnimIndex::  ; dpad direction nibble to animation index
    INCBIN "assets/bank_01/5178_DirectionToAnimIndex.bin"
SetPlayerStatusBit0::  ; sets wPlayerStatus bit 0 and clears $c4cf
    ld hl, wPlayerStatus
    set 0, [hl]
    xor a, a
    ld [$c4cf], a
    ret
D_01_518d::
    INCBIN "assets/bank_01/518d.bin"
D_01_519d::
    INCBIN "assets/bank_01/519d.bin"
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
    ld [wMagicCastTimer], a
    ld [$c4c2], a
    ld [wPlayerBlocked], a
    ld [wTrailIdx], a
    ld [wPlayerDir], a
    ld [wPlayerStatus], a
    ldh [hMagicTimer], a
    ld hl, PlayerAnimPtrs
    ld a, [hl+]
    ld [$c4bf], a
    ld a, [hl]
    ld [$c4c0], a
    ldh a, [hLinkFlags]
    bit 0, a
    jr z, .L_01_5207
    ld a, $01
    ld [wMagicCards], a
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
    ld [wMagicCards], a
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
    ld hl, wMagicCastTimer
    inc [hl]
    ld a, $3c
    ldh [hScratch06], a
    ld a, $02
    ldh [hScratch07], a
    ld a, [wMagicCastTimer]
    ldh [hScratch08], a
    ld a, $0f
    call CounterToFrame
    ldh a, [hScratch08]
    ld [wMagicCastTimer], a
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
    ld [wActiveMagic], a
    ld [wMagicCastTimer], a
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
    ld a, [wRoundFlags]
    set 0, a
    and a, $f9
    ld [wRoundFlags], a
    ld a, $03
    ld [wLives], a
    ld a, $50
    call DelayFrames
    ld a, [wContinues]
    and a, a
    jr nz, .L_01_52fc
    ld a, [wCheatFlags]
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
    ld a, [wCameraXHi]
    sbc a, $00
    ld [wCameraXHi], a
    bit 7, a
    jr nz, .L_01_5337
    ld a, [wCameraX]
    cp a, $60
    jr c, .L_01_533e
    ld a, $60
    ld [wCameraX], a
    xor a, a
    ld [wCameraXHi], a
    jr .L_01_533e
.L_01_5337:
    xor a, a
    ld [wCameraXHi], a
    ld [wCameraX], a
.L_01_533e:
    ld a, [wPlayerY]
    sub a, $68
    ld [wCameraY], a
    ld a, [wCameraYHi]
    sbc a, $00
    ld [wCameraYHi], a
    bit 7, a
    jr nz, .L_01_5362
    ld a, [wCameraY]
    cp a, $70
    ret c
    ld a, $70
    ld [wCameraY], a
    xor a, a
    ld [wCameraYHi], a
    ret
.L_01_5362:
    xor a, a
    ld [wCameraY], a
    ld [wCameraYHi], a
    ret
ResetCamera::  ; wCameraX and wCameraY = $20; high bytes 0
    ld a, $20
    ld [wCameraX], a
    ld [wCameraY], a
    xor a, a
    ld [wCameraXHi], a
    ld [wCameraYHi], a
    ret
EnemyKind4::  ; enemy kind 4
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_5385
    jp EnemyKind4Init
.L_01_5385:
    call EnemyAimAtPlayer
    call EnemyTurnOrAnimate
    call CheckEnemyTouchesPlayer
    call SelectKind4Animation
    jp DrawObject
SelectKind4Animation::  ; animation pointers of enemy kind 4 by hEnemyDir
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_01_53a8
    bit 1, a
    jr nz, .L_01_53b3
    bit 2, a
    jr nz, .L_01_53be
    ld de, D_01_53e5
    jp SetObjectAnimationStub
.L_01_53a8:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_01_53ec
    jp SetObjectAnimationStub
.L_01_53b3:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_53ec
    jp SetObjectAnimationStub
.L_01_53be:
    ld de, D_01_53f3
    jp SetObjectAnimationStub
EnemyKind4Init::  ; sets the counters and the first animation of enemy kind 4 ($80 or $50 steps in a link game)
    ld a, $08
    ldh [hEnemySpeed], a
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
    INCBIN "assets/bank_01/53e5.bin"
D_01_53ec::
    INCBIN "assets/bank_01/53ec.bin"
D_01_53f3::
    INCBIN "assets/bank_01/53f3.bin"
EnemyKind10::  ; enemy kind 10 (rounds 14 and 30)
    call TickObjectTimer
    jr nz, .L_01_551b
    jp InitProjectile
.L_01_551b:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyTurnOrAnimate
    call EnemyKind10Move
    call UpdateProjectile
    call ProjectileCheckPlayerHit
    call ProjectileRemoveIfHit
    call ProjectileSelectFrame
    call SelectObject2
    jp DrawObject
ProjectileRemoveIfHit::  ; removes the projectile and its enemy when hEnemyFlags has bits 1 and 3 set
    ldh a, [hEnemyFlags]
    and a, $0a
    cp a, $0a
    ret nz
    ld hl, wProjectile
    res 7, [hl]
    jp RemoveEnemy
ProjectileSelectFrame::  ; picks the projectile animation frame pointer from $c499/$c49a by hEnemyTick bit 2 (name provisional)
    ldh a, [hEnemyTick]
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
    ldh [hEnemyAnimLo], a
    ld a, [hl]
    ldh [hEnemyAnimHi], a
    ret
UpdateProjectile::  ; projectile steps while the shooter enemy lives; removed when the shooter is hit
    ldh a, [hEnemyFlags]
    bit 0, a
    ret nz
    ldh a, [hEnemyFlags]
    bit 3, a
    jr z, .L_01_557b
    ld hl, wProjectile
    res 7, [hl]
    ret
.L_01_557b:
    ldh a, [hEnemyX]
    ld c, a
    ldh a, [hEnemyY]
    ld b, a
    call EnemyScreenPosition
    ret nz
    ld hl, hEnemyStep
    dec [hl]
    ret nz
    call L_01_570c
    ldh a, [hEnemyX]
    ld [$c4a5], a
    ldh a, [hEnemyY]
    ld [$c4a8], a
    ld a, $86
    ld [wProjectile], a
    ldh a, [hEnemyKind]
    cp a, $0a
    jr nz, .L_01_55a7
    ld de, D_01_57ec
    jr .L_01_55aa
.L_01_55a7:
    ld de, D_01_57c9
.L_01_55aa:
    ld a, e
    ld [wProjectileAnimLo], a
    ld a, d
    ld [wProjectileAnimHi], a
    ld a, $50
    ldh [hEnemyStep], a
    ld hl, hEnemyFlags
    set 0, [hl]
    ret
ProjectileCheckPlayerHit::  ; when hEnemyFlags bit 0 is set runs ProjectileHitTest on the boxes at $c4a5-$c4a9 (name provisional)
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
    call ProjectileHitTest
    and a, a
    jr z, .L_01_560d
    ld hl, hEnemyDir
    set 5, [hl]
    ld a, $0b
    ld [$c4af], a
    ld a, [wActiveMagic]
    cp a, $03
    jr nz, .L_01_55fb
    ld a, [wMagicState]
    bit 0, a
    jp z, .L_01_55fb
    xor a, a
    ldh [hEnemySpeed], a
    xor a, a
    ld [$c4af], a
.L_01_55fb:
    call EnemyKind10Animate
    ld hl, wProjectile
    call SetObjPtr
    call MoveObject
    call ClampObjectToRoom
    jp DrawObject
.L_01_560d:
    ld hl, wProjectile
    res 7, [hl]
    ld hl, hEnemyFlags
    set 1, [hl]
    ret
EnemyKind10Animate::  ; toggles between two animations D_01_57ec and D_01_57ee every 4 ticks (kind $0a only; name provisional)
    ldh a, [hEnemyKind]
    cp a, $0a
    ret nz
    ld hl, hEnemyCounter2
    inc [hl]
    ld hl, D_01_57ec
    ldh a, [hEnemyCounter2]
    and a, $04
    jr z, .L_01_562d
    ld hl, D_01_57ee
.L_01_562d:
    ld a, l
    ld [wProjectileAnimLo], a
    ld a, h
    ld [wProjectileAnimHi], a
    ret
EnemyKind10Move::  ; moves and clamps the enemy by the speed table D_01_5782 indexed by hEnemyDir (name provisional)
    ldh a, [hEnemyDir]
    and a, $0f
    srl a
    ld c, a
    ld b, $00
    ld hl, D_01_5782
    add hl, bc
    ld a, [hl]
    ldh [hEnemyAngle], a
    call SelectObject2
    call MoveObject
    call ClampObjectToRoom
    ldh a, [hEnemyX]
    ldh [hScratch00], a
    ldh a, [hEnemyXHi]
    ldh [hScratch01], a
    ldh a, [hEnemyY]
    ldh [hScratch02], a
    ldh a, [hEnemyYHi]
    ldh [hScratch03], a
    call ProjectileHitTest
    and a, a
    ret nz
    ld hl, hEnemyFlags
    set 3, [hl]
    ret
EnemyFlagBit3IfDead::  ; sets hEnemyFlags bit 3 when hEnemyDir bit 5 is set
    ldh a, [hEnemyDir]
    bit 5, a
    jr nz, .L_01_5671
    ret
.L_01_5671:
    ld hl, hEnemyFlags
    set 3, [hl]
    ret
ProjectileHitTest::  ; compares projectile and player boxes (hScratch00-03): A = 1 on a hit
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
InitProjectile::  ; creates the projectile object at wProjectile for the kind 10 enemy
    ld hl, wProjectile
    call Clear32Bytes
    ld a, $01
    ld [$c4a2], a
    xor a, a
    ld [hEnemyFlags], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $30
    ldh [hEnemyStep], a
    ldh a, [hEnemyKind]
    cp a, $0a
    jr nz, .L_01_56ca
    ld bc, D_01_5793
    ld de, D_01_579b
    ld hl, D_01_5797
    jr .L_01_56d3
.L_01_56ca:
    ld bc, D_01_5787
    ld de, D_01_578f
    ld hl, D_01_578b
.L_01_56d3:
    call EnemySnapToGrid
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
    jp ProjectileSelectFrame
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
    INCBIN "assets/bank_01/5782.bin"
D_01_5787::
    INCBIN "assets/bank_01/5787.bin"
D_01_578b::
    INCBIN "assets/bank_01/578b.bin"
D_01_578f::
    INCBIN "assets/bank_01/578f.bin"
D_01_5793::
    INCBIN "assets/bank_01/5793.bin"
D_01_5797::
    INCBIN "assets/bank_01/5797.bin"
D_01_579b::
    INCBIN "assets/bank_01/579b.bin"
D_01_57c9::
    INCBIN "assets/bank_01/57c9.bin"
D_01_57ec::
    INCBIN "assets/bank_01/57ec.bin"
D_01_57ee::
    INCBIN "assets/bank_01/57ee.bin"
EnemyKind9::  ; enemy kind 9
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_57fb
    jp EnemyKind9Init
.L_01_57fb:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call EnemyAimAtPlayer
    call EnemyTurnOrAnimate
    call EnemyPaintUnderB0M
    call CheckEnemyTouchesPlayer
    call SelectKind9Animation
    jp DrawObject
EnemyKind9Move::  ; sets hEnemySpeed 6 then moves and clamps (name provisional)
    ld a, $06
    ldh [hEnemySpeed], a
    call EnemyTurnIfBlocked
    jp MoveAndClampObject
SelectKind9Animation::  ; animation pointers of enemy kind 9 by hEnemyDir
    ld hl, hObject2
    res 5, [hl]
    ldh a, [hEnemyDir]
    bit 2, a
    jr nz, .L_01_583e
    bit 3, a
    jr nz, .L_01_5847
    bit 0, a
    call nz, SetObjectFlipFlag
    ld de, D_01_587d
    ld bc, D_01_5884
    jp .L_01_584d
.L_01_583e:
    ld de, D_01_588b
    ld bc, D_01_5892
    jp .L_01_584d
.L_01_5847:
    ld de, D_01_586f
    ld bc, D_01_5876
.L_01_584d:
    ldh a, [hEnemyTick]
    and a, $08
    jr z, .L_01_5855
    push bc
    pop de
.L_01_5855:
    jp SetObjectAnimation
SetObjectFlipFlag::  ; sets hObject2 bit 5 (horizontal flip; name provisional)
    ld hl, hObject2
    set 5, [hl]
    ret
EnemyKind9Init::  ; sets the counters and the first animation of enemy kind 9
    ld a, $06
    ldh [hEnemySpeed], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld de, D_01_586f
    call SetObjectAnimation
    jp EnemySnapToGrid
D_01_586f::
    INCBIN "assets/bank_01/586f.bin"
D_01_5876::
    INCBIN "assets/bank_01/5876.bin"
D_01_587d::
    INCBIN "assets/bank_01/587d.bin"
D_01_5884::
    INCBIN "assets/bank_01/5884.bin"
D_01_588b::
    INCBIN "assets/bank_01/588b.bin"
D_01_5892::
    INCBIN "assets/bank_01/5892.bin"
EnemyKind2::  ; enemy kind 2
    call TickObjectTimer
    jr nz, .L_01_58a1
    jp EnemyKind2Init
.L_01_58a1:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyComputeBlockedDirs
    call EnemyGridStep
    call EnemyChooseDirection
    call EnemyTurnOrAnimate
    call EnemyShootIfReady
    call L_01_58ee
    call ProjectileFrame
    call EnemyPaintUnderB0M
    call CheckEnemyTouchesPlayer
    call CheckPaintHitsEnemy
    call SelectKind2Animation
    call SelectObject2
    jp DrawObject
EnemyShootIfReady::  ; counts hEnemyStep down; when it hits 0 and no projectile is live and the enemy is on screen calls SpawnEnemyProjectile
    ld a, [wProjectile]
    bit 7, a
    ret nz
    ld hl, hEnemyStep
    dec [hl]
    ret nz
    ld a, [wProjectile]
    bit 7, a
    ret nz
    ldh a, [hEnemyX]
    ld c, a
    ldh a, [hEnemyY]
    ld b, a
    call EnemyScreenPosition
    and a, a
    ret nz
    jp SpawnEnemyProjectile
L_01_58ee::
    ld a, [wActiveMagic]
    cp a, $03
    jr nz, .L_01_58fc
    ld a, [wMagicState]
    bit 0, a
    jr nz, .L_01_5938
.L_01_58fc:
    ld a, [wActiveMagic]
    cp a, $05
    jr nz, .L_01_590a
    ld a, [wMagicState]
    bit 0, a
    jr nz, .L_01_5938
.L_01_590a:
    ld a, [wProjectile]
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
    ld [wProjectileAnimLo], a
    ld a, h
    ld [wProjectileAnimHi], a
    ld hl, wProjectile
    call SetObjPtr
    jp DrawObject
.L_01_5938:
    ld a, $05
    ldh [hEnemyStep], a
    ld a, $a0
    ld [$c4b4], a
    ld hl, wProjectile
    res 7, [hl]
    ret
SpawnEnemyProjectile::  ; creates the projectile at wProjectile in front of the shooter enemy
    ld hl, wProjectile
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
    ld [wProjectile], a
    ret
SelectKind2Animation::  ; animation pointers of enemy kind 2 by hEnemyDir
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
    ld bc, D_01_59e0
    jr .L_01_59ab
.L_01_5990:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_59d9
    ld bc, D_01_59e0
    jr .L_01_59ab
.L_01_599d:
    ld bc, D_01_59e7
    ld de, D_01_59ee
    jr .L_01_59ab
.L_01_59a5:
    ld bc, D_01_59cb
    ld de, D_01_59d2
.L_01_59ab:
    ldh a, [hEnemyTick]
    and a, $04
    jr z, .L_01_59b3
    push bc
    pop de
.L_01_59b3:
    jp SetObjectAnimationStub
EnemyKind2Init::  ; sets the counters and the first animation of enemy kind 2
    ld a, $05
    ldh [hEnemySpeed], a
    ld a, $20
    ldh [hEnemyCounter], a
    ld a, $05
    ldh [hEnemyStep], a
    ld de, D_01_59cb
    call SetObjectAnimation
    jp EnemySnapToGrid
D_01_59cb::
    INCBIN "assets/bank_01/59cb.bin"
D_01_59d2::
    INCBIN "assets/bank_01/59d2.bin"
D_01_59d9::
    INCBIN "assets/bank_01/59d9.bin"
D_01_59e0::
    INCBIN "assets/bank_01/59e0.bin"
D_01_59e7::
    INCBIN "assets/bank_01/59e7.bin"
D_01_59ee::
    INCBIN "assets/bank_01/59ee.bin"
D_01_59f5::
    INCBIN "assets/bank_01/59f5.bin"
D_01_59fa::
    INCBIN "assets/bank_01/59fa.bin"
EnemyKind3::  ; enemy kind 3
    call SelectObject2
    call TickObjectTimer
    jr nz, .L_01_5a0a
    jp EnemyKind3Init
.L_01_5a0a:
    ldh a, [hEnemyFlags]
    bit 2, a
    jp nz, EnemyDefeated
    call EnemyAimAtPlayer
    call EnemyFlagOnPaintedTile
    call EnemyTurnIfBlocked
    call MoveAndClampObject
    call EnemyPaintUnderB0M
    call CheckEnemyTouchesPlayer
    call SelectKind3Animation
    jp DrawObject
SelectKind3Animation::  ; animation pointers of enemy kind 3 by hEnemyDir
    ldh a, [hEnemyDir]
    bit 0, a
    jr nz, .L_01_5a40
    bit 1, a
    jr nz, .L_01_5a4e
    bit 2, a
    jr nz, .L_01_5a5c
    ld de, D_01_5a76
    ld bc, D_01_5a7d
    jp SetAnimationVariant
.L_01_5a40:
    ld hl, hObject2
    set 5, [hl]
    ld de, D_01_5a84
    ld bc, D_01_5a8b
    jp SetAnimationVariant
.L_01_5a4e:
    ld hl, hObject2
    res 5, [hl]
    ld de, D_01_5a84
    ld bc, D_01_5a8b
    jp SetAnimationVariant
.L_01_5a5c:
    ld de, D_01_5a92
    ld bc, D_01_5a99
    jp SetAnimationVariant
EnemyKind3Init::  ; sets the counters and the first animation of enemy kind 3
    ld de, D_01_5a76
    call SetObjectAnimation
    ld a, $05
    ldh [hEnemySpeed], a
    ld a, $20
    ldh [hEnemyCounter], a
    jp EnemySnapToGrid
D_01_5a76::
    INCBIN "assets/bank_01/5a76.bin"
D_01_5a7d::
    INCBIN "assets/bank_01/5a7d.bin"
D_01_5a84::
    INCBIN "assets/bank_01/5a84.bin"
D_01_5a8b::
    INCBIN "assets/bank_01/5a8b.bin"
D_01_5a92::
    INCBIN "assets/bank_01/5a92.bin"
D_01_5a99::
    INCBIN "assets/bank_01/5a99.bin"
Sound8DEffectData::  ; stream of sound id $8d
    INCBIN "assets/bank_01/5c48_Sound8DEffectData.bin"
Sound8EEffectData::  ; stream of sound id $8e
    INCBIN "assets/bank_01/5c5c_Sound8EEffectData.bin"
Sound8FEffectData::  ; stream of sound id $8f
    INCBIN "assets/bank_01/5c70_Sound8FEffectData.bin"
Sound90EffectData::  ; stream of sound id $90
    INCBIN "assets/bank_01/5c80_Sound90EffectData.bin"
Sound91EffectData::  ; stream of sound id $91
    INCBIN "assets/bank_01/5c93_Sound91EffectData.bin"
Sound92EffectData::  ; stream of sound id $92
    INCBIN "assets/bank_01/5ca7_Sound92EffectData.bin"
Sound93EffectData::  ; stream of sound id $93
    INCBIN "assets/bank_01/5cba_Sound93EffectData.bin"
UnusedSoundData0::  ; bytes after the last effect stream ($93 ends at $5cc9); never read in play tests
    INCBIN "assets/bank_01/5cca_UnusedSoundData0.bin"
Sound81MusicData::  ; stream of sound id $81
    INCBIN "assets/bank_01/5e72_Sound81MusicData.bin"
UnusedSoundData1::  ; bytes after the title song ($81 reads $5e72-$5ef2 only); never read in play tests
    INCBIN "assets/bank_01/5ef3_UnusedSoundData1.bin"
Sound82EffectData::  ; stream of sound id $82
    INCBIN "assets/bank_01/609b_Sound82EffectData.bin"
UnusedSoundData2::  ; bytes after song $82
    INCBIN "assets/bank_01/60ec_UnusedSoundData2.bin"
Sound83EffectData::  ; stream of sound id $83
    INCBIN "assets/bank_01/6294_Sound83EffectData.bin"
UnusedSoundData3::  ; bytes after song $83
    INCBIN "assets/bank_01/62ea_UnusedSoundData3.bin"
Sound84MusicData::  ; stream of sound id $84
    INCBIN "assets/bank_01/6492_Sound84MusicData.bin"
UnusedSoundData4::  ; bytes after song $84
    INCBIN "assets/bank_01/65b5_UnusedSoundData4.bin"
Sound85MusicData::  ; stream of sound id $85
    INCBIN "assets/bank_01/675d_Sound85MusicData.bin"
UnusedSoundData5::  ; bytes after song $85
    INCBIN "assets/bank_01/6a35_UnusedSoundData5.bin"
Sound86MusicData::  ; stream of sound id $86
    INCBIN "assets/bank_01/6bdd_Sound86MusicData.bin"
UnusedSoundData6::  ; bytes after song $86
    INCBIN "assets/bank_01/6f03_UnusedSoundData6.bin"
Sound87MusicData::  ; stream of sound id $87
    INCBIN "assets/bank_01/70ab_Sound87MusicData.bin"
UnusedSoundData7::  ; bytes after song $87
    INCBIN "assets/bank_01/7289_UnusedSoundData7.bin"
Sound88MusicData::  ; stream of sound id $88
    INCBIN "assets/bank_01/7431_Sound88MusicData.bin"
UnusedSoundData8::  ; bytes after song $88
    INCBIN "assets/bank_01/76f2_UnusedSoundData8.bin"
Sound89MusicData::  ; stream of sound id $89
    INCBIN "assets/bank_01/789a_Sound89MusicData.bin"
UnusedSoundData9::  ; bytes after song $89
    INCBIN "assets/bank_01/79ad_UnusedSoundData9.bin"
Sound8AMusicData::  ; stream of sound id $8a
    INCBIN "assets/bank_01/7b55_Sound8AMusicData.bin"
UnusedSoundDataA::  ; bytes after song $8a
    INCBIN "assets/bank_01/7bad_UnusedSoundDataA.bin"
Sound8BMusicData::  ; stream of sound id $8b
    INCBIN "assets/bank_01/7d55_Sound8BMusicData.bin"
UnusedSoundDataB::  ; bytes after song $8b
    INCBIN "assets/bank_01/7dad_UnusedSoundDataB.bin"
D_01_7f55::
    INCBIN "assets/bank_01/7f55.bin"

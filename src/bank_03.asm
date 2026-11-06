INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank03", ROMX[$4000], BANK[3]

TilesTitle::  ; title logo; font; copyright text (loaded by LoadTilesBank3A)
    INCBIN "assets/bank_03/4000_TilesTitle.bin"
TilesIcons::  ; UI icons; round/status tiles (LoadTilesBank3B)
    INCBIN "assets/bank_03/5000_TilesIcons.bin"
TilesEnding::  ; castle and trees: ending scene tiles (LoadTilesBank3C)
    INCBIN "assets/bank_03/6000_TilesEnding.bin"
TilesFont2::  ; second font and misc tiles (LoadTilesBank3D)
    INCBIN "assets/bank_03/6e10_TilesFont2.bin"
Bank3Padding::  ; $ff padding to the end of the bank
    INCBIN "assets/bank_03/7e10_Bank3Padding.bin"

INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank03", ROMX[$4000], BANK[3]

TilesTitle::  ; title logo; font; copyright text (loaded by LoadTilesBank3A)
    INCBIN "orig/painter_momopie.gb", $0c000, 4096
TilesIcons::  ; UI icons; round/status tiles (LoadTilesBank3B)
    INCBIN "orig/painter_momopie.gb", $0d000, 4096
TilesEnding::  ; castle and trees: ending scene tiles (LoadTilesBank3C)
    INCBIN "orig/painter_momopie.gb", $0e000, 3600
TilesFont2::  ; second font and misc tiles (LoadTilesBank3D)
    INCBIN "orig/painter_momopie.gb", $0ee10, 4096
Bank3Padding::  ; $ff padding to the end of the bank
    INCBIN "orig/painter_momopie.gb", $0fe10, 496

INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank02", ROMX[$4000], BANK[2]

SpriteTiles::  ; 2bpp sprite tiles (characters and enemies): first $700 bytes are copied to VRAM $8000
    INCBIN "orig/painter_momopie.gb", $08000, 1792
SpriteSet0::  ; $900 bytes of sprite tiles copied to $8700 (cook enemies and kitchen props); room indices 0-2
    INCBIN "orig/painter_momopie.gb", $08700, 2304
SpriteSet1::  ; $900 bytes of sprite tiles copied to $8700 (skull/ghost enemies); used for room indices 12-14 and 16
    INCBIN "orig/painter_momopie.gb", $09000, 2304
SpriteSet2::  ; $900 bytes of sprite tiles (knight and ghost enemies); room indices 8-10
    INCBIN "orig/painter_momopie.gb", $09900, 2304
SpriteSet3::  ; $900 bytes of sprite tiles (cook enemies); room indices 3-6 and 11
    INCBIN "orig/painter_momopie.gb", $0a200, 2304
SpriteSet4::  ; $900 bytes of sprite tiles (blob enemies and a puff of smoke); room indices 7 and 15
    INCBIN "orig/painter_momopie.gb", $0ab00, 2304
Bank2Padding::  ; $ff padding to the end of the bank
    INCBIN "orig/painter_momopie.gb", $0b400, 3072

INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank02", ROMX[$4000], BANK[2]

SpriteTiles::  ; 2bpp sprite tiles (characters and enemies): first $700 bytes are copied to VRAM $8000
    INCBIN "orig/painter_momopie.gb", $08000, 1792
SpriteTilesPart2::  ; more sprite tiles; $900 bytes at an offset chosen from wRoomIndex are copied to $8700
    INCBIN "orig/painter_momopie.gb", $08700, 11520
Bank2Padding::  ; $ff padding to the end of the bank
    INCBIN "orig/painter_momopie.gb", $0b400, 3072

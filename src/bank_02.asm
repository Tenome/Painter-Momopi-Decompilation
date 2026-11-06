INCLUDE "src/hardware.inc"
INCLUDE "src/constants.inc"

SECTION "bank02", ROMX[$4000], BANK[2]

SpriteTiles::  ; 2bpp sprite tiles (characters and enemies): first $700 bytes are copied to VRAM $8000
    INCBIN "assets/bank_02/4000_SpriteTiles.bin"
SpriteSet0::  ; $900 bytes of sprite tiles copied to $8700 (cook enemies and kitchen props); room indices 0-2
    INCBIN "assets/bank_02/4700_SpriteSet0.bin"
SpriteSet1::  ; $900 bytes of sprite tiles copied to $8700 (skull/ghost enemies); used for room indices 12-14 and 16
    INCBIN "assets/bank_02/5000_SpriteSet1.bin"
SpriteSet2::  ; $900 bytes of sprite tiles (knight and ghost enemies); room indices 8-10
    INCBIN "assets/bank_02/5900_SpriteSet2.bin"
SpriteSet3::  ; $900 bytes of sprite tiles (cook enemies); room indices 3-6 and 11
    INCBIN "assets/bank_02/6200_SpriteSet3.bin"
SpriteSet4::  ; $900 bytes of sprite tiles (blob enemies and a puff of smoke); room indices 7 and 15
    INCBIN "assets/bank_02/6b00_SpriteSet4.bin"
Bank2Padding::  ; $ff padding to the end of the bank
    INCBIN "assets/bank_02/7400_Bank2Padding.bin"

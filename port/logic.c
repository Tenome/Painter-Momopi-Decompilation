/* Hand written C versions of game routines (replacing the generated code for the labels listed in port/overrides.txt).
 * Each one keeps the register and flag results of the original routine so that its callers behave the same; the generated code and these
 * versions are compared with `python tools/verify_all.py` (frame hashes of random play) before a routine is added here. */
#include "gb_rt.h"

/* LookupByte: A = byte at HL + C (table lookup). */
void *gb_native_LookupByte(void) {
    r.b = 0;
    add_hl(BC());
    r.a = rd(HL());
    return 0;
}

/* LookupWord: HL = word at HL + A*2; the word is also copied to DE and BC; A ends as its high byte. */
void *gb_native_LookupWord(void) {
    int carry = r.a >> 7;
    r.a <<= 1;
    r.f = (r.a ? 0 : 0x80) | (carry ? 0x10 : 0);     /* sla a */
    r.c = r.a;
    r.b = 0;
    add_hl(BC());
    uint16_t at = HL();
    r.e = rd(at);
    r.d = rd((uint16_t)(at + 1));
    r.a = r.d;
    SET_HL(DE());
    SET_BC(DE());
    return 0;
}

/* ClearMemory: zero fill HL for BC bytes (BC = 0 fills 65536 bytes, the loop tests after the first byte). */
void *gb_native_ClearMemory(void) {
    uint16_t at = HL(), left = BC();
    do { wr(at++, 0); } while (--left);
    SET_HL(at);
    SET_BC(0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* FillBackwardsFF: fills $400 bytes with $ff going down from HL. */
void *gb_native_FillBackwardsFF(void) {
    uint16_t at = HL();
    for (int n = 0; n < 0x400; n++) wr(at--, 0xFF);
    SET_HL(at);
    SET_BC(0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* CopyMemory: copy BC bytes from HL to DE (BC = 0 copies 65536 bytes). */
void *gb_native_CopyMemory(void) {
    uint16_t from = HL(), to = DE(), left = BC();
    do { wr(to++, rd(from++)); } while (--left);
    SET_HL(from);
    SET_DE(to);
    SET_BC(0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* Clear32Bytes: zero fill HL for 32 bytes. */
void *gb_native_Clear32Bytes(void) {
    uint16_t at = HL();
    for (int n = 0; n < 32; n++) wr(at++, 0);
    SET_HL(at);
    r.b = 0;
    r.a = 0;
    r.f = 0xC0;
    return 0;
}

#define wRoomMap 0xC0A7

/* PixelXToColumn: E = (X + 8) / 16 - 1 (A is the pixel X); A ends equal to E. */
void *gb_native_PixelXToColumn(void) {
    uint8_t column = (uint8_t)(((uint8_t)(r.a + 8) & 0xF0) >> 4);
    r.a = column;
    alu_sub(1, 0);
    r.e = r.a;
    return 0;
}

/* LookupMapTile: A = room map tile at pixel Y (A) with column E; the map has 16 cells per row and rows start at pixel Y $18. */
void *gb_native_LookupMapTile(void) {
    uint8_t save_b = r.b, save_c = r.c;
    alu_sub(0x18, 0);
    alu_add(r.e, 0);
    SET_HL(wRoomMap);
    r.c = r.a;
    gb_native_LookupByte();
    r.b = save_b;
    r.c = save_c;
    return 0;
}

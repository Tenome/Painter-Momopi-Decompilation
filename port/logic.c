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

#define hScratch00 0xFF96
#define hScratch01 0xFF97
#define hEnemyBlocked 0xFFC7
#define hEnemyX 0xFFBC
#define hEnemyY 0xFFBF
#define wCameraX 0xC1AC
#define wCameraY 0xC1AE

/* EnemyEdgeBlockedDirs: hEnemyBlocked = the directions the screen edges forbid (bit 0 right, 1 left, 2 up, 3 down; limits X $20-$ef, Y $28-$f7). */
void *gb_native_EnemyEdgeBlockedDirs(void) {
    uint8_t x = rd(hEnemyX), y = rd(hEnemyY), blocked = 0;
    if (x < 0x21) blocked = 0x02;
    if (x >= 0xF0) blocked |= 0x01;
    if (y < 0x29) blocked |= 0x04;
    if (y < 0xF8) {            /* the original returns with the flags of this compare and A = Y */
        wr(hEnemyBlocked, blocked);
        r.a = y;
        alu_cp(0xF8);
        return 0;
    }
    blocked |= 0x08;
    wr(hEnemyBlocked, blocked);
    r.a = blocked;
    r.f = 0;                   /* result of `or a, $08` is never zero */
    return 0;
}

/* EnemyScreenPosition: C = X and B = Y of an enemy (world pixels). Writes the position relative to the camera to hScratch00 (X) and hScratch01 (Y);
 * A = 0 when it is inside the visible area (X $08-$a7, Y $10-$a7), else 1. HL is preserved. */
void *gb_native_EnemyScreenPosition(void) {
    uint8_t sx = (uint8_t)(r.c - rd(wCameraX)), sy = (uint8_t)(r.b - rd(wCameraY));
    wr(hScratch00, sx);
    wr(hScratch01, sy);
    r.a = sx; alu_cp(0xA8);
    if (!CF()) { r.a = 1; return 0; }
    r.a = sx; alu_cp(0x08);
    if (CF()) { r.a = 1; return 0; }
    r.a = sy; alu_cp(0xA8);
    if (!CF()) { r.a = 1; return 0; }
    r.a = sy; alu_cp(0x10);
    if (CF()) { r.a = 1; return 0; }
    r.a = 0;
    r.f = 0x80;
    return 0;
}

#define hOamCount 0xFFD9
#define hObjPtrLo 0xFFD5
#define hObjPtrHi 0xFFD6
#define hObject2  0xFFB5

/* SetObjPtr: hObjPtr = HL (the object record the next routines work on); A ends as L. */
void *gb_native_SetObjPtr(void) {
    wr(hObjPtrHi, r.h);
    wr(hObjPtrLo, r.l);
    r.a = r.l;
    return 0;
}

/* SelectObject2: hObjPtr = hObject2 (the enemy record held in high RAM); HL = $ffb5. */
void *gb_native_SelectObject2(void) {
    SET_HL(hObject2);
    wr(hObjPtrLo, r.l);
    wr(hObjPtrHi, 0xFF);
    r.a = 0xFF;
    return 0;
}

/* AddOamSprite: appends one sprite (Y hScratch0B, X hScratch0A, tile hScratch0C, attributes hScratch0D) to the OAM shadow at $c000;
 * the 40 entry slot counter hOamCount wraps back to 0 after slot 38. */
void *gb_native_AddOamSprite(void) {
    uint8_t slot = rd(hOamCount);
    if (slot >= 0x27) slot = 0;
    uint16_t at = 0xC000 + slot * 4;
    wr(at, rd(0xFFA1));
    wr(at + 1, rd(0xFFA0));
    wr(at + 2, rd(0xFFA2));
    wr(at + 3, rd(0xFFA3));
    wr(hOamCount, slot + 1);
    SET_HL(at + 3);
    r.b = 0;
    r.c = slot * 4;
    r.a = slot + 1;
    r.f = (slot & 15) == 15 ? 0x20 : 0;      /* flags of `inc a` (the carry was cleared by the shifts) */
    return 0;
}

/* MultiplyByDE: signed multiply of A by the low byte of E, shifted left like the original (D starts at 0, DE doubles every step).
 * Result in hScratch00 (low) and hScratch01 (high); HL holds the magnitude; D and E end as E shifted into D. */
void *gb_native_MultiplyByDE(void) {
    uint8_t a0 = r.a, f0 = r.f;
    uint8_t m = (a0 & 0x80) ? (uint8_t)(~a0 + 1) : a0;
    uint16_t hl = 0, de = r.e;
    for (int i = 0; i < 8; i++) {
        if (m & 1) hl += de;
        m >>= 1;
        de <<= 1;
    }
    SET_HL(hl);
    SET_DE(de);
    r.c = 0;
    r.a = a0;
    r.f = (f0 & 0x10) | 0x20 | ((a0 & 0x80) ? 0 : 0x80);        /* pop af, then bit 7, a */
    if (!(a0 & 0x80)) {
        wr(hScratch01, r.h);
        wr(hScratch00, r.l);
        r.a = r.l;
        return 0;
    }
    r.a = 0; alu_sub(r.l, 0);
    wr(hScratch00, r.a);
    r.a = 0; alu_sub(r.h, CF() ? 1 : 0);
    wr(hScratch01, r.a);
    return 0;
}

/* ByteToBCD: A (plus 256 when C is not 0) to decimal. hScratch02 = the two low digits as BCD (tens in the high nibble),
 * hScratch03 = the hundreds (carry count); hScratch00 ends as the last remainder; A and the flags are those of the final addition. */
void *gb_native_ByteToBCD(void) {
    uint8_t ones = r.a, digits = 0, hundreds = 0;
    wr(0xFF97, r.c);
    if (r.c) {
        ones += 0x38;
        hundreds += 2;
    }
    wr(0xFF96, ones);
    while (ones >= 0x0A) {
        ones -= 0x0A;
        r.a = digits;
        alu_add(0x10, 0);
        op_daa();
        digits = r.a;
        hundreds += CF() ? 1 : 0;
    }
    r.a = digits;
    alu_add(ones, 0);
    wr(0xFF96, ones);
    wr(0xFF98, r.a);
    wr(0xFF99, hundreds);
    return 0;
}

/* IsOnTileGrid: B = X and C = Y; Z set when X is a multiple of 16 and Y is 8 more than one. A ends as the compared Y remainder. */
void *gb_native_IsOnTileGrid(void) {
    r.a = r.b;
    alu_and(0x0F);
    if (r.a) return 0;                  /* NZ: X is off the grid (flags of the AND) */
    r.a = r.c;
    alu_and(0x0F);
    alu_cp(0x08);
    return 0;
}

/* EnemyOnTileGrid: Z when the enemy is aligned to the grid; B = hEnemyX and C = hEnemyY on return. */
void *gb_native_EnemyOnTileGrid(void) {
    r.b = rd(hEnemyX);
    r.c = rd(hEnemyY);
    return gb_native_IsOnTileGrid();
}

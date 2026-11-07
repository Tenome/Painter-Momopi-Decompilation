/* Hand written C versions of game routines (replacing the generated code for the labels listed in port/overrides.txt).
 * Most keep the register and flag results of the original routine so that its callers behave the same (the ones that do not say so in their comment); the generated code and these
 * versions are compared with `python tools/lift_check.py` (frame hashes of random play) before a routine is added here. */
#include "gb_rt.h"
#include "game_symbols.h"      /* generated: wPlayerX, hEnemyKind ... (from src/constants.inc) */
#include "game_labels.h"       /* generated: GAME_<Label> = the generated routine of a label */

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

/* MoveObject: the object record at hObjPtr moves by its heading (+$10, 0-31) and speed (+$11): the vector from MoveVectorTable (pairs dx dy) is
 * multiplied by the speed; the 16 bit results are stored as the horizontal step at +$0c/+$0d and the vertical step at +$0e/+$0f. */
void *gb_native_MoveObject(void) {
    uint16_t obj = rd(0xFFD5) | rd(0xFFD6) << 8;
    uint8_t speed = rd(obj + 0x11), heading = rd(obj + 0x10);
    uint8_t d0 = r.d;
    uint16_t vec = 0x0BB6 + (uint8_t)(heading << 1);
    int8_t dx = (int8_t)rd(vec), dy = (int8_t)rd(vec + 1);

    r.e = speed;                       /* vertical step */
    r.a = (uint8_t)dy;
    r.f = 0;
    gb_native_MultiplyByDE();
    wr(obj + 0x0E, rd(hScratch00));
    wr(obj + 0x0F, rd(hScratch01));

    r.d = d0;                          /* horizontal step (the original pops DE and the flags it pushed) */
    r.e = speed;
    r.a = (uint8_t)dx;
    r.f = 0;
    gb_native_MultiplyByDE();
    r.b = 0;
    r.c = 0x0C;
    SET_HL(obj);
    add_hl(BC());
    wr(HL(), rd(hScratch00));
    SET_HL(HL() + 1);
    r.a = rd(hScratch01);
    wr(HL(), r.a);
    return 0;
}

/* ApplyObjectStep: adds the movement step of the object record at hObjPtr to its fixed point position.
 * X: fraction +6, pixel +7/+8 gets step +$0c/+$0d; Y: fraction +9, pixel +$a/+$b gets step +$0e/+$0f. The pixel part is a 16 bit value and the step
 * is a signed 8.8 number (its high byte is sign extended). The hScratch variables are left as the original leaves them; the registers are not kept. */
void *gb_native_ApplyObjectStep(void) {
    uint16_t obj = rd(0xFFD5) | rd(0xFFD6) << 8;
    uint8_t last_step_hi = 0;
    for (int axis = 0; axis < 2; axis++) {
        uint16_t pos = obj + 6 + 3 * axis, step = obj + 0x0C + 2 * axis;
        unsigned frac = rd(pos) + rd(step);
        wr(pos, frac);
        unsigned lo = rd(pos + 1) + rd(step + 1) + (frac >> 8);
        wr(pos + 1, lo);
        uint8_t step_hi = rd(step + 1);
        unsigned hi = rd(pos + 2) + (step_hi & 0x80 ? 0xFF : 0) + (lo >> 8);
        wr(pos + 2, hi);
        last_step_hi = step_hi;
    }
    wr(hScratch00, 0x0C);
    wr(hScratch01, 0x10);
    wr(0xFF98, last_step_hi);
    return 0;
}


/* CompareObjectCoordinate: E = offset of a coordinate byte. Takes |obj[E] - other[E]| (the object at hObjPtr against the one at hOtherObj) and compares it with
 * the sum of the two box sizes taken from the table at $0a3f (indexes hScratch02 and hScratch03). Carry set = closer than the sum (the boxes touch on this axis).
 * hScratch04 = the distance and hScratch06 = the sum afterwards. Registers other than A and the flags are not kept. */
void *gb_native_CompareObjectCoordinate(void) {
    uint16_t a = rd(hObjPtrLo) | rd(hObjPtrHi) << 8, b = rd(hOtherObjLo) | rd(hOtherObjHi) << 8;
    uint8_t dist = (uint8_t)(rd(a + r.e) - rd(b + r.e));
    if (rd(a + r.e) < rd(b + r.e)) dist = (uint8_t)(0 - dist);
    wr(0xFF9A, dist);
    uint8_t sum = (uint8_t)(rd(0x0A3F + rd(hScratch00 + 2)) + rd(0x0A3F + rd(hScratch00 + 3)));
    wr(0xFF9C, sum);
    r.a = dist;
    alu_cp(sum);
    return 0;
}

/* ObjectsOverlap: do the boxes of the object at hObjPtr and the one at hOtherObj overlap? A and C = $80 when they do, else 0.
 * Both X and Y must be within the summed box sizes; an object whose X is beyond 255 (high byte not 0) never overlaps. */
void *gb_native_ObjectsOverlap(void) {
    uint16_t other = rd(hOtherObjLo) | rd(hOtherObjHi) << 8;
    wr(hScratch00 + 2, (uint8_t)(rd(0xFFB9) << 1));
    wr(hScratch00 + 3, (uint8_t)(rd(other + 4) << 1));
    if (rd(0xFFBD) == 0 && rd(other + 8) == 0) {
        r.d = 0; r.e = 7;
        gb_native_CompareObjectCoordinate();
        if (CF()) {
            wr(hScratch00 + 2, rd(hScratch00 + 2) + 1);
            wr(hScratch00 + 3, rd(hScratch00 + 3) + 1);
            r.e = 0x0A;
            gb_native_CompareObjectCoordinate();
            if (!CF()) goto no;
            r.a = 0x80;
            r.c = 0x80;
            return 0;
        }
    }
no:
    r.a = 0;
    r.c = 0;
    r.f = 0x80;
    return 0;
}

/* PlayerComputeBlockedDirs: B = X and C = Y of the player. When the player stands on the tile grid, wPlayerBlocked gets a bit for every neighbouring map cell
 * that is a wall (low nibble 0): 4 up, 8 down, 2 left, 1 right. hEnemyBlocked receives the same value each time a bit is set (a side effect of the original).
 * Registers are not kept except for the flags of IsOnTileGrid when the player is off the grid. */
static uint8_t map_tile(uint8_t y, uint8_t column) { return rd(0xC0A7 + (uint8_t)(y - 0x18 + column)); }

void *gb_native_PlayerComputeBlockedDirs(void) {
    wr(wPlayerBlocked, 0);
    gb_native_IsOnTileGrid();
    if (!ZF()) return 0;
    uint8_t x = r.b, y = r.c;
    uint8_t column = (uint8_t)((((uint8_t)(x + 8) & 0xF0) >> 4) - 1);
    uint8_t blocked = 0;
    if ((map_tile(y - 0x10, column) & 0x0F) == 0) { blocked = 0x04; wr(wPlayerBlocked, blocked); wr(hEnemyBlocked, blocked); }
    if ((map_tile(y + 0x10, column) & 0x0F) == 0) { blocked |= 0x08; wr(wPlayerBlocked, blocked); wr(hEnemyBlocked, blocked); }
    if ((map_tile(y, column - 1) & 0x0F) == 0) { blocked |= 0x02; wr(wPlayerBlocked, blocked); wr(hEnemyBlocked, blocked); }
    if ((map_tile(y, column + 1) & 0x0F) == 0) { blocked |= 0x01; wr(wPlayerBlocked, blocked); wr(hEnemyBlocked, blocked); }
    return 0;
}


/* TickObjectTimer: hEnemyTick += 1; Z is set unless bit 7 of the next byte (hEnemyDir) is set; HL = hEnemyDir's address. */
void *gb_native_TickObjectTimer(void) {
    wr(hEnemyTick, rd(hEnemyTick) + 1);
    r.a = rd(hEnemyTick + 1);
    SET_HL(hEnemyTick + 1);
    r.f = (r.f & 0x10) | 0x20 | ((r.a & 0x80) ? 0 : 0x80);
    return 0;
}

/* LoadPlayerXY: B = wPlayerX, C = wPlayerY; HL = the address of wPlayerY. */
void *gb_native_LoadPlayerXY(void) {
    r.b = rd(0xC4C5);
    r.c = rd(0xC4C8);
    SET_HL(0xC4C8);
    return 0;
}

/* GetEnemyPos: C = hEnemyX, B = hEnemyY; HL = the address of hEnemyY. */
void *gb_native_GetEnemyPos(void) {
    r.c = rd(hEnemyX);
    r.b = rd(hEnemyY);
    SET_HL(hEnemyY);
    return 0;
}

/* GetPlayerPos: L = wPlayerX and H = wPlayerY (A = wPlayerY). */
void *gb_native_GetPlayerPos(void) {
    r.l = rd(0xC4C5);
    r.h = rd(0xC4C8);
    r.a = r.h;
    return 0;
}

/* RememberEnemyPosition: copies hEnemyX and hEnemyY to $c525 and $c526 (A ends as Y). */
void *gb_native_RememberEnemyPosition(void) {
    wr(0xC525, rd(hEnemyX));
    r.a = rd(hEnemyY);
    wr(0xC526, r.a);
    return 0;
}

/* DigitToTile: A = tile id of digit A from the table at $1d2f; HL and BC are kept, only Z of the flags survives. */
void *gb_native_DigitToTile(void) {
    r.a = rd(0x1D2F + r.a);
    r.f &= 0x80;
    return 0;
}

/* EnemyTileUnder: A = room map tile under the enemy, with its Y rounded to the grid row (Y and $f0, plus 8). */
void *gb_native_EnemyTileUnder(void) {
    r.a = rd(hEnemyX);
    gb_native_PixelXToColumn();
    r.a = rd(hEnemyY);
    alu_and(0xF0);
    alu_add(0x08, 0);
    return gb_native_LookupMapTile();
}

/* EnemyMapTile: A = room map tile at the enemy position (column from X, row from Y as it is). */
void *gb_native_EnemyMapTile(void) {
    r.a = rd(hEnemyX);
    gb_native_PixelXToColumn();
    r.a = rd(hEnemyY);
    return gb_native_LookupMapTile();
}

/* ProjectileHitTest: hScratch00/01 = X distance (low, high byte) and hScratch02/03 = Y distance between the projectile and the player, as signed 16 bit
 * numbers (high byte $ff = negative). A = 1 on a hit, else 0. A high byte of 1 only counts when the low byte is below 8 (X) or $20 (Y). */
void *gb_native_ProjectileHitTest(void) {
    r.a = rd(hScratch00 + 1);
    alu_cp(0xFF);
    if (ZF()) goto miss;
    alu_cp(0x01);
    if (ZF()) {
        r.a = rd(hScratch00);
        alu_cp(0x08);
        if (!CF()) goto miss;
        r.a = 1;
        return 0;
    }
    r.a = rd(hScratch00 + 3);
    alu_cp(0xFF);
    if (ZF()) goto miss;
    alu_cp(0x01);
    if (ZF()) {
        r.a = rd(hScratch00 + 2);
        alu_cp(0x20);
        if (!CF()) goto miss;
        r.a = 1;
        return 0;
    }
    r.a = 1;
    return 0;
miss:
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* EnemyRequestTurn: sets hEnemyDir bit 6 and stops the enemy (speed and the high bytes of its step are cleared); A = 0, HL = hEnemyDir. */
void *gb_native_EnemyRequestTurn(void) {
    SET_HL(0xFFD1);
    wr(0xFFD1, rd(0xFFD1) | 0x40);
    wr(0xFFC6, 0);
    wr(0xFFC2, 0);
    wr(0xFFC4, 0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* SelectEnemySlot: HL = address of the table of slot pointers, A = slot index. HL ends as the slot address and also goes to hEnemySlotLo/Hi ($ffd7/$ffd8). */
void *gb_native_SelectEnemySlot(void) {
    uint8_t carry = r.a >> 7;
    r.a <<= 1;
    r.f = (r.a ? 0 : 0x80) | (carry ? 0x10 : 0);
    r.c = r.a;
    r.b = 0;
    add_hl(BC());
    uint16_t at = HL();
    uint8_t lo = rd(at), hi = rd(at + 1);
    wr(0xFFD7, lo);
    wr(0xFFD8, hi);
    r.h = hi;
    r.l = lo;
    r.a = lo;
    return 0;
}

/* RemoveEnemy: clears the active bit of the enemy record in hObject2 and decrements the enemy count. */
void *gb_native_RemoveEnemy(void) {
    wr(0xFFB5, rd(0xFFB5) & 0x7F);
    SET_HL(wEnemyCount);
    wr(wEnemyCount, dec8(rd(wEnemyCount)));
    return 0;
}

/* ClampPlayerPosition: keeps the player inside X $20-$f0 and Y $28-$f8. */
void *gb_native_ClampPlayerPosition(void) {
    uint8_t x = rd(wPlayerX), y;
    if (x < 0x21) x = 0x20;
    if (x >= 0xF0) x = 0xF0;
    wr(wPlayerX, x);
    y = rd(wPlayerY);
    if (y < 0x29) y = 0x28;
    wr(wPlayerY, y);
    r.a = y;
    alu_cp(0xF8);
    if (y >= 0xF8) {
        wr(wPlayerY, 0xF8);
        r.a = 0xF8;
    }
    return 0;
}

/* NextRandomDirection: steps the shift register hFrameSpin ($ffdb): shifted left; the new low bit is bit 7 when bit 4 is set,
 * else the complement of bit 7; then adds the result to hRngCounter ($ffda). A = the new hRngCounter, B = the new hFrameSpin. */
void *gb_native_NextRandomDirection(void) {
    uint8_t spin = rd(0xFFDB), bit7 = spin >> 7, bit4 = (spin >> 4) & 1;
    uint8_t next = (uint8_t)(spin << 1);
    int low = bit4 ? bit7 : !bit7;
    next = low ? (next | 1) : (next & 0xFE);
    wr(0xFFDB, next);
    r.b = next;
    r.a = rd(0xFFDA);
    alu_add(next, 0);
    wr(0xFFDA, r.a);
    return 0;
}

/* StoreEnemySlot: copies the 32 byte enemy record in high RAM (hObject2, $ffb5-$ffd4) back to its slot (address in $ffd7/$ffd8). HL ends on the last byte, A = hEnemyFlags. */
void *gb_native_StoreEnemySlot(void) {
    uint16_t slot = rd(0xFFD7) | rd(0xFFD8) << 8;
    for (int i = 0; i < 0x20; i++) wr(slot + i, rd(0xFFB5 + i));
    SET_HL(slot + 0x1F);
    r.a = rd(0xFFD4);
    return 0;
}

/* LoadEnemySlot: copies the enemy slot (address in $ffd7/$ffd8) into the high RAM record hObject2. HL ends on the last byte, A = that byte (hEnemyFlags). */
void *gb_native_LoadEnemySlot(void) {
    uint16_t slot = rd(0xFFD7) | rd(0xFFD8) << 8;
    for (int i = 0; i < 0x20; i++) wr(0xFFB5 + i, rd(slot + i));
    SET_HL(slot + 0x1F);
    r.a = rd(slot + 0x1F);
    return 0;
}


/* DrawObject: turns the object record at hObjPtr into OAM sprites (through AddOamSprite).
 * Record: +0 flags (bit 7 active, bit 1 position is in the world so the camera is subtracted, bit 2 set here when a part was drawn,
 *         bit 3 -> OAM attribute bit 7, bits 4-6 -> OAM attribute bits 4-6 (palette, X flip, Y flip)), +1/+2 animation pointer, +5 part cursor, +7/+8 X, +$a/+$b Y.
 * Animation data: shape id, then one tile id per part. Shape (ObjectShapeTable): part count, then x and y offset (signed bytes) of every part.
 * The parts are drawn starting at the cursor, which moves on by one every frame, so when the OAM overflows different parts drop out each frame.
 * Mirrored objects (X flip or Y flip) are moved 8 pixels and their part offsets are negated. A part is skipped when its position is off the screen
 * (high byte not 0). The scratch variables hScratch00-0D, hOtherObjLo/Hi are left as the original leaves them. */
void *gb_native_DrawObject(void) {
    uint16_t obj = rd(0xFFD5) | rd(0xFFD6) << 8;
    uint8_t flags = rd(obj);
    if (!(flags & 0x80)) return 0;
    int x = rd(obj + 7) | rd(obj + 8) << 8, y = rd(obj + 0x0A) | rd(obj + 0x0B) << 8;
    uint8_t s00 = flags & 0xFB;
    if (s00 & 0x02) {
        x = (x - (rd(0xC1AC) | rd(wCameraXHi) << 8)) & 0xFFFF;
        y = (y - (rd(0xC1AE) | rd(wCameraYHi) << 8)) & 0xFFFF;
    }
    if (s00 & 0x20) x = (x - 8) & 0xFFFF;
    if (s00 & 0x40) y = (y - 8) & 0xFFFF;
    wr(hScratch00, s00);
    wr(hScratch00 + 1, x);  wr(hScratch00 + 2, x >> 8);
    wr(hScratch00 + 3, y);  wr(hScratch00 + 4, y >> 8);
    uint16_t anim = rd(obj + 1) | rd(obj + 2) << 8;
    wr(hScratch00 + 5, anim); wr(hScratch00 + 6, anim >> 8);
    uint8_t cursor = rd(obj + 5);
    uint16_t shape = rd(0x06A4 + 2 * rd(anim)) | rd(0x06A5 + 2 * rd(anim)) << 8;
    wr(hScratch00 + 7, shape); wr(hScratch00 + 8, shape >> 8);
    uint8_t count = rd(shape);
    wr(hScratch00 + 9, count);
    for (int left = count; left > 0; left--) {
        if (cursor >= count) cursor = 0;
        uint8_t part = cursor++;
        int8_t ox = (int8_t)rd(shape + 2 * part + 1);
        if (s00 & 0x20) ox = (int8_t)(0 - ox);
        int sx = (x + ox) & 0xFFFF;
        wr(hScratch00 + 10, (uint8_t)sx);
        if (sx > 255) continue;
        int8_t oy = (int8_t)rd(shape + 2 * part + 2);
        if (s00 & 0x40) oy = (int8_t)(0 - oy);
        int sy = (y + oy) & 0xFFFF;
        wr(hScratch00 + 11, (uint8_t)sy);
        if (sy > 255) continue;
        wr(hScratch00 + 12, rd(anim + 1 + part));
        s00 |= 0x04;
        wr(hScratch00, s00);
        wr(hScratch00 + 13, (uint8_t)(((s00 & 0x08) << 4) | (s00 & 0x70)));
        gb_native_AddOamSprite();
    }
    wr(hOtherObjHi, 0);
    wr(hOtherObjLo, (uint8_t)(cursor - 1));
    wr(obj, s00);
    wr(obj + 5, (uint8_t)(cursor - 1));
    return 0;
}

/* CounterToFrame: A = number of frames in the animation, hScratch06 = mask, hScratch07 = shift count (ends 0), hScratch08 = running counter.
 * frame = (counter & mask) >> shift; when the frame is above the last one (A - 1) the counter is reset to 0.
 * hScratch05 = A - 1. Returns B = C = frame * 2 (a table offset) and A = the last frame number (0 after a reset); HL = hScratch07. */
void *gb_native_CounterToFrame(void) {
    uint8_t last = (uint8_t)(r.a - 1);
    wr(0xFF9B, last);
    uint8_t frame = rd(0xFF9E) & rd(0xFF9C);
    uint8_t shifts = rd(0xFF9D), carry;
    do {
        carry = frame & 1;
        frame >>= 1;
        shifts--;
    } while (shifts);
    wr(0xFF9D, 0);
    r.f = 0xC0 | (carry ? 0x10 : 0);              /* flags of the final `dec [hl]` (the carry is that of the last shift) */
    r.a = last;
    alu_cp(frame);
    if (last < frame) {
        r.a = 0;
        wr(0xFF9E, 0);
    }
    r.f = ((uint8_t)(frame << 1) ? 0 : 0x80) | ((frame & 0x80) ? 0x10 : 0);     /* flags of `sla b` */
    r.b = (uint8_t)(frame << 1);
    r.c = r.b;
    SET_HL(0xFF9D);
    return 0;
}

/* PlayerCheckOffPath: when the player stands exactly on a grid cell whose map cell is not a path (low nibble 0) wPlayerDir bit 5 (death) is set. */
void *gb_native_PlayerCheckOffPath(void) {
    r.b = rd(wPlayerX);
    r.c = rd(wPlayerY);
    gb_native_IsOnTileGrid();
    if (!ZF()) return 0;
    r.a = rd(wPlayerX);
    gb_native_PixelXToColumn();
    r.a = rd(wPlayerY);
    gb_native_LookupMapTile();
    alu_and(0x0F);
    if (!ZF()) return 0;
    SET_HL(wPlayerDir);
    wr(wPlayerDir, rd(wPlayerDir) | 0x20);
    return 0;
}

fn_t gb_dispatch(uint16_t addr);

/* UpdateEnemy: one step of the enemy record held in hObject2. While hEnemyDir bit 4 is set the enemy only blinks: it is drawn on the frames where the global
 * tick $ffde has bit 2 set, hEnemyCounter counts down and when it goes below zero the bit is cleared. Otherwise the routine of the enemy's kind (hEnemyKind,
 * EnemyBehaviorTable at $3782) runs (as a tail jump). */
void *gb_native_UpdateEnemy(void) {
    uint8_t dir = rd(0xFFD1);
    if (dir & 0x10) {
        r.a = rd(0xFFDE);
        r.f = (r.f & 0x10) | 0x20 | ((r.a & 4) ? 0 : 0x80);       /* bit 2, a */
        if (!(r.a & 4)) return 0;
        SET_HL(0xFFB5);
        wr(0xFFD5, 0xB5);
        wr(0xFFD6, 0xFF);
        gb_native_DrawObject();
        r.a = rd(0xFFC9);
        alu_sub(1, 0);
        wr(0xFFC9, r.a);
        r.f = (r.f & 0x10) | 0x20 | ((r.a & 0x80) ? 0 : 0x80);   /* bit 7, a */
        if (!(r.a & 0x80)) return 0;
        SET_HL(0xFFD1);
        wr(0xFFD1, rd(0xFFD1) & 0xEF);
        r.a = 0;
        r.f = 0x80;
        wr(0xFFC9, 0);
        return 0;
    }
    r.a = rd(0xFFD2);
    uint8_t carry = r.a >> 7;
    r.a <<= 1;
    r.f = (r.a ? 0 : 0x80) | (carry ? 0x10 : 0);
    r.c = r.a;
    r.b = 0;
    SET_HL(0x3782);
    add_hl(BC());
    uint16_t entry = HL();
    r.e = rd(entry);
    r.d = rd(entry + 1);
    r.a = r.d;
    SET_HL(DE());
    return (void *)gb_dispatch(HL());
}

/* UpdateEnemyLoop: runs every active enemy slot once. The slots are visited from index wEnemyLoopIdx (15) down to 0, offset by wEnemyLoopStart (which rises by one
 * every frame, so the order in which enemies update rotates). Each active slot (bit 7 of its first byte) is copied into hObject2, updated and copied back. */
void *gb_native_UpdateEnemyLoop(void) {
    const uint16_t idx = 0xC53E, start = 0xC53F;
    do {
        r.a = (uint8_t)((rd(idx) + rd(start)) & 0x0F);
        SET_HL(0x37AF);                          /* EnemySlotTable */
        gb_native_SelectEnemySlot();
        if (rd(HL()) & 0x80) {
            gb_native_LoadEnemySlot();
            r.sp -= 2;                           /* like `call UpdateEnemy`: the routine, or its tail jump, ends with a return */
            void *next = gb_native_UpdateEnemy();
            if (next) gb_run((fn_t)next); else r.sp += 2;
            gb_native_StoreEnemySlot();
        }
        wr(idx, (uint8_t)(rd(idx) - 1));
    } while (!(rd(idx) & 0x80));
    return 0;
}

/* UpdateAllEnemies: advances the rotation (wEnemyLoopStart + 1), sets the loop index to 15 and runs UpdateEnemyLoop. */
void *gb_native_UpdateAllEnemies(void) {
    wr(0xC53F, rd(0xC53F) + 1);
    wr(0xC53E, 0x0F);
    return gb_native_UpdateEnemyLoop();
}

/* PlayFrame: one frame of play mode (Mode1_Play calls it every frame). Order of the original: round cleared and link game checks, player death,
 * the A button / the running card effect (PlayerAction), wall check and blocked directions (skipped while card 2, W.IN, runs: it lets the player walk through walls), direction
 * and position handling, painting the floor, animation selection, the enemy projectile, then the player is drawn (while a card effect runs the
 * player is only drawn every other frame). */
void *gb_native_PlayFrame(void) {
    if (rd(wGameFlags) & 0x01) return (void *)GAME_RoundCleared;
    uint8_t link = rd(hSerialByte);
    if ((link & 0x04) && ((link & 0x80) || (link & 0x08))) return (void *)GAME_GotoLinkLose;
    if (rd(wPlayerDir) & 0x20) return (void *)GAME_PlayerDeath;
    CALL(GAME_PlayerAction);
    if (!(rd(wActiveMagic) == 0x02 && (rd(wMagicState) & 0x01))) {
        gb_native_PlayerCheckOffPath();
        gb_native_LoadPlayerXY();
        gb_native_PlayerComputeBlockedDirs();
    }
    CALL(GAME_HoldDirectionUntilAligned);
    CALL(GAME_PlayerSetDirection);
    gb_native_ClampPlayerPosition();
    CALL(GAME_PaintUnderPlayer);
    CALL(GAME_SelectPlayerAnimation);
    CALL(GAME_ProjectileFrame);
    if (rd(wActiveMagic) != 0 && (rd(wMagicState) & 0x01)) {
        wr(0xC4D3, rd(0xC4D3) + 1);
        if (!(rd(0xC4D3) & 0x02)) return 0;
    }
    CALL(GAME_AnimatePlayerWalk);
    SET_HL(wPlayer);
    gb_native_SetObjPtr();
    gb_native_DrawObject();
    return 0;
}

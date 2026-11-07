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

/* The behaviour routines of the enemy kinds are chains of the same steps (the record of the enemy is in hObject2):
 * ticking its timer (TickObjectTimer: Z while the enemy is just spawning, when it only plays its first animation), being hit by paint (EnemyDefeated),
 * the blocked directions, the grid step, direction choice, painting the floor (EnemyPaintStep, and with the B.O.M card), touching the player, being hit,
 * the animation, drawing. */

/* EnemyKindIdle: kinds 0, 6 and 8: stationary enemies (kind 0 = the armoured guards standing in the corridor rooms 13-15 and 29-31). */
void *gb_native_EnemyKindIdle(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyInitMoveAnim;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyComputeBlockedDirs);
    CALL(GAME_EnemyGridStep);
    CALL(GAME_EnemyChooseDirection);
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_EnemyPaintStep);
    CALL(GAME_EnemyPaintUnderB0M);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_CheckPaintHitsEnemy);
    CALL(GAME_EnemySelectAnimByKind);
    gb_native_SelectObject2();
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind1: an enemy that walks on the tile grid, turning at walls and the screen edges; while hEnemyFlags bit 1 is set the rest of its update only runs
 * every eighth tick of hEnemyCounter (provisional reading). */
void *gb_native_EnemyKind1(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyInitAnim3bbe;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyComputeBlockedDirs);
    CALL(GAME_EnemyGridStep);
    gb_native_EnemyEdgeBlockedDirs();
    CALL(GAME_EnemyChooseDirection);
    CALL(GAME_EnemyFlagOnPaintedTile);
    if (rd(hEnemyFlags) & 0x02) {
        wr(hEnemyCounter, rd(hEnemyCounter) + 1);
        if (!(rd(hEnemyCounter) & 0x08)) return 0;
    }
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_EnemyPaintStep);
    CALL(GAME_EnemyPaintUnderB0M);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_CheckPaintHitsEnemy);
    CALL(GAME_SetEnemyAnimation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind2: an enemy that shoots (EnemyShooterAI decides, ProjectileFrame moves the shot). */
void *gb_native_EnemyKind2(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind2Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyComputeBlockedDirs);
    CALL(GAME_EnemyGridStep);
    CALL(GAME_EnemyChooseDirection);
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_EnemyShootIfReady);
    CALL(GAME_EnemyShooterAI);
    CALL(GAME_ProjectileFrame);
    CALL(GAME_EnemyPaintUnderB0M);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_CheckPaintHitsEnemy);
    CALL(GAME_SelectKind2Animation);
    gb_native_SelectObject2();
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind3: an enemy that flies straight at the player (EnemyAimAtPlayer), not bound to the grid. */
void *gb_native_EnemyKind3(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind3Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyAimAtPlayer);
    CALL(GAME_EnemyFlagOnPaintedTile);
    CALL(GAME_EnemyTurnIfBlocked);
    CALL(GAME_MoveAndApplyObject);
    CALL(GAME_EnemyPaintUnderB0M);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_SelectKind3Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind4: aims at the player and turns; it cannot be hurt by paint (no defeat check). */
void *gb_native_EnemyKind4(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind4Init;
    CALL(GAME_EnemyAimAtPlayer);
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_SelectKind4Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind5: a teleporting enemy (EnemyKind7Teleport moves it along its position table). It does not touch the player while the SEALED card (6) runs. */
void *gb_native_EnemyKind5(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyBuildTeleportTable;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    if (!(rd(wActiveMagic) == 0x06 && (rd(wMagicState) & 0x01))) CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_CheckPaintHitsEnemy);
    CALL(GAME_EnemyIdleAnimate);
    CALL(GAME_EnemyKind7Teleport);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind7 (rounds 5-7 and 21-23): follows a scripted path (EnemyKind7NextStep reads the path table at wEnemyPathPtr). */
void *gb_native_EnemyKind7(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind7Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyKind7NextStep);
    CALL(GAME_MoveAndApplyObject);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_CheckPaintHitsEnemy);
    CALL(GAME_EnemyKind7Update);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind9: aims at the player like kind 3 but is bound by the blocked directions of the grid. */
void *gb_native_EnemyKind9(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind9Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyComputeBlockedDirs);
    CALL(GAME_EnemyAimAtPlayer);
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_EnemyPaintUnderB0M);
    CALL(GAME_CheckEnemyTouchesPlayer);
    CALL(GAME_SelectKind9Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind10 (rounds 14 and 30): the enemy that fires a projectile object (InitProjectile at first; the projectile is updated and drawn here). */
void *gb_native_EnemyKind10(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_InitProjectile;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    CALL(GAME_EnemyTurnOrAnimate);
    CALL(GAME_EnemyKind10Move);
    CALL(GAME_UpdateProjectile);
    CALL(GAME_ProjectileCheckPlayerHit);
    CALL(GAME_ProjectileRemoveIfHit);
    CALL(GAME_ProjectileSelectFrame);
    gb_native_SelectObject2();
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind11 (rounds 5 6 9 11 and the same +16): an enemy that sits in a map cell; it hides the cell's tile (EnemyClearTileSaveStep keeps the tile it replaced in
 * hEnemyAux) and writes the tile back when it is hit, when its timer (hEnemyTimer) runs out, or while the GHOST or SEALED card runs. */
void *gb_native_EnemyKind11(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind7Start;
    if (rd(hEnemyFlags) & 0x04) {
        uint8_t dir = rd(hEnemyDir);
        if (dir & 0x02) return (void *)GAME_EnemyDefeated;
        wr(hEnemyDir, dir | 0x02);
        CALL(GAME_EnemyStoreAuxToTile);
        return (void *)GAME_EnemyDefeated;
    }
    if (!(rd(hEnemyDir) & 0x01)) {
        CALL(GAME_EnemyClearTileSaveStep);
        wr(hEnemyDir, rd(hEnemyDir) | 0x01);
    }
    uint8_t timer = rd(hEnemyTimer);
    wr(hEnemyTimer, timer - 1);
    if (timer == 0) {
        gb_native_EnemyMapTile();
        wr(HL(), rd(hEnemyAux));
        return (void *)GAME_RemoveEnemy;
    }
    uint8_t card = rd(wActiveMagic);
    if ((card == 0x04 || card == 0x06) && (rd(wMagicState) & 0x01)) {
        gb_native_EnemyMapTile();
        wr(HL(), rd(hEnemyAux));
    } else {
        CALL(GAME_EnemyClearTileSaveStep);
    }
    CALL(GAME_EnemyKind7SetAnimation);
    gb_native_SelectObject2();
    gb_native_DrawObject();
    return 0;
}

/* Mode1_Play: sets a room up for play and then runs the frame loop forever (the loop is left by a routine that resets the stack and jumps to another mode).
 * Setup: stack, LCD off, clear the map, load tiles (bank 2), unpack the room map and draw it with the metatiles of the room theme, VRAM jobs of the room,
 * the paint counter of the round, magic screen and points, camera, round and player variables (once), enemies and projectile cleared, serial start,
 * interrupts and the LCD on, round music, the round timer. Each frame: wait for the frame, read the pad, PlayFrame, the magic screen, camera,
 * enemy spawning and updates, the time-up enemy and the extra life check; hBlinkTick counts frames. */
void *gb_native_Mode1_Play(void) {
    r.sp = wStackTop;
    CALL(GAME_LcdOff);
    ime = 0;
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    CALL(GAME_LoadGfxBank2);
    CALL(GAME_ClearOamShadow);
    SET_HL(DATA_RoomMapTable);
    r.a = rd(wRound);
    CALL(GAME_TableIndexFromRoundDec);
    CALL(GAME_UnpackRoomMap);
    wr(hScratch01, 0x10);
    wr(hScratch00, 0x10);
    r.a = rd(wRoomIndex);
    SET_HL(DATA_RoomMetatileTable);
    CALL(GAME_TableIndexFromRound);
    SET_HL(vBGMap0);
    SET_DE(wRoomMap);
    wr(wMapCellMask, 0x0F);
    CALL(GAME_DrawMetatileMap);
    r.a = rd(wRoomIndex);
    SET_HL(DATA_RoomVramJobTable);
    CALL(GAME_TableIndexFromRound);
    CALL(GAME_RunVramCopyList);
    r.c = 0x10;
    r.a = (uint8_t)(rd(wRound) - 1);
    if (r.a != 0x20) r.c = r.a & 0x0F;
    SET_HL(DATA_PaintCellCountTable);
    gb_native_LookupByte();
    wr(wPaintRemaining, r.a);
    CALL(GAME_RequestOamDma);
    CALL(GAME_ClearOamShadowY);
    CALL(GAME_InitMagicScreenState);
    CALL(GAME_InitMagicPoints);
    CALL(GAME_ResetCamera);
    if (!(rd(wRoundFlags) & 0x04)) {
        wr(wRoundFlags, rd(wRoundFlags) | 0x04);
        CALL(GAME_ClearRoundVariables);
    }
    if (!(rd(wGameFlags) & 0x80)) {
        wr(wGameFlags, rd(wGameFlags) | 0x80);
        CALL(GAME_InitPlayer);
    }
    CALL(GAME_ClearAllEnemies);
    SET_HL(wProjectile);
    gb_native_Clear32Bytes();
    CALL(GAME_SerialStartTransfer);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    CALL(GAME_StartRoundMusic);
    wr(wGameFlags, rd(wGameFlags) & ~0x20);
    wr(hTimeFrames, 0x3C);
    r.a = rd(wRound);
    if (r.a == 0x21) {
        r.a = 0x5A;
    } else {
        r.c = r.a >> 2;
        SET_HL(DATA_RoundTimeTable);
        gb_native_LookupByte();
    }
    wr(hTimeSeconds, r.a);
    wr(hRoundSeconds, r.a);
    wr(hVBlankTasks, rd(hVBlankTasks) | 0x10);
    for (;;) {
        CALL(GAME_WaitFrameAndSyncOam);
        CALL(GAME_ReadJoypad);
        CALL(GAME_PlayFrame);
        CALL(GAME_ShowMagicScreen);
        CALL(GAME_UpdateCamera);
        CALL(GAME_StepEnemySpawnScript);
        CALL(GAME_UpdateAllEnemies);
        CALL(GAME_TimeUpSpawnEnemy);
        CALL(GAME_CheckExtraLife);
        wr(hBlinkTick, rd(hBlinkTick) + 1);
    }
}

/* HoldDirectionUntilAligned: while the player is between two grid cells the pad is overridden: the direction bits of hJoyHeld (high nibble) are replaced by
 * the direction the player already moves in (wPlayerDir), so a started step is finished. The buttons (low nibble) are kept unless a direction is pressed.
 * Nothing is done when both opposite directions are combined (the value $30 or $c0), or when the player is exactly on the grid. */
void *gb_native_HoldDirectionUntilAligned(void) {
    r.b = rd(wPlayerX);
    r.c = rd(wPlayerY);
    gb_native_IsOnTileGrid();
    if (ZF()) return 0;
    uint8_t dir_high = (uint8_t)((rd(wPlayerDir) & 0x0F) << 4);
    uint8_t held = rd(hJoyHeld);
    if ((uint8_t)(held | dir_high) == 0x30 || (uint8_t)(held | dir_high) == 0xC0) return 0;
    wr(hJoyHeld, ((held & 0xF0) ? 0 : (held & 0x0F)) | dir_high);
    return 0;
}

/* PlayerSetDirection: turns the pad into the player's direction and step. Blocked directions (wPlayerBlocked, shifted into the pad nibble) or no direction
 * stop the player (SetPlayerStatusBit0). Otherwise wPlayerDir gets the direction, the heading comes from DirectionToAnimIndex, the 16 bit steps from a table of
 * 4 byte entries (x fraction, x pixels, y fraction, y pixels; a second table while the S.UP card runs), the speed is 9 and the step is applied. */
void *gb_native_PlayerSetDirection(void) {
    uint8_t held = rd(hJoyHeld);
    if (((rd(wPlayerBlocked) << 4 | rd(wPlayerBlocked) >> 4) & 0xFF & held) != 0) return (void *)GAME_SetPlayerStatusBit0;
    if (!(held & 0xF0)) return (void *)GAME_SetPlayerStatusBit0;
    uint8_t dir = held >> 4;
    wr(wPlayerDir, (rd(wPlayerDir) & 0xF0) | dir);
    uint8_t angle = rd(DATA_DirectionToAnimIndex + dir);
    wr(wPlayerAngle, angle);
    uint16_t table = 0x518D;
    if (rd(wActiveMagic) == 0x01 && (rd(wMagicState) & 0x01)) table = 0x519D;
    table += angle >> 1;
    wr(wPlayerStepYLo, rd(table));
    wr(wPlayerVelY, rd(table + 1));
    wr(wPlayerStepXLo, rd(table + 2));
    wr(wPlayerVelX, rd(table + 3));
    wr(wPlayerSpeed, 0x09);
    SET_HL(wPlayer);
    gb_native_SetObjPtr();
    gb_native_ApplyObjectStep();
    wr(wPlayerStatus, rd(wPlayerStatus) & ~0x01);
    return 0;
}

/* SelectPlayerAnimation: chooses the table of animation pointers by the direction in wPlayerDir (bit 0 = right: mirrored, bit 1 = left: not mirrored, bit 2 = up). */
void *gb_native_SelectPlayerAnimation(void) {
    uint8_t dir = rd(wPlayerDir);
    uint16_t table;
    if (dir & 0x01) { wr(wPlayer, rd(wPlayer) | 0x20); table = DATA_PlayerAnimPtrsFlipped; }
    else if (dir & 0x02) { wr(wPlayer, rd(wPlayer) & ~0x20); table = DATA_PlayerAnimPtrsFlipped; }
    else if (dir & 0x04) table = 0x48D4;
    else table = DATA_PlayerAnimPtrs;
    wr(wPlayerAnimPtrLo, table);
    wr(wPlayerAnimPtrHi, table >> 8);
    return 0;
}

static void draw_record(uint16_t record) {      /* hObjPtr = record, DrawObject */
    SET_HL(record);
    gb_native_SetObjPtr();
    gb_native_DrawObject();
}

static void draw_enemy_record(void) {           /* the enemy record in hObject2 */
    gb_native_SelectObject2();
    gb_native_DrawObject();
}

/* ProjectileFrame: the shot of an enemy (object at wProjectile) kills the player when its box overlaps the player's. Skipped while SEALED (6) or GHOST (4) runs. */
void *gb_native_ProjectileFrame(void) {
    if ((rd(wActiveMagic) == 0x06 || rd(wActiveMagic) == 0x04) && (rd(wMagicState) & 0x01)) return 0;
    if (!(rd(wProjectile) & 0x80)) return 0;
    wr(hOtherObjLo, (uint8_t)wProjectile);
    wr(hOtherObjHi, wProjectile >> 8);
    wr(hObjPtrLo, (uint8_t)wPlayer);
    wr(hObjPtrHi, wPlayer >> 8);
    gb_native_ObjectsOverlap();
    if (r.a) {
        SET_HL(wPlayerDir);
        wr(wPlayerDir, rd(wPlayerDir) | 0x20);
    }
    return 0;
}

/* EnemyDefeated: an enemy hit by paint (hEnemyFlags bit 2). It plays sound $8e, then shows a short effect driven by a counter (hEnemyCounter2, or
 * wComboCounter while wPlayerStatus bit 4 is set, which also pops the projectile object): CounterToFrame turns the counter into a stage; the effect frames
 * are drawn mirrored four ways to make a burst. After the last stage the score of the enemy's kind (EnemyScoreTable) is added with AddScore,
 * the status bits 3 and 4 are cleared and the enemy is removed. */
void *gb_native_EnemyDefeated(void) {
    r.a = SND_SFX_8E;
    CALL(GAME_PlaySound);
    wr(hEnemyCounter2, rd(hEnemyCounter2) + 1);
    int combo = (rd(wPlayerStatus) & 0x10) != 0;
    if (combo) wr(wComboCounter, rd(wComboCounter) + 1);
    wr(hScratch00 + 6, 0x0C);
    wr(hScratch00 + 7, 0x02);
    wr(hScratch00 + 8, rd(combo ? wComboCounter : hEnemyCounter2));
    r.a = 0x03;
    gb_native_CounterToFrame();
    wr(hEnemyCounter2, rd(hScratch00 + 8));
    if (combo) wr(wComboCounter, rd(hScratch00 + 8));
    if (r.c == 0x06) {
        wr(wPlayerStatus, rd(wPlayerStatus) & ~0x18);
        wr(hEnemyFlags, rd(hEnemyFlags) & ~0x04);
        r.c = rd(hEnemyKind);
        SET_HL(DATA_EnemyScoreTable);
        gb_native_LookupByte();
        r.e = r.a;
        r.d = 0;
        CALL(GAME_AddScore);
        wr(wProjectile, rd(wProjectile) & 0x7F);
        gb_native_RemoveEnemy();
        return 0;
    }
    uint16_t frames = r.c == 0 ? DATA_PopFrames1 : (r.c == 2 ? DATA_PopFrames2 : DATA_PopFrames3);
    wr(hEnemyAnimLo, (uint8_t)frames);
    wr(hEnemyAnimHi, frames >> 8);
    draw_enemy_record();
    if (combo) { wr(wProjectileAnimLo, (uint8_t)frames); wr(wProjectileAnimHi, frames >> 8); draw_record(wProjectile); }
    wr(hObject2, rd(hObject2) | 0x40);
    draw_enemy_record();
    if (combo) { wr(wProjectile, rd(wProjectile) | 0x40); draw_record(wProjectile); }
    wr(hObject2, (rd(hObject2) | 0x20) & ~0x40);
    draw_enemy_record();
    if (combo) { wr(wProjectile, (rd(wProjectile) | 0x20) & ~0x40); draw_record(wProjectile); }
    wr(hObject2, rd(hObject2) | 0x40);
    draw_enemy_record();
    if (combo) { wr(wProjectile, rd(wProjectile) | 0x40); draw_record(wProjectile); }
    wr(hObject2, rd(hObject2) & 0x9F);
    if (combo) wr(wProjectile, rd(wProjectile) & 0x9F);
    return 0;
}

/* AddScore: adds D:E points (E mostly) to the score, which is three bytes of base 100 digits at wScoreDigits (low first). The digits are then redrawn
 * (DrawDecimalDigits turns each byte into two decimal digits at wScoreDecimal) and queued as the tile stream at wScoreStream (count 6, rows 1, six tiles),
 * and CheckExtraLife runs. */
void *gb_native_AddScore(void) {
    SET_BC(0);
    SET_HL(wScoreDigits);
    r.a = r.e;
    alu_add(rd(HL()), 0);
    wr(wScoreTemp, r.a);
    gb_native_ByteToBCD();
    if (rd(hScratch00 + 3)) {
        r.d++;
        wr(wScoreTemp, rd(wScoreTemp) - 100);
    }
    wr(HL(), rd(wScoreTemp));
    SET_HL(HL() + 1);
    r.a = r.d;
    alu_add(rd(HL()), 0);                       /* the carry is 0 here (ByteToBCD found a hundred in that case) */
    wr(HL(), r.a);
    SET_HL(HL() + 1);
    int carry = CF() ? 1 : 0;
    r.a = 0;
    alu_add(rd(HL()), carry);
    wr(HL(), r.a);
    for (int i = 0; i < 3; i++) {
        CALL(GAME_DrawDecimalDigits);
        if (i < 2) SET_HL(HL() - 1);
    }
    wr(wScoreStream, 0x06);
    wr(wScoreStream + 1, 0x01);
    for (int i = 0; i < 6; i++) {
        r.a = rd(wScoreDecimal + i);
        CALL(GAME_LowNibbleToDigitTile);
        wr(wScoreStream + 2 + i, r.a);
    }
    return (void *)GAME_CheckExtraLife;
}

/* StepEnemySpawnScript: runs the spawn list of the round (RoundDataTable[wRound - 1] -> six wave lists -> entries `kind, x, y, delay` of 4 bytes after a count byte).
 * The delay of the next entry is loaded once (wPlayerStatus bit 5 marks that); when the seconds elapsed in the round (hRoundSeconds - hTimeSeconds) reach it
 * and fewer than 3 enemies are alive, the entry is spawned through FindFreeEnemySlot (kind in hScratch07, X in hScratch08, Y in hScratch0A, flag in hSpawnFlag).
 * After the last entry of a wave the next wave starts (wSpawnWave; it wraps after 6 and wWaveEnded is set). */
void *gb_native_StepEnemySpawnScript(void) {
    r.a = (uint8_t)(rd(wRound) - 1);
    SET_HL(DATA_RoundDataTable);
    gb_native_LookupWord();
    if (rd(wSpawnWave) == 0x06) wr(wSpawnWave, 0);
    r.a = rd(wSpawnWave);
    gb_native_LookupWord();
    uint16_t list = HL();
    wr(wSpawnListPtr, (uint8_t)list);
    wr(wSpawnListPtr + 1, list >> 8);
    uint8_t count = rd(list);
    wr(wSpawnCount, count);
    if ((uint8_t)(rd(wSpawnIndex) - 1) == count) {
        wr(wSpawnWave, rd(wSpawnWave) + 1);
        wr(wSpawnIndex, 1);
        wr(wWaveEnded, 1);
    }
    list = rd(wSpawnListPtr) | rd(wSpawnListPtr + 1) << 8;
    if (!(rd(wPlayerStatus) & 0x20)) {
        wr(hSpawnDelay, rd(list + (uint8_t)(rd(wSpawnIndex) << 2)));
        wr(wPlayerStatus, rd(wPlayerStatus) | 0x20);
    }
    uint8_t delay = rd(hSpawnDelay);
    if ((uint8_t)(rd(hRoundSeconds) - delay) < rd(hTimeSeconds)) return 0;
    if (rd(wEnemyCount) >= 0x03) return 0;
    uint16_t entry = list + (uint8_t)((rd(wSpawnIndex) << 2) - 3);
    wr(hScratch00 + 7, rd(entry));
    wr(hScratch00 + 8, rd(entry + 1));
    wr(hScratch00 + 10, rd(entry + 2) & 0xF8);
    wr(hSpawnFlag, rd(entry + 2) & (rd(wRound) >= 0x11 ? 0x02 : 0x01));
    wr(wSpawnIndex, rd(wSpawnIndex) + 1);
    wr(wWaveEnded, rd(wWaveEnded) + 1);
    wr(wEnemyCount, rd(wEnemyCount) + 1);
    wr(wPlayerStatus, rd(wPlayerStatus) & ~0x20);
    return (void *)GAME_FindFreeEnemySlot;
}

/* TimeUpSpawnEnemy: when the round clock has run out (hTimeSeconds and $ffe2 both 0), or in a link game when the other machine asks for it (hSerialByte bit 5),
 * one extra enemy (kind 4, X $a0, Y $98) is spawned once per round (wGameFlags bit 5) and the link transfer is started. */
void *gb_native_TimeUpSpawnEnemy(void) {
    int linked = (rd(hLinkFlags) & 0x01) && (rd(hSerialByte) & 0x20);
    if (!linked && (rd(hTimeSeconds) | rd(0xFFE2))) return 0;
    if (rd(wGameFlags) & 0x20) return 0;
    wr(wGameFlags, rd(wGameFlags) | 0x20);
    wr(hScratch00 + 7, 0x04);
    wr(hScratch00 + 8, 0xA0);
    wr(hScratch00 + 10, 0x98);
    CALL(GAME_FindFreeEnemySlot);
    return (void *)GAME_SerialStartTransfer;
}

/* RunMagicEffect: runs the effect routine of the active card (wActiveMagic indexes MagicEffectTable) as a tail jump; clears wMagicState bit 2 first. */
void *gb_native_RunMagicEffect(void) {
    wr(wMagicState, rd(wMagicState) & ~0x04);
    r.c = (uint8_t)(rd(wActiveMagic) << 1);
    SET_HL(DATA_MagicEffectTable);
    gb_native_LookupByte();
    uint16_t entry = HL();
    r.e = r.a;
    r.d = rd(entry + 1);
    return (void *)gb_dispatch((uint16_t)(r.d << 8 | r.e));
}

/* PlayerAction: the A button during play. While a card effect runs (wMagicState bit 0) the effect is run. A press (hJoyNew bit 0) sets wPlayerDir bit 6;
 * with a card selected (wActiveMagic) and the player standing still (wPlayerStatus bit 0) the cast starts: bit 0 of wMagicState is set and the cost of the card
 * (MagicCostTable) is taken from wMagicPoints by PayMagicCost (with a link game LinkSyncFrame first when the points hit exactly 0). */
void *gb_native_PlayerAction(void) {
    if (rd(wMagicState) & 0x01) return gb_native_RunMagicEffect();
    if (!(rd(hJoyNew) & 0x01)) return 0;
    wr(wPlayerDir, rd(wPlayerDir) | 0x40);
    wr(wMagicState, rd(wMagicState) & ~0x02);
    if (rd(wActiveMagic) == 0) return 0;
    if (!(rd(wPlayerStatus) & 0x01)) return 0;
    wr(wMagicState, rd(wMagicState) | 0x01);
    SET_HL(DATA_MagicCostTable);
    r.c = rd(wActiveMagic);
    gb_native_LookupByte();
    r.c = r.a;
    r.a = rd(wMagicPoints);
    alu_sub(r.c, 0);
    r.e = r.a;
    if (ZF()) return (void *)GAME_LinkSyncFrame;
    return (void *)GAME_PayMagicCost;
}

/* PaintCell: B = X and C = Y of a grid aligned cell under the player. Sets the painted bit ($10) of the map cell and queues the tile update (two tile rows from
 * D_01_4921 for path type 1, else D_01_491b) at the cell's position in the background map, waits for the VRAM copy, and counts wPaintRemaining down;
 * at 0 the round is cleared (RoundCleared). Nothing happens when the cell is already painted. */
void *gb_native_PaintCell(void) {
    r.a = r.b;
    gb_native_PixelXToColumn();
    r.a = r.c;
    gb_native_LookupMapTile();
    uint8_t tile = r.a;
    wr(hScratch00, tile);
    if (tile & 0x10) return 0;
    wr(HL(), (tile & 0x0F) | 0x10);
    wr(hSpriteX, r.b);
    wr(hSpriteY, (uint8_t)(r.c - 8));
    CALL(GAME_PixelToTilemapAddr);
    r.l = rd(hTilemapAddrLo);
    r.l--;
    r.h = rd(hTilemapAddrHi);
    SET_DE((tile & 0x0F) == 0x01 ? 0x4921 : 0x491B);
    CALL(GAME_QueueVramCopyRows);
    CALL(GAME_WaitVramCopyDone);
    wr(wPaintRemaining, rd(wPaintRemaining) - 1);
    if (rd(wPaintRemaining)) return 0;
    return (void *)GAME_RoundCleared;
}

/* PaintUnderPlayerCell: paints the map cell under the player when it is a path cell and the player is exactly on the grid. */
void *gb_native_PaintUnderPlayerCell(void) {
    r.a = rd(wPlayerX);
    gb_native_PixelXToColumn();
    r.a = rd(wPlayerY);
    gb_native_LookupMapTile();
    if (r.a == 0) return 0;
    gb_native_LoadPlayerXY();
    gb_native_IsOnTileGrid();
    if (!ZF()) return 0;
    return gb_native_PaintCell();
}

/* PaintUnderPlayerAligned: the same with the player's Y rounded to the grid row (used while the W.IN card lets the player walk between rows). */
void *gb_native_PaintUnderPlayerAligned(void) {
    r.a = rd(wPlayerX);
    gb_native_PixelXToColumn();
    r.a = (uint8_t)((rd(wPlayerY) & 0xF0) + 8);
    gb_native_LookupMapTile();
    if (r.a == 0) return 0;
    return gb_native_PaintUnderPlayerCell();
}

/* PaintUnderPlayer: paints the floor under the player (not while the card 9, PYON, effect runs; with card 2, W.IN, the aligned version). */
void *gb_native_PaintUnderPlayer(void) {
    if (rd(wActiveMagic) == 0x09 && (rd(wMagicState) & 0x01)) return 0;
    if (rd(wActiveMagic) == 0x02) return gb_native_PaintUnderPlayerAligned();
    return gb_native_PaintUnderPlayerCell();
}

/* ClearRoomState: zeroes the card state, the enemy count and the spawn script variables (the next entry is number 1). */
void *gb_native_ClearRoomState(void) {
    wr(wActiveMagic, 0);
    wr(wMagicState, 0);
    wr(wEnemyCount, 0);
    wr(wWaveEnded, 0);
    wr(wSpawnWave, 0);
    wr(wSpawnIndex, 1);
    r.a = 1;
    r.f = 0x80;
    return 0;
}

/* DrawTwoDigitNumber: B = a value, HL = background map address. Draws its two decimal digits as a VRAM stream (count 2, rows 1, two digit tiles). */
void *gb_native_DrawTwoDigitNumber(void) {
    wr(hScratch00 + 10, 0x02);
    wr(hScratch00 + 11, 0x01);
    r.a = r.b;
    gb_native_ByteToBCD();
    wr(hScratch00, r.a);
    r.a = r.a & 0xF0;
    r.a = (uint8_t)(r.a << 4 | r.a >> 4);
    gb_native_DigitToTile();
    wr(hScratch00 + 12, r.a);
    r.a = rd(hScratch00) & 0x0F;
    gb_native_DigitToTile();
    wr(hScratch00 + 13, r.a);
    SET_DE(hScratch00 + 10);
    return (void *)GAME_VramCopyStream;
}

/* Mode3_RoundIntro: the "ROUND nn / room name / lives / READY !!" screen. Shown for $97 frames, then mode 1 (play) is started. */
void *gb_native_Mode3_RoundIntro(void) {
    r.sp = wStackTop;
    CALL(GAME_LcdOff);
    ime = 0;
    r.a = 0xFF;
    CALL(GAME_PlaySound);
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    wr(0xC7C2, 0);
    CALL(GAME_LoadTilesBank3A);
    CALL(GAME_ClearOamShadow);
    SET_BC(DATA_RoundIntroText);
    CALL(GAME_RunVramCopyList);
    r.b = rd(wRound);
    SET_HL(0x986C);
    CALL(GAME_DrawTwoDigitNumber);
    r.b = (rd(hLinkFlags) & 0x01) ? 1 : rd(wLives);
    SET_HL(0x992C);
    CALL(GAME_DrawTwoDigitNumber);
    r.a = rd(wRound);
    SET_HL(DATA_RoomNameJobTable);
    CALL(GAME_TableIndexFromRoundDec);
    SET_HL(0x98C3);
    CALL(GAME_VramCopyStream);
    CALL(GAME_RequestOamDma);
    CALL(GAME_ClearOamShadowY);
    gb_native_ClearRoomState();
    CALL(GAME_ClearBonusFlags);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    wr(hScratch00, 0x97);
    do {
        CALL(GAME_WaitVBlankFlag);
        CALL(GAME_ReadJoypad);
        wr(hScratch00, rd(hScratch00) - 1);
    } while (rd(hScratch00));
    r.a = 1;
    return (void *)GAME_GameModeDispatch;
}

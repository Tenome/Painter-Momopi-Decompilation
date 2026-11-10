/* Hand written C versions of game routines (replacing the generated code for the labels listed in port/overrides.txt).
 * Most keep the register and flag results of the original routine so that its callers behave the same (the ones that do not say so in their comment); the generated code and these
 * versions are compared with `python tools/lift_check.py` (frame hashes of random play) before a routine is added here. */
#include "gb_rt.h"
#include "game_symbols.h"      /* generated: wPlayerX, hEnemyKind ... (from src/constants.inc) */
#include "game_labels.h"       /* generated: GAME_<Label> = the generated routine of a label */

/* A `call` inside a lifted routine. Like CALL of the generated code, but when the callee discards its return address (pop hl before a return: the sound command
 * routines do) the whole chain has already returned past this routine, so the routine returns and gives back the slot the stub of the override releases again. */
/* a call whose callee never discards its return address */
#define NCALL_VOID(fn) do { r.sp -= 2; gb_run((fn_t)(fn)); } while (0)
#define NCALL(fn) do { uint16_t sp0_ = r.sp; r.sp -= 2; gb_run((fn_t)(fn)); if (r.sp > sp0_) { r.sp -= 2; return 0; } } while (0)

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
    NCALL(GAME_PlayerAction);
    if (!(rd(wActiveMagic) == 0x02 && (rd(wMagicState) & 0x01))) {
        gb_native_PlayerCheckOffPath();
        gb_native_LoadPlayerXY();
        gb_native_PlayerComputeBlockedDirs();
    }
    NCALL(GAME_HoldDirectionUntilAligned);
    NCALL(GAME_PlayerSetDirection);
    gb_native_ClampPlayerPosition();
    NCALL(GAME_PaintUnderPlayer);
    NCALL(GAME_SelectPlayerAnimation);
    NCALL(GAME_ProjectileFrame);
    if (rd(wActiveMagic) != 0 && (rd(wMagicState) & 0x01)) {
        wr(0xC4D3, rd(0xC4D3) + 1);
        if (!(rd(0xC4D3) & 0x02)) return 0;
    }
    NCALL(GAME_AnimatePlayerWalk);
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
    NCALL(GAME_EnemyComputeBlockedDirs);
    NCALL(GAME_EnemyGridStep);
    NCALL(GAME_EnemyChooseDirection);
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_EnemyErasePaint);
    NCALL(GAME_EnemyPaintUnderB0M);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_CheckPaintHitsEnemy);
    NCALL(GAME_EnemySelectAnimByKind);
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
    NCALL(GAME_EnemyComputeBlockedDirs);
    NCALL(GAME_EnemyGridStep);
    gb_native_EnemyEdgeBlockedDirs();
    NCALL(GAME_EnemyChooseDirection);
    NCALL(GAME_EnemyFlagOffPath);
    if (rd(hEnemyFlags) & 0x02) {
        wr(hEnemyCounter, rd(hEnemyCounter) + 1);
        if (!(rd(hEnemyCounter) & 0x08)) return 0;
    }
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_EnemyErasePaint);
    NCALL(GAME_EnemyPaintUnderB0M);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_CheckPaintHitsEnemy);
    NCALL(GAME_SetEnemyAnimation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind2: an enemy that shoots (EnemyShooterAI decides, ProjectileFrame moves the shot). */
void *gb_native_EnemyKind2(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind2Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    NCALL(GAME_EnemyComputeBlockedDirs);
    NCALL(GAME_EnemyGridStep);
    NCALL(GAME_EnemyChooseDirection);
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_EnemyShootIfReady);
    NCALL(GAME_EnemyShooterAI);
    NCALL(GAME_ProjectileFrame);
    NCALL(GAME_EnemyPaintUnderB0M);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_CheckPaintHitsEnemy);
    NCALL(GAME_SelectKind2Animation);
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
    NCALL(GAME_EnemyAimAtPlayer);
    NCALL(GAME_EnemyFlagOffPath);
    NCALL(GAME_EnemyTurnIfBlocked);
    NCALL(GAME_MoveAndApplyObject);
    NCALL(GAME_EnemyPaintUnderB0M);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_SelectKind3Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind4: aims at the player and turns; it cannot be hurt by paint (no defeat check). */
void *gb_native_EnemyKind4(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind4Init;
    NCALL(GAME_EnemyAimAtPlayer);
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_SelectKind4Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind5: a teleporting enemy (EnemyKind7Teleport moves it along its position table). It does not touch the player while the SEALED card (6) runs. */
void *gb_native_EnemyKind5(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyBuildTeleportTable;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    if (!(rd(wActiveMagic) == 0x06 && (rd(wMagicState) & 0x01))) NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_CheckPaintHitsEnemy);
    NCALL(GAME_EnemyIdleAnimate);
    NCALL(GAME_EnemyTeleportNext);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind7 (rounds 5-7 and 21-23): follows a scripted path (EnemyKind7NextStep reads the path table at wEnemyPathPtr). */
void *gb_native_EnemyKind7(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind7Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    NCALL(GAME_EnemyKind7NextStep);
    NCALL(GAME_MoveAndApplyObject);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_CheckPaintHitsEnemy);
    NCALL(GAME_EnemyKind7Update);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind9: aims at the player like kind 3 but is bound by the blocked directions of the grid. */
void *gb_native_EnemyKind9(void) {
    gb_native_SelectObject2();
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_EnemyKind9Init;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    NCALL(GAME_EnemyComputeBlockedDirs);
    NCALL(GAME_EnemyAimAtPlayer);
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_EnemyPaintUnderB0M);
    NCALL(GAME_CheckEnemyTouchesPlayer);
    NCALL(GAME_SelectKind9Animation);
    gb_native_DrawObject();
    return 0;
}

/* EnemyKind10 (rounds 14 and 30): the enemy that fires a projectile object (InitProjectile at first; the projectile is updated and drawn here). */
void *gb_native_EnemyKind10(void) {
    gb_native_TickObjectTimer();
    if (ZF()) return (void *)GAME_InitProjectile;
    if (rd(hEnemyFlags) & 0x04) return (void *)GAME_EnemyDefeated;
    NCALL(GAME_EnemyMoveStep);
    NCALL(GAME_EnemyKind10Move);
    NCALL(GAME_UpdateProjectile);
    NCALL(GAME_ProjectileCheckPlayerHit);
    NCALL(GAME_ProjectileRemoveIfHit);
    NCALL(GAME_ProjectileSelectFrame);
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
        NCALL(GAME_EnemyStoreAuxToTile);
        return (void *)GAME_EnemyDefeated;
    }
    if (!(rd(hEnemyDir) & 0x01)) {
        NCALL(GAME_EnemyClearTileSaveStep);
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
        NCALL(GAME_EnemyClearTileSaveStep);
    }
    NCALL(GAME_EnemyKind7SetAnimation);
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
    NCALL(GAME_LcdOff);
    ime = 0;
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    NCALL(GAME_LoadGfxBank2);
    NCALL(GAME_ClearOamShadow);
    SET_HL(DATA_RoomMapTable);
    r.a = rd(wRound);
    NCALL(GAME_TableIndexFromRoundDec);
    NCALL(GAME_UnpackRoomMap);
    wr(hScratch01, 0x10);
    wr(hScratch00, 0x10);
    r.a = rd(wRoomIndex);
    SET_HL(DATA_RoomMetatileTable);
    NCALL(GAME_TableIndexFromRound);
    SET_HL(vBGMap0);
    SET_DE(wRoomMap);
    wr(wMapCellMask, 0x0F);
    NCALL(GAME_DrawMetatileMap);
    r.a = rd(wRoomIndex);
    SET_HL(DATA_RoomVramJobTable);
    NCALL(GAME_TableIndexFromRound);
    NCALL(GAME_RunVramCopyList);
    r.c = 0x10;
    r.a = (uint8_t)(rd(wRound) - 1);
    if (r.a != 0x20) r.c = r.a & 0x0F;
    SET_HL(DATA_PaintCellCountTable);
    gb_native_LookupByte();
    wr(wPaintRemaining, r.a);
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadowY);
    NCALL(GAME_InitMagicScreenState);
    NCALL(GAME_InitMagicPoints);
    NCALL(GAME_ResetCamera);
    if (!(rd(wRoundFlags) & 0x04)) {
        wr(wRoundFlags, rd(wRoundFlags) | 0x04);
        NCALL(GAME_ClearRoundVariables);
    }
    if (!(rd(wGameFlags) & 0x80)) {
        wr(wGameFlags, rd(wGameFlags) | 0x80);
        NCALL(GAME_InitPlayer);
    }
    NCALL(GAME_ClearAllEnemies);
    SET_HL(wProjectile);
    gb_native_Clear32Bytes();
    NCALL(GAME_SerialStartTransfer);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    NCALL(GAME_StartRoundMusic);
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
        NCALL(GAME_WaitFrameAndSyncOam);
        NCALL(GAME_ReadJoypad);
        NCALL(GAME_PlayFrame);
        NCALL(GAME_ShowMagicScreen);
        NCALL(GAME_UpdateCamera);
        NCALL(GAME_StepEnemySpawnScript);
        NCALL(GAME_UpdateAllEnemies);
        NCALL(GAME_TimeUpSpawnEnemy);
        NCALL(GAME_CheckExtraLife);
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
    NCALL(GAME_PlaySound);
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
        NCALL(GAME_AddScore);
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
        NCALL(GAME_DrawDecimalDigits);
        if (i < 2) SET_HL(HL() - 1);
    }
    wr(wScoreStream, 0x06);
    wr(wScoreStream + 1, 0x01);
    for (int i = 0; i < 6; i++) {
        r.a = rd(wScoreDecimal + i);
        NCALL(GAME_LowNibbleToDigitTile);
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
    NCALL(GAME_FindFreeEnemySlot);
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
    NCALL(GAME_PixelToTilemapAddr);
    r.l = rd(hTilemapAddrLo);
    r.l--;
    r.h = rd(hTilemapAddrHi);
    SET_DE((tile & 0x0F) == 0x01 ? 0x4921 : 0x491B);
    NCALL(GAME_QueueVramCopyRows);
    NCALL(GAME_WaitVramCopyDone);
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
    NCALL(GAME_LcdOff);
    ime = 0;
    r.a = 0xFF;
    NCALL(GAME_PlaySound);
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    wr(0xC7C2, 0);
    NCALL(GAME_LoadTilesBank3A);
    NCALL(GAME_ClearOamShadow);
    SET_BC(DATA_RoundIntroText);
    NCALL(GAME_RunVramCopyList);
    r.b = rd(wRound);
    SET_HL(0x986C);
    NCALL(GAME_DrawTwoDigitNumber);
    r.b = (rd(hLinkFlags) & 0x01) ? 1 : rd(wLives);
    SET_HL(0x992C);
    NCALL(GAME_DrawTwoDigitNumber);
    r.a = rd(wRound);
    SET_HL(DATA_RoomNameJobTable);
    NCALL(GAME_TableIndexFromRoundDec);
    SET_HL(0x98C3);
    NCALL(GAME_VramCopyStream);
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadowY);
    gb_native_ClearRoomState();
    NCALL(GAME_ClearBonusFlags);
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
        NCALL(GAME_WaitVBlankFlag);
        NCALL(GAME_ReadJoypad);
        wr(hScratch00, rd(hScratch00) - 1);
    } while (rd(hScratch00));
    r.a = 1;
    return (void *)GAME_GameModeDispatch;
}

/* Mode4_GameOver: the GAME OVER screen: tiles, the text, the game over music; shown for 3 x 256 frames, then back to the title (mode 0) or, in a link game, a restart. */
void *gb_native_Mode4_GameOver(void) {
    r.sp = wStackTop;
    NCALL(GAME_LcdOff);
    ime = 0;
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    NCALL(GAME_LoadTilesBank3A);
    NCALL(GAME_ClearOamShadow);
    r.a = SND_MUSIC_GAME_OVER;
    NCALL(GAME_PlaySound);
    SET_HL(0x9905);
    SET_DE(DATA_GameOverText);
    NCALL(GAME_VramCopyStream);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadowY);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    wr(wRoundFlags, rd(wRoundFlags) & ~0x01);
    wr(wGameFlags, rd(wGameFlags) & ~0x04);
    wr(hScratch00, 0xFF);
    wr(hScratch00 + 1, 0x02);
    for (;;) {
        do {
            NCALL(GAME_WaitVBlankFlag);
            NCALL(GAME_ReadJoypad);
            wr(hScratch00, rd(hScratch00) - 1);
        } while (rd(hScratch00));
        uint8_t left = (uint8_t)(rd(hScratch00 + 1) - 1);
        wr(hScratch00 + 1, left);
        if (left & 0x80) break;
    }
    if (rd(hLinkFlags) & 0x01) return (void *)GAME_Entry;
    r.a = 0;
    return (void *)GAME_GameModeDispatch;
}

/* SoundDequeue: takes the first command out of the sound queue (wSoundQueue, wSoundQueueLen entries) into wSoundCmd and moves the rest forward. */
void *gb_native_SoundDequeue(void) {
    uint8_t len = rd(wSoundQueueLen);
    if (len == 0) return 0;
    wr(wSoundCmd, rd(wSoundQueue));
    for (int i = 0; i < len; i++) wr(wSoundQueue + i, rd(wSoundQueue + 1 + i));
    wr(wSoundQueueLen, len - 1);
    return 0;
}

/* SoundUpdate: the sound engine, called once per frame from the VBlank handler: take a queued command when the queue is not being changed (wSoundBusy),
 * start the current command, hand out channels, then update each of the 8 channel records of $20 bytes (those with bit 7 of their first byte set). */
void *gb_native_SoundUpdate(void) {
    if (!rd(wSoundBusy)) gb_native_SoundDequeue();
    NCALL(GAME_SoundStartCommand);
    NCALL(GAME_SoundAssignChannels);
    wr(wSoundChanLeft, 8);
    uint16_t record = wSoundChannels;
    for (;;) {
        SET_BC(record);
        SET_HL(record);
        if (rd(record) & 0x80) NCALL(GAME_SoundUpdateChannel);
        uint8_t left = rd(wSoundChanLeft) - 1;
        wr(wSoundChanLeft, left);
        if (!left) return 0;
        record += 0x20;
    }
}

/* ShowMagicScreen: the B button in play opens MOMOPIE'S MAGIC screen (not while the player is dying or a cast is starting). The screen is set up with the LCD
 * off (tiles of bank 3, the frame and the card pictures, the score, the magic points as a number and as a gauge, the time, the round) and then runs its own
 * frame loop (MagicScreenInput moves the cursor, CursorBlinkStep blinks it) until B is pressed again; then the play screen is restored and the round music is
 * restarted (StartRoundMusic). The gauge: each 100 points give five full tiles ($b8), each 20 points one, and a remainder of 10 a half tile ($a8). */
void *gb_native_ShowMagicScreen(void) {
    if (rd(wPlayerDir) & 0x20) return 0;
    if (rd(wMagicState) & 0x02) return 0;
    if (!(rd(hJoyNew) & 0x02)) return 0;
    NCALL(GAME_LcdOff);
    ime = 0;
    NCALL(GAME_LoadTilesBank3B);
    SET_HL(0x9FFF);
    gb_native_FillBackwardsFF();
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(hVBlankTasks, rd(hVBlankTasks) & ~0x10);
    SET_BC(DATA_MagicScreenJobsA);
    NCALL(GAME_RunVramCopyList);
    SET_BC(DATA_MagicScreenJobsB);
    NCALL(GAME_RunVramCopyList);
    SET_BC(0x0010);
    SET_HL(0x9CD0);
    NCALL(GAME_FillBackwardsFFBC);
    wr(wMpStreamIdx, 0);
    SET_BC(0x0010);
    SET_HL(0xC462);
    do {                                    /* $c453-$c462 = tile $98 */
        wr(HL(), 0x98);
        SET_HL(HL() - 1);
        SET_BC(BC() - 1);
    } while (BC());
    NCALL(GAME_InitMagicScreenState);
    SET_HL(0x9C66);
    SET_DE(wScoreStream);
    NCALL(GAME_VramCopyStream);
    r.c = rd(wMagicPointsHi);
    r.a = rd(wMagicPoints);
    gb_native_ByteToBCD();
    r.a = rd(hScratch00 + 2) & 0x0F;
    NCALL(GAME_NumberToTile);
    wr(0xC450, r.a);
    r.a = (uint8_t)(rd(hScratch00 + 2) >> 4);
    NCALL(GAME_NumberToTile);
    wr(0xC44F, r.a);
    r.a = rd(hScratch00 + 3);
    NCALL(GAME_NumberToTile);
    wr(0xC44E, r.a);
    wr(wTextBuf, 0x03);
    wr(wTextBuf + 1, 0x01);
    SET_HL(0x9CA5);
    SET_DE(wTextBuf);
    NCALL(GAME_VramCopyStream);
    r.a = rd(hTimeSeconds);
    r.c = 0;
    gb_native_ByteToBCD();
    r.a = rd(hScratch00 + 2) & 0x0F;
    NCALL(GAME_NumberToTile);
    wr(0xFFE8, r.a);
    r.a = (uint8_t)(rd(hScratch00 + 2) >> 4);
    NCALL(GAME_NumberToTile);
    wr(0xFFE7, r.a);
    r.a = rd(hScratch00 + 3);
    NCALL(GAME_NumberToTile);
    wr(0xFFE6, r.a);
    wr(0xFFE4, 0x03);
    wr(0xFFE5, 0x01);
    SET_HL(0x9CB0);
    SET_DE(0xFFE4);
    NCALL(GAME_VramCopyStream);
    r.b = rd(wRound);
    SET_HL(0x9C71);
    NCALL(GAME_DrawTwoDigitNumber);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    NCALL(GAME_ClearOamShadowY);
    NCALL(GAME_RequestOamDma);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, 0x9B);
    ime = 1;
    wr(hScratch00, 0);
    NCALL(GAME_DrawMagicPage);
    /* the magic points gauge */
    SET_BC(0x0002);
    r.e = rd(wMagicPointsHi) ? 1 : 0;
    wr(hScratch00, rd(wMagicPoints));
    for (;;) {
        uint8_t s = rd(hScratch00), minus100 = (uint8_t)(s - 100);
        if (s >= 100) {
            wr(hScratch00, minus100);
        } else if (r.e) {
            wr(hScratch00, minus100);
            r.e = 0;
        } else {
            for (;;) {
                s = rd(hScratch00);
                if (s == 0) goto gauge_done;
                if (s == 0x0A) {
                    wr(0xC453 + rd(wMpStreamIdx), 0xA8);
                    goto gauge_done;
                }
                wr(hScratch00, (uint8_t)(s - 0x14));
                wr(0xC453 + rd(wMpStreamIdx), 0xB8);
                wr(wMpStreamIdx, rd(wMpStreamIdx) + 1);
            }
        }
        {                                   /* StoreMagicPointsDigit (the index is read once: the tiles may overwrite wMpStreamIdx itself) */
            uint8_t at = rd(wMpStreamIdx);
            for (int i = 0; i < 5; i++) wr(0xC453 + at + i, 0xB8);
            wr(wMpStreamIdx, rd(wMpStreamIdx) + 5);
        }
    }
gauge_done:
    wr(wMpStream, 0x10);
    wr(wMpStream + 1, 0x01);
    SET_HL(0x9CC2);
    SET_DE(wMpStream);
    NCALL(GAME_QueueVramCopyRows);
    NCALL(GAME_WaitVramCopyDone);
    NCALL(GAME_WaitVBlankFlag);
    r.a = 0xFF;
    NCALL(GAME_PlaySound);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    do {
        NCALL(GAME_WaitFrameAndSyncOam);
        uint8_t link = rd(hSerialByte);
        if ((link & 0x04) && ((link & 0x80) || (link & 0x08))) return (void *)GAME_GotoLinkLose;
        NCALL(GAME_ReadJoypad);
        wr(0xC769, rd(0xC769) + 1);
        NCALL(GAME_MagicScreenInput);
        NCALL(GAME_CursorBlinkStep);
    } while (!(rd(hJoyNew) & 0x02));
    wr(wMagicScreenFlags, rd(wMagicScreenFlags) & ~0x02);
    NCALL(GAME_LcdOff);
    ime = 0;
    NCALL(GAME_LoadGfxBank2);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    NCALL(GAME_ClearOamShadow);
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadowY);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    return (void *)GAME_StartRoundMusic;
}

/* SetCursorAnimation: HL = animation pointer of the card cursor object (wCursorObject +1/+2). SetCursorDefaultAnimation uses D_00_1a30. */
void *gb_native_SetCursorAnimation(void) {
    wr(wCursorObject + 1, r.l);
    wr(wCursorObject + 2, r.h);
    r.a = r.h;
    return 0;
}
void *gb_native_SetCursorDefaultAnimation(void) {
    SET_HL(0x1A30);
    return gb_native_SetCursorAnimation();
}
void *gb_native_ResetMagicCursorAnimation(void) {
    SET_HL(wMagicScreenFlags);
    wr(wMagicScreenFlags, rd(wMagicScreenFlags) & ~0x04);
    return gb_native_SetCursorDefaultAnimation();
}

/* CursorBlinkStep: while the cursor is active (wMagicScreenFlags bit 2) wCursorBlink counts to $50 (then the cursor is reset); in between the cursor
 * animation toggles between D_00_1a17 and D_00_1a30 with bit 2 of the screen frame counter $c769. */
void *gb_native_CursorBlinkStep(void) {
    r.a = rd(wMagicScreenFlags);
    r.f = (r.f & 0x10) | 0x20 | ((r.a & 4) ? 0 : 0x80);
    if (!(r.a & 4)) return 0;
    r.a = rd(wCursorBlink);
    if (r.a >= 0x50) return gb_native_ResetMagicCursorAnimation();
    r.a++;
    wr(wCursorBlink, r.a);
    r.a = rd(0xC769) & 0x04;
    if (r.a) return gb_native_SetCursorDefaultAnimation();
    SET_HL(0x1A17);
    return gb_native_SetCursorAnimation();
}

/* DrawMagicPage: draws the three cards of a row. hScratch00 = index of the first card in wMagicCards; for each card its name strip, picture and cost label
 * are queued as VRAM rows (columns 6 tiles apart) and waited for. */
void *gb_native_DrawMagicPage(void) {
    for (int i = 0; i < 3; i++) {
        if (i) wr(hScratch00, rd(hScratch00) + 1);
        r.c = rd(hScratch00);
        SET_HL(wMagicCards);
        gb_native_LookupByte();
        wr(hScratch00 + 2, r.a);
        static const uint16_t tables[3] = { DATA_MagicCardTitleJobs, DATA_MagicCardPictureJobs, DATA_MagicCardCostJobs };
        static const uint16_t base[3] = { 0x9D02, 0x9D42, 0x9DE2 };
        for (int t = 0; t < 3; t++) {
            r.a = rd(hScratch00 + 2);
            SET_HL(tables[t]);
            gb_native_LookupWord();
            SET_DE(HL());
            SET_HL(base[t] + 6 * i);
            NCALL(GAME_QueueVramCopyRows);
            if (i < 2 || t < 2) NCALL(GAME_WaitVramCopyDone); else return (void *)GAME_WaitVramCopyDone;
        }
    }
    return 0;
}

/* call a lifted routine that may end in a tail jump (it returns the routine to continue with) like a `call` would */
static void call_native(void *(*fn)(void)) {
    r.sp -= 2;
    void *next = fn();
    if (next) gb_run((fn_t)next); else r.sp += 2;
}

static uint8_t card_at(uint8_t index) { r.c = index; SET_HL(wMagicCards); gb_native_LookupByte(); return r.a; }
static uint8_t row_start(uint8_t row) { r.a = row; r.e = 3; gb_native_MultiplyByDE(); return rd(hScratch00); }

/* MagicCursorRight and MagicCursorLeft: move the card cursor (wMagicCol 0-2) when there is a card at the new place. */
void *gb_native_MagicCursorRight(void) {
    if (rd(wMagicCol) == 2) { wr(wMagicCol, 0); r.a = 0; return 0; }
    uint8_t first = row_start(rd(wMagicRow));
    uint8_t card = card_at((uint8_t)(rd(wMagicCol) + 1 + first));
    r.a = card;
    if (!card) return 0;
    SET_HL(wMagicCol);
    wr(wMagicCol, rd(wMagicCol) + 1);
    return 0;
}
void *gb_native_MagicCursorLeft(void) {
    uint8_t col = rd(wMagicCol);
    r.a = col;
    if (col) { SET_HL(wMagicCol); wr(wMagicCol, col - 1); return 0; }
    uint8_t first = row_start(rd(wMagicRow));
    uint8_t card = card_at(first + 2);
    r.a = card;
    if (!card) return 0;
    wr(wMagicCol, 2);
    r.a = 2;
    return 0;
}

/* MagicCursorUp and MagicCursorDown: move the card cursor between rows (wMagicRow 0-2) when there is a card below, and redraw the page (DrawMagicPage). */
void *gb_native_MagicCursorUp(void) {
    uint8_t row = rd(wMagicRow);
    if (!row) { wr(wMagicRow, 0); r.a = 0; return 0; }
    SET_HL(wMagicRow);
    wr(wMagicRow, row - 1);
    row_start(row - 1);
    return gb_native_DrawMagicPage();
}
void *gb_native_MagicCursorDown(void) {
    uint8_t row = rd(wMagicRow);
    r.a = row;
    if (row == 2) { wr(wMagicRow, 2); return 0; }
    uint8_t first = row_start(row + 1);
    uint8_t card = card_at((uint8_t)(rd(wMagicCol) + first));
    r.a = card;
    if (!card) return 0;
    SET_HL(wMagicRow);
    wr(wMagicRow, row + 1);
    row_start(rd(wMagicRow));
    return gb_native_DrawMagicPage();
}

/* MagicScreenInput: the pad on the magic screen. D-pad: sound, move the cursor (right 4, left 5, up 6, down 7 of hJoyNew; each routine leaves A as the original does and
 * the following tests read that A). A: the selected card is chosen when the magic points pay for it (cost in MagicCostTable): sound $90, wActiveMagic = the card,
 * wMagicScreenFlags |= 6, and the A bit is removed from hJoyNew. Then the cursor object is placed at the column (D_00_2630) and drawn. */
void *gb_native_MagicScreenInput(void) {
    if (!(rd(wMagicScreenFlags) & 0x02)) {
        uint8_t pad = rd(hJoyNew) & 0xF1;
        if (pad) {
            if (pad & 0x01) {
                uint8_t card = card_at((uint8_t)(rd(wMagicCol) + row_start(rd(wMagicRow))));
                uint8_t cost = rd(DATA_MagicCostTable + card);
                if (rd(wMagicPoints) < cost && rd(wMagicPointsHi) == 0) {
                    wr(wMagicScreenFlags, rd(wMagicScreenFlags) & ~0x04);
                    return 0;
                }
                r.a = SND_SFX_90;
                NCALL(GAME_PlaySound);
                card = card_at((uint8_t)(rd(wMagicCol) + row_start(rd(wMagicRow))));
                wr(wActiveMagic, card);
                wr(wMagicScreenFlags, rd(wMagicScreenFlags) | 0x06);
                wr(hJoyNew, rd(hJoyNew) & ~0x80);
            } else {
                r.a = SND_SFX_CURSOR;
                NCALL(GAME_PlaySound);
                r.a = rd(hJoyNew);
                if (r.a & 0x10) gb_native_MagicCursorRight();
                if (r.a & 0x20) gb_native_MagicCursorLeft();
                if (r.a & 0x40) call_native(gb_native_MagicCursorUp);
                if (r.a & 0x80) call_native(gb_native_MagicCursorDown);
            }
        }
        r.c = rd(wMagicCol);
        SET_HL(0x2630);
        gb_native_LookupByte();
        wr(wCursorX, r.a);
    }
    SET_HL(wCursorObject);
    gb_native_SetObjPtr();
    return (void *)GAME_DrawObjectBytePos;
}

/* The timed cards S.UP (1, $f0 frames), W.IN (2, $d0), T.STOP (3, $d0), GHOST (4, $b0) and FRIEND (5, $b0): on the first frame of a cast (wMagicState bit 1 clear)
 * the timer hMagicTimer is set and the cast starts (BeginMagicCast); T.STOP and FRIEND also remove the enemy projectile; W.IN clears wPlayerBlocked every frame
 * (so walls do not stop the player). Every frame MagicTimerTick counts the timer down. The effects of the cards themselves are made by the checks elsewhere
 * (the player speed for S.UP, the touch checks for GHOST, the enemy behaviours for T.STOP and so on). */
static void *magic_timed(uint8_t frames, int remove_projectile, int clear_blocked) {
    if (!(rd(wMagicState) & 0x02)) {
        wr(hMagicTimer, frames);
        NCALL(GAME_BeginMagicCast);
        if (remove_projectile) wr(wProjectile, rd(wProjectile) & 0x7F);
    }
    if (clear_blocked) wr(wPlayerBlocked, 0);
    return (void *)GAME_MagicTimerTick;
}
void *gb_native_MagicEffectSUp(void) { return magic_timed(0xF0, 0, 0); }
void *gb_native_MagicEffectWIn(void) { return magic_timed(0xD0, 0, 1); }
void *gb_native_MagicEffectTStop(void) { return magic_timed(0xD0, 1, 0); }
void *gb_native_MagicEffectGhost(void) { return magic_timed(0xB0, 0, 0); }
void *gb_native_MagicEffectFriend(void) { return magic_timed(0xB0, 1, 0); }

/* SelectBlobAnimation: the paint blob alternates between two animations ($492b and $492d) with bit 1 of its phase counter. */
void *gb_native_SelectBlobAnimation(void) {
    uint16_t anim = (rd(wBlobPhase) & 0x02) ? 0x492B : 0x492D;
    wr(wPaintAnimLo, (uint8_t)anim);
    wr(wPaintAnimHi, anim >> 8);
    r.a = anim >> 8;
    return 0;
}

/* MagicEffectPyon: card 9 PYON: a paint blob object is created at the player (SpawnPaintBlob) and then, every frame, it is moved (MoveObject, ApplyObjectStep),
 * painted by MagicPaintEndUnlessBit2, drawn, and removed when it leaves the screen (EnemyScreenPosition of the player is checked: not of the blob). */
void *gb_native_MagicEffectPyon(void) {
    if (!(rd(wMagicState) & 0x02)) NCALL(GAME_SpawnPaintBlob);
    SET_HL(wPaintObject);
    gb_native_SetObjPtr();
    wr(wBlobPhase, rd(wBlobPhase) + 1);
    NCALL(GAME_MagicPaintEndUnlessBit2);
    r.c = rd(wPlayerX);
    r.b = rd(wPlayerY);
    gb_native_EnemyScreenPosition();
    if (r.a) wr(wPaintObject, rd(wPaintObject) & 0x7F);
    gb_native_SelectBlobAnimation();
    gb_native_MoveObject();
    gb_native_ApplyObjectStep();
    gb_native_DrawObject();
    return 0;
}

/* MagicEffectBom: card 7 B.O.M: a paint blob trail of 8 segments (wTrailIdx 0-7) is advanced each frame: every segment is loaded into the paint object,
 * moved, drawn and stored back; at the end of the frame the timer counts down (MagicTimerCountdown). */
void *gb_native_MagicEffectBom(void) {
    if (!(rd(wMagicState) & 0x02)) {
        NCALL(GAME_SpawnBombBlob);
        NCALL(GAME_BombHitAllEnemies);
    }
    for (;;) {
        NCALL(GAME_LoadTrailSegment);
        SET_HL(wPaintObject);
        gb_native_SetObjPtr();
        gb_native_MoveObject();
        gb_native_ApplyObjectStep();
        gb_native_DrawObject();
        NCALL(GAME_StoreTrailSegment);
        NCALL(GAME_SetPaintBlobAnimation);
        wr(0xC449, rd(0xC449) - 1);
        if (rd(0xC449) == 0) break;
        wr(wTrailIdx, rd(wTrailIdx) + 1);
    }
    NCALL(GAME_MagicTimerCountdown);
    wr(0xC449, 0x08);
    wr(wTrailIdx, 0);
    return 0;
}

void *gb_native_MagicEffectSealed(void) { return magic_timed(0xA0, 0, 0); }

/* MagicTimerTick: counts hMagicTimer down; at zero the effect ends (EndMagic: wMagicState = 0). */
void *gb_native_MagicTimerTick(void) {
    SET_HL(hMagicTimer);
    wr(hMagicTimer, dec8(rd(hMagicTimer)));
    if (rd(hMagicTimer)) return 0;
    wr(wMagicState, 0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* SpawnPaintBlob: creates the paint blob object (wPaintObject) for the PYON card at the player's position: flags $86, animation $492b, heading and fixed point
 * position copied from the player, speed $20, box size 1; plays sound $8d, sets the timer $d0 and wMagicState bits 4 and 1. */
void *gb_native_SpawnPaintBlob(void) {
    SET_HL(wPaintObject);
    gb_native_Clear32Bytes();
    wr(wPaintAnimLo, 0x2B);
    wr(wPaintAnimHi, 0x49);
    wr(wPaintObject + 0x11, 0x20);
    wr(wPaintObject + 0x10, rd(wPlayerAngle));
    wr(wPaintObject, 0x86);
    wr(wPaintObject + 6, rd(wPlayer + 6));
    wr(wPaintObject + 7, rd(wPlayerX));
    wr(wPaintObject + 8, rd(wPlayer + 8));
    wr(wPaintObject + 9, rd(wPlayer + 9));
    wr(wPaintObject + 10, rd(wPlayerY));
    wr(wPaintObject + 11, rd(wPlayer + 11));
    wr(wPaintObject + 4, 0x01);
    r.a = SND_SFX_8D;
    NCALL(GAME_PlaySound);
    wr(hMagicTimer, 0xD0);
    SET_HL(wMagicState);
    wr(wMagicState, rd(wMagicState) | 0x12);
    return 0;
}

/* MagicEffectClear: card 8 CLEAR: for $50 frames the background palette flashes; then every unpainted path cell (bit 7 set in the map) is painted at once
 * (tile updates queued; wPaintRemaining counts down and the round is cleared when it hits 0) and the effect ends. */
void *gb_native_MagicEffectClear(void) {
    if (!(rd(wMagicState) & 0x02)) {
        wr(0xC1F8, 0);
        NCALL(GAME_BeginMagicCast);
    }
    wr(wBlobPhase, rd(wBlobPhase) + 1);
    uint8_t step = rd(0xC1F8);
    if (step != 0x50) {
        wr(0xC1F8, step + 1);
        wr(rBGP, PAL_NORMAL);
        if (rd(wBlobPhase) & 0x02) return 0;
        wr(rBGP, 0);
        return 0;
    }
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    for (int cell = 0xFF; cell >= 0; cell--) {
        uint8_t tile = rd(wRoomMap + cell);
        if (!(tile & 0x80)) continue;
        tile = (tile & 0x0F) | 0x10;
        wr(wRoomMap + cell, tile);
        wr(hScratch00 + 2, tile);
        SET_BC(cell);
        NCALL(GAME_MapCellToVramAddr);
        NCALL(GAME_QueueCellTileRows);
        wr(wPaintRemaining, rd(wPaintRemaining) - 1);
        if (rd(wPaintRemaining) == 0) return (void *)GAME_RoundCleared;
    }
    return (void *)GAME_EndMagic;
}

/* The B.O.M card sends eight paint blobs out in the eight headings. Their state is kept in 8 trail segments of 7 bytes at $c1b7: X fraction, X pixel, X high,
 * Y fraction, Y pixel, Y high, heading. LoadTrailSegment / StoreTrailSegment copy segment wTrailIdx to / from the paint object (wPaintObject +6 to +$b, heading +$10). */
#define TRAIL 0xC1B7

void *gb_native_LoadTrailSegment(void) {
    r.a = rd(wTrailIdx);
    r.e = 7;
    gb_native_MultiplyByDE();
    uint16_t seg = TRAIL + r.a;
    for (int i = 0; i < 6; i++) wr(wPaintObject + 6 + i, rd(seg + i));
    wr(wPaintObject + 0x10, rd(seg + 6));
    return 0;
}

void *gb_native_StoreTrailSegment(void) {
    r.a = rd(wTrailIdx);
    r.e = 7;
    gb_native_MultiplyByDE();
    uint16_t seg = TRAIL + r.a;
    for (int i = 0; i < 6; i++) wr(seg + i, rd(wPaintObject + 6 + i));
    return 0;
}

/* InitTrailSegment: HL = segment, A = heading, D and E = offsets of X and Y from the player. */
void *gb_native_InitTrailSegment(void) {
    uint16_t seg = HL();
    wr(seg + 6, r.a);
    wr(seg + 1, (uint8_t)(rd(wPlayerX) + r.d));
    wr(seg + 4, (uint8_t)(rd(wPlayerY) + r.e));
    return 0;
}

/* InitTrailSegments: clears the 8 segments and places them around the player: offsets (x, y) and headings of the eight blobs. */
void *gb_native_InitTrailSegments(void) {
    SET_BC(0x0040);
    SET_HL(TRAIL);
    gb_native_ClearMemory();
    static const struct { uint8_t dx, dy, heading; } blobs[8] = {
        {0x10, 0x00, 0x08}, {0x10, 0xF0, 0x04}, {0x00, 0xF0, 0x00}, {0xF0, 0x00, 0x1C},
        {0xF0, 0x00, 0x18}, {0xF0, 0x10, 0x14}, {0x00, 0x10, 0x10}, {0x10, 0x10, 0x0C},
    };
    for (int i = 0; i < 8; i++) {
        SET_HL(TRAIL + 7 * i);
        r.d = blobs[i].dx;
        r.e = blobs[i].dy;
        r.a = blobs[i].heading;
        gb_native_InitTrailSegment();
    }
    return 0;
}

/* BombHitAllEnemies (B.O.M card): every active enemy slot (16 slots through EnemySlotTable) gets bit 2 of its flags byte (+$1f: hit by paint) and its counter
 * (+$14) cleared, so the enemies are all defeated by their own update. */
void *gb_native_BombHitAllEnemies(void) {
    for (int i = 15; i >= 0; i--) {
        wr(hScratch00, i);
        uint16_t slot = rd(DATA_EnemySlotTable + 2 * i) | rd(DATA_EnemySlotTable + 2 * i + 1) << 8;
        if (rd(slot) & 0x80) {
            wr(slot + 0x1F, rd(slot + 0x1F) | 0x04);
            wr(slot + 0x14, 0);
        }
    }
    wr(hScratch00, 0xFF);
    return 0;
}

/* EndMagicPaint: removes the paint blob object and clears bits of wMagicState: bits 0-2 for the PYON card (9), all but bit 3 for the others. */
void *gb_native_EndMagicPaint(void) {
    SET_HL(wPaintObject);
    wr(wPaintObject, rd(wPaintObject) & 0x7F);
    if (rd(wActiveMagic) == 0x09) wr(wMagicState, rd(wMagicState) & 0xF8);
    else wr(wMagicState, rd(wMagicState) & 0x08);
    r.a = rd(wMagicState);
    r.f = 0;
    r.f = (r.a ? 0 : 0x80) | 0x20;
    return 0;
}

/* MagicPaintEndUnlessBit2: ends the paint (EndMagicPaint) unless the paint object has bit 2 (drawn this frame) set. */
void *gb_native_MagicPaintEndUnlessBit2(void) {
    r.a = rd(wPaintObject);
    r.f = (r.f & 0x10) | 0x20 | ((r.a & 4) ? 0 : 0x80);
    if (r.a & 4) return 0;
    return gb_native_EndMagicPaint();
}

/* MagicTimerCountdown: counts hMagicTimer down; at zero wMagicState is cleared and the paint ended. */
void *gb_native_MagicTimerCountdown(void) {
    r.a = rd(hMagicTimer);
    alu_sub(1, 0);
    wr(hMagicTimer, r.a);
    if (r.a) return 0;
    wr(wMagicState, 0);
    r.a = 0;
    r.f = 0x80;
    return gb_native_EndMagicPaint();
}

/* SpawnBombBlob: creates the paint blob object for the B.O.M card (flags $82, animation $4929, speed $2a), the timer 7, wPlayerStatus bit 4, places the trail
 * segments around the player and starts the cast. */
void *gb_native_SpawnBombBlob(void) {
    SET_HL(wPaintObject);
    gb_native_Clear32Bytes();
    wr(0xC1F7, 0x08);
    wr(hMagicTimer, 0x07);
    wr(wPlayerStatus, rd(wPlayerStatus) | 0x10);
    wr(wPaintObject + 0x11, 0x2A);
    wr(wPaintAnimLo, 0x29);
    wr(wPaintAnimHi, 0x49);
    wr(0xC449, 0x08);
    wr(wPaintObject, 0x82);
    gb_native_InitTrailSegments();
    return (void *)GAME_BeginMagicCast;
}

/* ---- the sound engine ----
 * A channel record is $20 bytes (wSoundChannels, 8 records): +0 flags (bit 7 in use, 4 paused, 2 effect has the channel, bit 0 restart note), +1 hardware channel
 * (0 pulse 1, 1 pulse 2, 2 wave, 3 noise), +2 pan mask for NR51, +3/+4 stream pointer, +7 envelope, +8..+$d note timing, +$12/+$13 frequency, +$15 duty.
 * The writers send a register only when its value changed (the shadows wShadowNR..) except for the restart of a note (flags bit 0). */

static uint16_t rec_of_bc(void) { return BC(); }

void *gb_native_SoundSilenceChannel1(void) { wr(rNR13, 0xFF); wr(wShadowNR13, 0xFF); wr(rNR14, 0x87); wr(wShadowNR14, 0x87); return 0; }
void *gb_native_SoundSilenceChannel2(void) { wr(rNR23, 0xFF); wr(wShadowNR23, 0xFF); wr(rNR24, 0x87); wr(wShadowNR24, 0x87); return 0; }
void *gb_native_SoundSilenceChannel3(void) { wr(rNR33, 0xFF); wr(wShadowNR33, 0xFF); wr(rNR34, 0x07); wr(wShadowNR34, 0x07); return 0; }
void *gb_native_SoundSilenceChannel4(void) { wr(rNR43, 0xFF); wr(wShadowNR43, 0xFF); wr(rNR44, 0x80); return 0; }

/* the two pulse channels differ only in their registers */
static void *write_pulse(uint16_t rec, uint16_t nr1, uint16_t nr2, uint16_t nr3, uint16_t nr4,
                         uint16_t sh2, uint16_t sh3, uint16_t sh4, uint8_t pan, void *(*silence)(void)) {
    wr(nr1, rd(rec + 0x15) & 0xC0);
    uint8_t env = rd(rec + 7);
    if (rd(sh2) != env) { wr(sh2, env); wr(nr2, env); }
    uint8_t lo = rd(rec + 0x12), hi = rd(rec + 0x13);
    if (!(lo | hi)) return silence();
    wr(rNR51, (rd(rNR51) | pan) & rd(rec + 2));
    int restart = rd(rec) & 0x01;
    if (!restart && rd(sh3) == lo && rd(sh4) == hi) return 0;
    wr(nr3, lo);
    wr(sh3, lo);
    wr(sh4, hi);
    uint8_t arg = (hi & 0x07) | 0x80;
    if (!restart) arg &= 0x7F;
    wr(wSoundArg, arg);
    wr(rec, rd(rec) & 0xFE);
    wr(nr4, arg);
    return 0;
}
void *gb_native_SoundWriteChannel1(void) {
    return write_pulse(rec_of_bc(), rNR11, rNR12, rNR13, rNR14, wShadowNR12, wShadowNR13, wShadowNR14, 0x11, gb_native_SoundSilenceChannel1);
}
void *gb_native_SoundWriteChannel2(void) {
    return write_pulse(rec_of_bc(), rNR21, rNR22, rNR23, rNR24, wShadowNR22, wShadowNR23, wShadowNR24, 0x22, gb_native_SoundSilenceChannel2);
}

void *gb_native_SoundWriteChannel3(void) {
    uint16_t rec = rec_of_bc();
    uint8_t lo = rd(rec + 0x12), hi = rd(rec + 0x13);
    if (!(lo | hi)) return gb_native_SoundSilenceChannel3();
    uint8_t level = rd(rec + 7);
    if (rd(wShadowNR32) != level) { wr(wShadowNR32, level); wr(rNR32, level & 0x60); }
    wr(rNR51, (rd(rNR51) | 0x44) & rd(rec + 2));
    if (rd(wShadowNR33) == lo && rd(wShadowNR34) == hi) return 0;
    wr(rNR33, lo);
    wr(wShadowNR33, lo);
    wr(wShadowNR34, hi);
    uint8_t arg = hi & 0x07;
    wr(wSoundArg, arg);
    wr(rNR34, arg);
    return 0;
}

void *gb_native_SoundWriteChannel4(void) {
    uint16_t rec = rec_of_bc();
    uint8_t env = rd(rec + 7);
    if (rd(wShadowNR42) != env) { wr(wShadowNR42, env); wr(rNR42, env); }
    uint8_t poly = rd(rec + 0x12);
    if (!poly) return gb_native_SoundSilenceChannel4();
    wr(rNR51, (rd(rNR51) | 0x88) & rd(rec + 2));
    if (rd(wShadowNR43) == poly) return 0;
    wr(rNR43, poly);
    wr(wShadowNR43, poly);
    uint8_t arg = (rd(rec) & 0x01) ? 0x00 : 0x80;       /* the noise channel is retriggered when the restart bit is clear */
    wr(wSoundArg, arg);
    wr(rec, rd(rec) & 0xFE);
    wr(rNR44, arg);
    return 0;
}

/* SoundLoadWave: A = wave pattern number. Copies the 16 byte pattern (pointer table at $3fb8) into wave RAM ($ff30-$ff3f) with the wave channel switched off, then SoundInit. */
static void load_wave(uint8_t pattern) {
    wr(rNR30, 0);
    uint16_t source = rd(0x3FB8 + 2 * pattern) | rd(0x3FB8 + 2 * pattern + 1) << 8;
    for (int i = 0; i < 16; i++) wr(0xFF30 + i, rd(source + i));
    wr(rNR30, 0x80);
    uint16_t bc = BC();
    NCALL_VOID(GAME_SoundInit);
    SET_BC(bc);
}

/* ends the stream of a record: its flags become the given value and the hardware channel it used is silenced */
static void silence_record(uint16_t rec, uint8_t flags) {
    wr(rec, flags);
    switch (rd(rec + 1)) {
    case 3: gb_native_SoundSilenceChannel4(); break;
    case 2: gb_native_SoundSilenceChannel3(); break;
    case 1: gb_native_SoundSilenceChannel2(); break;
    case 0: gb_native_SoundSilenceChannel1(); break;
    }
}

/* The stream interpreter. The stream pointer is the record's +3/+4. Tokens: $e0-$f1 commands (see below), $80-$df notes (frequency from SoundFrequencyTable
 * with the transpose +5 added; $80 is a rest), $00-$7f lengths. A note sets the pitch (+$e/+$f, copied to +$10/+$11) and, with flag bit 5, reads a duty byte (+$14);
 * a length byte after it sets +$b; the pointer is stored back and the length counter +$c restarts. Commands: $e0 $e1 call (small stack at +$a), $e2 return, $e3 stop,
 * $e4 counted repeat, $e5 jump, $e6 envelope (+7), $e7 transpose (+5), $e8 duty (+$15), $e9 pan (+2), $ea wave pattern, $eb end (also ends the update of the record),
 * $ec/$ed mute on/off (flag bit 5), $ee clear flag bit 0, $ef master volume (NR50), $f0 field +6, $f1 pitch (+$e).
 * Returns 1 when a command ended the stream ($e3 stop or $eb end: both silence the channel and abandon the update of the record). */
static int sound_parse(uint16_t rec, uint16_t de) {
    for (;;) {
        uint8_t token = rd(de++);
        if (token >= 0xE0) {
            switch (token & 0x1F) {
            case 0x00: case 0x01: {                 /* call: push the return address (after the 2 operand bytes) on the small stack of the record */
                uint8_t sp = rd(rec + 0x0A);
                wr(rec + 0x0A, sp - 2);
                wr(rec + (uint8_t)(sp - 1), (de + 2) >> 8);
                wr(rec + (uint8_t)(sp - 2), (uint8_t)(de + 2));
                uint16_t target = rd(de) | rd(de + 1) << 8;
                wr(rec + 3, (uint8_t)target);
                wr(rec + 4, target >> 8);
                de = target;
                break;
            }
            case 0x02: {                            /* return */
                uint8_t sp = rd(rec + 0x0A);
                wr(rec + 0x0A, sp + 2);
                de = rd(rec + sp) | rd(rec + (uint8_t)(sp + 1)) << 8;
                wr(rec + 3, (uint8_t)de);
                wr(rec + 4, de >> 8);
                break;
            }
            case 0x03:                              /* stop */
                wr(wMusicPriority, 0);
                silence_record(rec, 0);
                return 1;
            case 0x04: {                            /* counted repeat: operands counter slot, count, jump target */
                uint16_t counter = rec + 0x17 + rd(de++);
                if (rd(counter) == 0) wr(counter, rd(de));
                de++;
                wr(counter, rd(counter) - 1);
                if (rd(counter) == 0) { de += 2; break; }
                uint16_t target = rd(de) | rd(de + 1) << 8;       /* otherwise it jumps */
                wr(rec + 3, (uint8_t)target);
                wr(rec + 4, target >> 8);
                de = target;
                break;
            }
            case 0x05: {                            /* jump */
                uint16_t target = rd(de) | rd(de + 1) << 8;
                wr(rec + 3, (uint8_t)target);
                wr(rec + 4, target >> 8);
                de = target;
                break;
            }
            case 0x06: wr(rec + 0x07, rd(de++)); break;
            case 0x07: wr(rec + 0x05, rd(de++) + rd(rec + 0x05)); break;
            case 0x08: wr(rec + 0x15, rd(de++)); break;
            case 0x09: wr(rec + 0x02, rd(de++)); break;
            case 0x0A:                              /* wave pattern */
                if (rd(rec) & 0x04) { wr(wWavePending, rd(de++)); break; }
                {
                    uint8_t pattern = rd(de++);
                    if (pattern == rd(wWaveCurrent)) break;
                    wr(wWaveCurrent, pattern);
                    if ((uint8_t)(rec - wSoundChannels) < 0x60) wr(wWavePending, pattern);
                    else wr(wWaveEffect, pattern);
                    load_wave(pattern);
                }
                break;
            case 0x0B:                              /* end */
                wr(wEffectPriority, 0);
                if (rd(wWavePending) != rd(wWaveCurrent)) { wr(wWaveCurrent, rd(wWavePending)); load_wave(rd(wWaveCurrent)); }
                silence_record(rec, 0);
                return 1;
            case 0x0C: wr(rec, rd(rec) | 0x20); break;
            case 0x0D: wr(rec, rd(rec) & 0xDF); break;
            case 0x0E: wr(rec, rd(rec) & 0xFE); break;
            case 0x0F: { uint8_t v = rd(de++); wr(rNR50, v); wr(wSoundMasterVol, v); break; }
            case 0x10: wr(rec + 0x06, rd(de++)); break;
            case 0x11: wr(rec + 0x0E, rd(de++)); break;
            }
            continue;
        }
        if (token & 0x80) {                         /* note */
            if (token != 0x80) token += rd(rec + 5);
            uint16_t freq = DATA_SoundFrequencyTable + (uint8_t)(token << 1);
            wr(rec + 0x0E, rd(freq));
            wr(rec + 0x0F, rd(freq + 1));
            wr(rec + 0x10, rd(rec + 0x0E));
            wr(rec + 0x11, rd(rec + 0x0F));
            if (rd(rec) & 0x20) wr(rec + 0x14, rd(de++));
            uint8_t next = rd(de);
            if (!(next & 0x80)) { de++; wr(rec + 0x0B, next); }
        } else {
            wr(rec + 0x0B, token);                  /* a length alone */
        }
        wr(rec + 3, (uint8_t)de);
        wr(rec + 4, de >> 8);
        wr(rec + 0x0C, 0);
        return 0;
    }
}

/* SoundReadNextNote: BC = record. Sets flag bit 0 (a note starts) and runs the stream interpreter from the record's stream pointer. */
void *gb_native_SoundReadNextNote(void) {
    uint16_t rec = rec_of_bc();
    wr(rec, rd(rec) | 0x01);
    if (sound_parse(rec, rd(rec + 3) | rd(rec + 4) << 8)) { r.sp += 2; return 0; }
    return 0;
}

/* SoundUpdateChannel: one record. Paused (bit 4): nothing. The note timer adds +9 to +8; on overflow the length counter +$c counts up and when it reaches +$b
 * the next note is read (SoundReadNextNote; with bit 0 set the vibrato counter +$d restarts). Unless an effect has taken the channel (bit 2) the pitch slide runs
 * and the registers of the record's hardware channel are written. */
void *gb_native_SoundUpdateChannel(void) {
    uint16_t rec = rec_of_bc();
    if (rd(rec) & 0x10) return 0;
    unsigned sum = rd(rec + 8) + rd(rec + 9);
    wr(rec + 9, sum);
    if (sum > 0xFF) {
        uint8_t length = rd(rec + 0x0C) + 1;
        wr(rec + 0x0C, length);
        if (rd(rec + 0x0B) == length) {
            wr(rec, rd(rec) | 0x01);
            if (sound_parse(rec, rd(rec + 3) | rd(rec + 4) << 8)) return 0;
            if (rd(rec) & 0x01) wr(rec + 0x0D, 0);
        }
    }
    if (rd(rec) & 0x04) return 0;
    SET_BC(rec);
    NCALL(GAME_SoundApplyPitchSlide);
    switch (rd(rec + 1)) {
    case 3: return gb_native_SoundWriteChannel4();
    case 2: return gb_native_SoundWriteChannel3();
    case 1: return gb_native_SoundWriteChannel2();
    case 0: return gb_native_SoundWriteChannel1();
    }
    return 0;
}

/* SoundAddSigned16: the 16 bit word at record + off plus the signed byte in wSoundTmp; the sum is stored at +$12/+$13 (the frequency) and returned in DE. */
static uint16_t sound_add_signed16(uint16_t rec, uint16_t off) {
    uint16_t sum = (uint16_t)((rd(rec + off) | rd(rec + off + 1) << 8) + (int8_t)rd(wSoundTmp));
    wr(rec + 0x12, (uint8_t)sum);
    wr(rec + 0x13, sum >> 8);
    SET_DE(sum);
    return sum;
}

/* SoundPitchSlideStep: the signed slide byte in +$14 is added to the pitch word at +$10. */
void *gb_native_SoundPitchSlideStep(void) {
    uint16_t rec = rec_of_bc();
    wr(wSoundTmp, rd(rec + 0x14));
    uint16_t sum = sound_add_signed16(rec, 0x10);
    wr(rec + 0x11, sum >> 8);
    wr(rec + 0x10, (uint8_t)sum);
    return 0;
}

/* SoundSetFrequency: the pitch envelope of the record (table number in +6, pointer table SoundPitchTables, position in +$d): each step byte is a signed change of
 * the frequency (+$12/+$13); $80 restarts the envelope, $81 steps back two, $82 steps back one and stops, $83 jumps to the position given by the next byte. */
void *gb_native_SoundSetFrequency(void) {
    uint16_t rec = rec_of_bc();
    for (;;) {
        uint16_t table = rd(DATA_SoundPitchTables + 2 * rd(rec + 6)) | rd(DATA_SoundPitchTables + 2 * rd(rec + 6) + 1) << 8;
        uint8_t pos = rd(rec + 0x0D);
        wr(rec + 0x0D, pos + 1);
        uint8_t step = rd(table + pos);
        wr(wSoundTmp, step);
        if (step == 0x80) wr(rec + 0x0D, 0);
        else if (step == 0x81) wr(rec + 0x0D, rd(rec + 0x0D) - 2);
        else if (step == 0x82) { wr(rec + 0x0D, rd(rec + 0x0D) - 1); return 0; }
        else if (step == 0x83) wr(rec + 0x0D, rd(table + pos + 1));
        else { sound_add_signed16(rec, 0x12); return 0; }
    }
}

/* SoundApplyPitchSlide: copies the pitch word (+$e/+$f) to the frequency (+$12/+$13); when it is not 0, the slide (flag bit 5) and the pitch envelope (+6 not 0) apply. */
void *gb_native_SoundApplyPitchSlide(void) {
    uint16_t rec = rec_of_bc();
    wr(rec + 0x13, rd(rec + 0x0F));
    wr(rec + 0x12, rd(rec + 0x0E));
    if (!(rd(rec + 0x0E) | rd(rec + 0x0F))) return 0;
    if (rd(rec) & 0x20) gb_native_SoundPitchSlideStep();
    if (rd(rec + 6)) gb_native_SoundSetFrequency();
    return 0;
}

/* PlaySound_Bank1: appends wSoundArg to the sound command queue (wSoundBusy is set while the queue changes); HL and DE are kept. */
void *gb_native_PlaySound_Bank1(void) {
    wr(wSoundBusy, 1);
    uint8_t len = rd(wSoundQueueLen);
    wr(wSoundQueueLen, len + 1);
    wr(wSoundQueue + len, rd(wSoundArg));
    wr(wSoundBusy, 0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* SoundClearRegisterShadow: zeroes the register shadows ($c427-$c432) so every register is written again. */
void *gb_native_SoundClearRegisterShadow(void) {
    for (int i = 0; i < 12; i++) wr(wShadowNR12 + i, 0);
    r.a = 0;
    return 0;
}

/* SoundInit: puts the sound registers in their starting state (wave channel off, no panning, envelopes $f0, frequencies $ff, master volume, retrigger); it continues
 * into SoundClearRegisterShadow. */
void *gb_native_SoundInit(void) {
    wr(rNR30, 0x00);
    wr(rNR51, 0x00);
    wr(rNR10, 0x08);
    wr(rNR12, 0xF0);
    wr(rNR22, 0xF0);
    wr(rNR42, 0xF0);
    wr(rNR30, 0x80);
    wr(rNR13, 0xFF);
    wr(rNR23, 0xFF);
    wr(rNR33, 0xFF);
    wr(rNR43, 0xFF);
    wr(rNR50, rd(wSoundMasterVol));
    wr(rNR14, 0x87);
    wr(rNR24, 0x87);
    wr(rNR34, 0x87);
    wr(rNR44, 0x87);
    return gb_native_SoundClearRegisterShadow();
}

/* SoundClearChannels: all eight records are freed, the master volume is $77, then SoundInit. */
void *gb_native_SoundClearChannels(void) {
    for (int i = 0; i < 8; i++) wr(wSoundChannels + 0x20 * i, 0);
    wr(wSoundMasterVol, 0x77);
    return gb_native_SoundInit();
}

void *gb_native_SoundRequestStop(void) {
    wr(wSoundCmd, 0x80);
    r.a = 0x80;
    return 0;
}

/* SoundLoadStream: HL = first record, DE = song data: a count of channels, then per channel a 10 byte header that becomes the start of a record; the rest of the record is
 * set up ($20 in +$a: empty call stack, 1 in +$b, zeros after). Ends by setting wSoundCmd to $80. */
static void load_stream(uint16_t rec, uint16_t de) {
    uint8_t count = rd(de++);
    wr(wSoundTmp, count);
    do {
        for (int i = 0; i < 10; i++) wr(rec + i, rd(de++));
        wr(rec + 10, 0x20);
        wr(rec + 11, 0x01);
        for (int i = 12; i < 32; i++) wr(rec + i, 0);
        rec += 0x20;
        count--;
        wr(wSoundTmp, count);
    } while (count);
    wr(wSoundCmd, 0x80);
}
void *gb_native_SoundLoadStream(void) {
    load_stream(HL(), DE());
    r.a = 0x80;
    return 0;
}

/* SoundStartMusicNow: music accepted: B = its priority (wMusicPriority); all channels are cleared and the music records get the stream at DE. */
static void start_music_now(uint8_t priority, uint16_t data) {
    wr(wMusicPriority, priority);
    gb_native_SoundClearChannels();
    for (int i = 0; i < 4; i++) wr(wSoundChannels + 0x20 * i, 0);
    load_stream(wSoundChannels, data);
}
void *gb_native_SoundStartMusicNow(void) {
    start_music_now(r.b, DE());
    return 0;
}

/* SoundStartMusic: BC = song id (index into the priority table at $4141): replaces the playing music when its priority is lower or equal, else the request is dropped. */
void *gb_native_SoundStartMusic(void) {
    uint8_t priority = rd(0x4141 + BC());
    r.b = priority;
    uint8_t playing = rd(wMusicPriority);
    if (playing > priority) return gb_native_SoundRequestStop();
    start_music_now(priority, DE());
    return 0;
}

/* SoundStartEffect: BC = effect id: same rules with wEffectPriority; the effect uses the records 4-7. */
void *gb_native_SoundStartEffect(void) {
    uint8_t priority = rd(0x4141 + BC());
    r.b = priority;
    if (rd(wEffectPriority) > priority) return gb_native_SoundRequestStop();
    wr(wEffectPriority, priority);
    gb_native_SoundClearRegisterShadow();
    for (int i = 4; i < 8; i++) wr(wSoundChannels + 0x20 * i, 0);
    load_stream(wSoundChan4, DE());
    return 0;
}

/* SoundPauseMusicChannels and SoundResumeMusicChannels: set or clear the pause flag (bit 4) of the music records 0-3 around an effect, then start the effect. */
void *gb_native_SoundPauseMusicChannels(void) {
    wr(wEffectPriority, rd(wEffectPriority) + 1);
    for (int i = 0; i < 4; i++) wr(wSoundChannels + 0x20 * i, rd(wSoundChannels + 0x20 * i) | 0x10);
    return gb_native_SoundStartEffect();
}
void *gb_native_SoundResumeMusicChannels(void) {
    gb_native_SoundClearRegisterShadow();
    wr(wEffectPriority, rd(wEffectPriority) + 1);
    for (int i = 0; i < 4; i++) wr(wSoundChannels + 0x20 * i, rd(wSoundChannels + 0x20 * i) & 0xEF);
    return gb_native_SoundStartEffect();
}

/* SoundAssignChannels: music records that an effect record (4-7, in use) has taken the hardware channel of get flag bit 2 (their registers are not written). */
void *gb_native_SoundAssignChannels(void) {
    for (int i = 0; i < 4; i++) wr(wSoundChannels + 0x20 * i, rd(wSoundChannels + 0x20 * i) & 0xFB);
    wr(wSoundArg, 4);
    for (int i = 0; i < 4; i++) {
        uint16_t effect = wSoundChan4 + 0x20 * i;
        if (rd(effect) & 0x80) {
            uint16_t music = wSoundChannels + 0x20 * rd(effect + 1);
            wr(music, rd(music) | 0x04);
        }
        if (i < 3) wr(wSoundArg, rd(wSoundArg) - 1);       /* the counter is not stored on the last pass (it stays 1) */
    }
    return 0;
}

/* SoundStartCommand: wSoundCmd $81-$93 start song or effect number cmd - $80: its data (SoundCommandDataTable) in DE, its handler (SoundCommandHandlerTable, one of
 * SoundStartMusic, SoundStartEffect and the pause and resume variants) is run with BC = number. $80 and below do nothing; above $93 the default data $4332 is played as music. */
void *gb_native_SoundStartCommand(void) {
    uint8_t cmd = rd(wSoundCmd);
    if (!(cmd & 0x80)) return 0;
    if (cmd >= 0x94) {
        SET_DE(0x4332);
        r.b = 0;
        return gb_native_SoundStartMusicNow();
    }
    uint8_t id = cmd - 0x80;
    if (id == 0) return 0;
    SET_BC(id);
    SET_DE(rd(DATA_SoundCommandDataTable + 2 * id) | rd(DATA_SoundCommandDataTable + 2 * id + 1) << 8);
    uint16_t handler = rd(DATA_SoundCommandHandlerTable + 2 * id) | rd(DATA_SoundCommandHandlerTable + 2 * id + 1) << 8;
    return (void *)gb_dispatch(handler);
}

/* VBlankHandler: runs at the start of every frame (gb_host_vblank calls it through the vector): the soft reset when all four direction keys are held (hJoyHeld = $0f);
 * the OAM DMA (hVBlankTasks bit 1), queued VRAM copies (bit 0: list, bit 2: rows), the scroll registers, clearing of the OAM shadow Y values after a DMA, the sound engine,
 * the round clock (bit 4: hTimeFrames counts 60 per second, hTimeSeconds counts down) and the frame flag and counter the waiting loops use. All registers are kept. */
void *gb_native_VBlankHandler(void) {
    Regs saved = r;
    if (rd(hJoyHeld) == 0x0F) {
        wr(rLCDC, rd(rLCDC) | 0x80);
        wr(rIF, 0);
        wr(rIE, 0);
        wr(rSC, 0);
        ime = 0;
        return (void *)GAME_Entry;
    }
    if (rd(hVBlankTasks) & 0x02) gb_dma_routine();
    if (rd(hVBlankTasks) & 0x01) {
        NCALL(GAME_VramCopyList);
        wr(hVBlankTasks, rd(hVBlankTasks) & ~0x01);
    }
    if (rd(hVBlankTasks) & 0x04) {
        NCALL(GAME_VramCopyRows);
        wr(hVBlankTasks, rd(hVBlankTasks) & ~0x04);
    }
    wr(rSCX, rd(wScrollX));
    wr(rSCY, rd(wScrollY));
    if (rd(hVBlankTasks) & 0x02) {
        wr(hVBlankTasks, rd(hVBlankTasks) & ~0x02);
        NCALL(GAME_ClearOamShadowY);
    }
    NCALL(GAME_SoundUpdate);
    if ((rd(hVBlankTasks) & 0x10) && rd(hTimeSeconds)) {
        uint8_t frames = rd(hTimeFrames);
        wr(hTimeFrames, frames - 1);
        if (frames == 0) {                       /* a second has passed */
            wr(hTimeSeconds, rd(hTimeSeconds) - 1);
            wr(hTimeFrames, 0x3C);
        }
    }
    wr(hVBlankFlag, rd(hVBlankFlag) | 0x01);
    wr(hFrameCounter, rd(hFrameCounter) + 1);
    r = saved;
    ime = 1;
    return 0;
}

/* ---- the VRAM copy queue ----
 * A copy stream is `count, rows, tiles...`: for every row `count` tiles (a count with bit 7 set repeats the one tile that follows) are written at the destination and the
 * destination moves to the next row of the 32 tile wide background map. The queue entries (wVramDst/wVramSrc for one stream, wVramListPtr for a list of `count,
 * then 4 byte jobs of destination and source`) are carried out by the VBlank handler. */

/* VramCopyStream: HL = destination in VRAM, DE = the stream. The queue flag bit 0 is cleared at the end unless bit 7 (list mode) is set. */
void *gb_native_VramCopyStream(void) {
    uint16_t to = HL(), from = DE();
    uint8_t spec = rd(from++);
    uint8_t rows = rd(from++);
    wr(hScratch12, spec);
    uint8_t width = spec & 0x7F;
    for (;;) {
        for (uint8_t i = 0; i < width; i++) {
            wr(to++, rd(from));
            if (!(spec & 0x80)) from++;
        }
        if (--rows == 0) break;
        to = (uint16_t)(to + 0x20 - width);
    }
    SET_HL(to);
    SET_DE(from);
    r.b = 0;
    r.c = 0;
    r.a = rd(wVramCopyFlags);
    r.f = (r.f & 0x10) | 0x20 | ((r.a & 0x80) ? 0 : 0x80);
    if (r.a & 0x80) return 0;
    SET_HL(wVramCopyFlags);
    wr(wVramCopyFlags, rd(wVramCopyFlags) & ~0x01);
    return 0;
}

/* VramCopyRows: the queued single stream (destination wVramDst, source wVramSrc). */
void *gb_native_VramCopyRows(void) {
    SET_HL(rd(wVramDstHi) << 8 | rd(wVramDstLo));
    SET_DE(rd(wVramSrcHi) << 8 | rd(wVramSrcLo));
    return gb_native_VramCopyStream();
}

/* RunVramCopyList: BC = a list: a job count, then per job the destination (2 bytes) and the stream address (2 bytes). All jobs run at once; the queue flag bit 0 is cleared. */
void *gb_native_RunVramCopyList(void) {
    uint16_t list = BC();
    uint8_t jobs = rd(list++);
    wr(hScratch15, jobs);
    for (;;) {
        wr(hScratch14, list >> 8);
        wr(hScratch13, (uint8_t)list);
        SET_HL(rd(list) | rd(list + 1) << 8);
        SET_DE(rd(list + 2) | rd(list + 3) << 8);
        gb_native_VramCopyStream();
        jobs--;
        if (jobs == 0) break;
        wr(hScratch15, jobs);
        list += 4;
    }
    SET_HL(wVramCopyFlags);
    wr(wVramCopyFlags, rd(wVramCopyFlags) & ~0x01);
    return 0;
}

/* VramCopyList: the queued list (wVramListPtr). */
void *gb_native_VramCopyList(void) {
    SET_BC(rd(wVramListPtrHi) << 8 | rd(wVramListPtrLo));
    return gb_native_RunVramCopyList();
}

/* QueueVramCopyList: BC = a list for the next VBlank (bits 0 and 7 of wVramCopyFlags, hVBlankTasks bit 0). */
void *gb_native_QueueVramCopyList(void) {
    wr(wVramListPtrLo, r.c);
    wr(wVramListPtrHi, r.b);
    SET_HL(hVBlankTasks);
    wr(wVramCopyFlags, rd(wVramCopyFlags) | 0x81);
    wr(hVBlankTasks, rd(hVBlankTasks) | 0x01);
    return 0;
}

/* QueueVramCopyRows: HL = destination, DE = stream, queued for the next VBlank (bit 0 of wVramCopyFlags, hVBlankTasks bit 2). */
void *gb_native_QueueVramCopyRows(void) {
    wr(wVramDstHi, r.h);
    wr(wVramDstLo, r.l);
    wr(wVramSrcHi, r.d);
    wr(wVramSrcLo, r.e);
    wr(wVramCopyFlags, rd(wVramCopyFlags) | 0x01);
    SET_HL(hVBlankTasks);
    wr(hVBlankTasks, rd(hVBlankTasks) | 0x04);
    return 0;
}

/* EnemyComputeBlockedDirs: hEnemyBlocked = the directions in which the map cell next to the enemy is a wall (low nibble 0): 4 up, 8 down, 2 left, 1 right.
 * The enemy is on the cell whose centre is nearest (column from X rounded to 16, row centre = (Y and $f0) + 8); a direction is only tested when the enemy has
 * reached or passed the centre of its cell in that direction. */
void *gb_native_EnemyComputeBlockedDirs(void) {
    uint8_t x = rd(hEnemyX), y = rd(hEnemyY);
    uint8_t blocked = 0;
    uint8_t nearest = (uint8_t)(x + 8) & 0xF0;
    uint8_t col = (uint8_t)((nearest >> 4) - 1);
    uint8_t centre = (uint8_t)((y & 0xF0) + 8);
    wr(hEnemyBlocked, 0);
    if (centre >= y && (map_tile(centre - 0x10, col) & 0x0F) == 0) { blocked = 0x04; wr(hEnemyBlocked, blocked); }
    if (y >= centre && (map_tile(centre + 0x10, col) & 0x0F) == 0) { blocked |= 0x08; wr(hEnemyBlocked, blocked); }
    if (nearest >= x && (map_tile(centre, col - 1) & 0x0F) == 0) { blocked |= 0x02; wr(hEnemyBlocked, blocked); }
    if (x >= nearest && (map_tile(centre, col + 1) & 0x0F) == 0) { blocked |= 0x01; wr(hEnemyBlocked, blocked); }
    return 0;
}

/* ProjectileAimAtPlayer: the heading of the enemy projectile (wProjectile +$10) becomes the one of the eight directions that points from the enemy at the player:
 * 0 up, 4 up-right, 8 right, $c down-right, $10 down, $14 down-left, $1c up-left (a difference of less than 16 pixels counts as the same row or column).
 * (Same row and the enemy to the right of the player gives $10, not left ($18): that is what the original does.) */
void *gb_native_ProjectileAimAtPlayer(void) {
    uint8_t px = rd(wPlayerX), py = rd(wPlayerY), ex = rd(hEnemyX), ey = rd(hEnemyY);
    uint8_t heading;
    int left = (uint8_t)(ex - 0x10) >= px, right = (uint8_t)(ex + 0x10) < px;
    if ((uint8_t)(ey - 0x10) >= py) heading = left ? 0x1C : (right ? 0x04 : 0x00);
    else if ((uint8_t)(ey + 0x10) < py) heading = left ? 0x14 : (right ? 0x0C : 0x10);
    else heading = ex < px ? 0x08 : 0x10;
    wr(wProjectile + 0x10, heading);
    r.a = heading;
    return 0;
}

/* EnemyAimAtPlayer: when the enemy stands on the tile grid it turns towards the player: horizontally first (right 1, left 2; also left when its X is beyond 255),
 * and when the X agrees vertically (up 4, down 8). If that direction is blocked (hEnemyBlocked) bit 6 of hEnemyDir is set and EnemyChooseDirection picks another.
 * When both coordinates agree the low nibble of hEnemyDir becomes the low bits of the enemy's Y (as in the original). */
void *gb_native_EnemyAimAtPlayer(void) {
    r.b = rd(hEnemyX);
    r.c = rd(hEnemyY);
    gb_native_IsOnTileGrid();
    if (!ZF()) return 0;
    uint8_t bits;
    uint8_t want = 0;
    if (rd(hEnemyXHi) == 1) {
        want = 0x02;
    } else {
        uint8_t ex = rd(hEnemyX), px = rd(wPlayerX);
        if (px != ex) want = px < ex ? 0x02 : 0x01;
    }
    if (want) {
        if (rd(hEnemyBlocked) & want) goto blocked;
        bits = want;
    } else {
        uint8_t ey = rd(hEnemyY), py = rd(wPlayerY);
        if (py == ey) {
            bits = ey;
        } else {
            uint8_t vertical = py < ey ? 0x04 : 0x08;
            if (rd(hEnemyBlocked) & vertical) goto blocked;
            bits = vertical;
        }
    }
    wr(hEnemyDir, (rd(hEnemyDir) & 0xF0) | bits);
    return 0;
blocked:
    SET_HL(hEnemyDir);
    wr(hEnemyDir, rd(hEnemyDir) | 0x40);
    return (void *)GAME_EnemyChooseDirection;
}

/* EnemyChooseDirection: when bit 6 of hEnemyDir asks for a new direction the low nibble of hEnemyDir becomes one free direction (bits 1 right, 2 left, 4 up, 8 down):
 * random numbers from NextRandomDirection are tried until exactly one bit of (not blocked) and (random nibble) is left. If every direction except the one the table at $3aa2
 * gives for the current heading is blocked, all free directions are set at once. */
void *gb_native_EnemyChooseDirection(void) {
    if (!(rd(hEnemyDir) & 0x40)) return 0;
    wr(hEnemyDir, rd(hEnemyDir) & ~0x40);
    uint8_t blocked = rd(hEnemyBlocked);
    uint8_t opposite = rd(0x3AA2 + ((rd(hEnemyDir) & 0x0F) >> 1));
    uint8_t free_dirs = (uint8_t)~blocked & 0x0F;
    if ((uint8_t)(opposite | blocked) == 0x0F) {
        wr(hEnemyDir, (rd(hEnemyDir) & 0xF0) | free_dirs);
        return 0;
    }
    for (;;) {
        gb_native_NextRandomDirection();
        uint8_t pick = free_dirs & (rd(hRngCounter) & 0x0F);
        if (pick == 0x08 || pick == 0x04 || pick == 0x02 || pick == 0x01) {
            wr(hEnemyDir, (rd(hEnemyDir) & 0xF0) | pick);
            return 0;
        }
    }
}

/* EnemyMoveStep: one movement step of an enemy on the grid. While the T.STOP card (3) runs, or when the direction in hEnemyDir is blocked, a turn is requested.
 * Otherwise the step (X and Y pixel parts, hEnemyDXHi and hEnemyDYHi) comes from a table indexed by the direction: $3ae3 for normal enemies and $3aed for fast ones
 * (hEnemyFlags bit 7 or a spawn flag), and is applied to the position. */
void *gb_native_EnemyMoveStep(void) {
    if (rd(wActiveMagic) == 0x03 && (rd(wMagicState) & 0x01)) return gb_native_EnemyRequestTurn();
    uint8_t blocked = rd(hEnemyBlocked) & 0x0F, dir = rd(hEnemyDir) & 0x0F;
    if (dir & blocked) return gb_native_EnemyRequestTurn();
    uint16_t table = ((rd(hEnemyFlags) & 0x80) || rd(hEnemySpawnFlag)) ? 0x3AED : 0x3AE3;
    uint8_t index = (uint8_t)((dir >> 1) << 1);
    wr(hEnemyDXHi, rd(table + index));
    wr(hEnemyDYHi, rd(table + index + 1));
    gb_native_SelectObject2();
    return gb_native_ApplyObjectStep();
}

/* EnemyGridStep: off the grid it only drops the turn request (bit 6 of hEnemyDir); on the grid hEnemyStep counts to $0b and then restarts with the bits 5 and 6 of hEnemyDir set. */
void *gb_native_EnemyGridStep(void) {
    gb_native_EnemyOnTileGrid();
    if (!ZF()) { wr(hEnemyDir, rd(hEnemyDir) & ~0x40); return 0; }
    uint8_t step = rd(hEnemyStep);
    if (step == 0x0B) {
        wr(hEnemyStep, 0);
        wr(hEnemyDir, rd(hEnemyDir) | 0x60);
    } else {
        wr(hEnemyStep, step + 1);
    }
    return 0;
}

/* EnemyPaintUnderB0M: while the B.O.M card (5) runs an enemy that is not frozen (flags bit 1) paints the cell it stands on when it is exactly on the grid. */
void *gb_native_EnemyPaintUnderB0M(void) {
    if (rd(wActiveMagic) != 0x05) return 0;
    if (!(rd(wMagicState) & 0x01)) return 0;
    if (rd(hEnemyFlags) & 0x02) return 0;
    r.b = rd(hEnemyX);
    r.c = rd(hEnemyY);
    gb_native_IsOnTileGrid();
    if (!ZF()) return 0;
    return gb_native_PaintCell();
}

/* EnemyShootIfReady: an enemy that shoots counts hEnemyStep down while no projectile is live; at 0, when it is on the screen, it shoots (SpawnEnemyProjectile). */
void *gb_native_EnemyShootIfReady(void) {
    if (rd(wProjectile) & 0x80) return 0;
    SET_HL(hEnemyStep);
    wr(hEnemyStep, rd(hEnemyStep) - 1);
    if (rd(hEnemyStep)) return 0;
    if (rd(wProjectile) & 0x80) return 0;
    r.c = rd(hEnemyX);
    r.b = rd(hEnemyY);
    gb_native_EnemyScreenPosition();
    if (r.a) return 0;
    return (void *)GAME_SpawnEnemyProjectile;
}

/* CheckEnemyTouchesPlayer: when the enemy in hObject2 overlaps the player, wPlayerDir bit 5 is set (PlayFrame then runs PlayerDeath). Not while the GHOST card (4) runs, except for kind 4. */
void *gb_native_CheckEnemyTouchesPlayer(void) {
    if (rd(hEnemyKind) != 0x04 && rd(wActiveMagic) == 0x04 && (rd(wMagicState) & 0x01)) return 0;
    wr(hOtherObjLo, (uint8_t)wPlayer);
    wr(hOtherObjHi, wPlayer >> 8);
    gb_native_SelectObject2();
    gb_native_ObjectsOverlap();
    if (!r.a) return 0;
    SET_HL(wPlayerDir);
    wr(wPlayerDir, rd(wPlayerDir) | 0x20);
    return 0;
}

/* CheckPaintHitsEnemy: when the paint blob (wPaintObject) overlaps the enemy in hObject2 the blob is removed, the enemy is marked hit (hEnemyFlags bit 2),
 * the card state is cleared and wPlayerStatus bit 3 is set. */
void *gb_native_CheckPaintHitsEnemy(void) {
    if (!(rd(wPaintObject) & 0x80)) return 0;
    wr(hOtherObjLo, (uint8_t)wPaintObject);
    wr(hOtherObjHi, wPaintObject >> 8);
    gb_native_SelectObject2();
    gb_native_ObjectsOverlap();
    if (!r.a) return 0;
    wr(wPaintObject, rd(wPaintObject) & 0x7F);
    SET_HL(hEnemyFlags);
    wr(hEnemyFlags, rd(hEnemyFlags) | 0x04);
    wr(wMagicState, 0);
    wr(wPlayerStatus, rd(wPlayerStatus) | 0x08);
    return 0;
}

/* ---- enemy animation selection ----
 * An animation is a pointer to frame data (hEnemyAnimLo/Hi, record +1/+2). Most enemies have two pointers per direction ("variants") that are swapped with
 * bit 3 of hEnemyTick (bit 2 for kind 2) to make the walk cycle; the sprite is mirrored with bit 5 of hObject2 for the right/left directions. */
static void set_anim(uint16_t pointer) {
    wr(hEnemyAnimLo, (uint8_t)pointer);
    wr(hEnemyAnimHi, pointer >> 8);
    SET_DE(pointer);
    r.a = pointer >> 8;
}
static void set_flip(int on) { SET_HL(hObject2); wr(hObject2, on ? (rd(hObject2) | 0x20) : (rd(hObject2) & ~0x20)); }
static void anim_variant(uint16_t a, uint16_t b) { SET_BC(b); set_anim((rd(hEnemyTick) & 0x08) ? b : a); }

void *gb_native_SetObjectAnimation(void) { set_anim(DE()); return 0; }
void *gb_native_SetObjectAnimationStub(void) { return gb_native_SetObjectAnimation(); }
void *gb_native_SetAnimationVariant(void) {
    if (rd(hEnemyTick) & 0x08) SET_DE(BC());
    return gb_native_SetObjectAnimation();
}
void *gb_native_SetObjectFlipFlag(void) { SET_HL(hObject2); wr(hObject2, rd(hObject2) | 0x20); return 0; }

/* SelectEnemyAnimation (kind 1): by direction bits 0 right (mirrored), 1 left, 2 up, else down. */
void *gb_native_SelectEnemyAnimation(void) {
    uint8_t dir = rd(hEnemyDir);
    if (dir & 0x01) { set_flip(1); anim_variant(0x3BC8, 0x3BCD); }
    else if (dir & 0x02) { set_flip(0); anim_variant(0x3BC8, 0x3BCD); }
    else if (dir & 0x04) anim_variant(0x3BD2, 0x3BD7);
    else anim_variant(0x3BBE, 0x3BC3);
    return 0;
}

/* EnemySelectAnimByKind: kinds 6 and 8 have their own animations, the others choose like kind 1 with the tables at $3aa6-$3abf. */
void *gb_native_EnemySelectAnimByKind(void) {
    uint8_t kind = rd(hEnemyKind), dir = rd(hEnemyDir);
    if (kind == 0x06) anim_variant(0x3ACF, 0x3AD4);
    else if (kind == 0x08) anim_variant(0x3AD9, 0x3ADE);
    else if (dir & 0x01) { set_flip(1); anim_variant(0x3AB0, 0x3AB5); }
    else if (dir & 0x02) { set_flip(0); anim_variant(0x3AB0, 0x3AB5); }
    else if (dir & 0x04) anim_variant(0x3ABA, 0x3ABF);
    else anim_variant(0x3AA6, 0x3AAB);
    return 0;
}

void *gb_native_SelectKind3Animation(void) {
    uint8_t dir = rd(hEnemyDir);
    if (dir & 0x01) { set_flip(1); anim_variant(0x5A84, 0x5A8B); }
    else if (dir & 0x02) { set_flip(0); anim_variant(0x5A84, 0x5A8B); }
    else if (dir & 0x04) anim_variant(0x5A92, 0x5A99);
    else anim_variant(0x5A76, 0x5A7D);
    return 0;
}

void *gb_native_SelectKind4Animation(void) {
    uint8_t dir = rd(hEnemyDir);
    if (dir & 0x01) { set_flip(1); set_anim(0x53EC); }
    else if (dir & 0x02) { set_flip(0); set_anim(0x53EC); }
    else if (dir & 0x04) set_anim(0x53F3);
    else set_anim(0x53E5);
    return 0;
}

/* SelectKind2Animation: four directions (bit 3 down), the animations of a pair alternate with bit 2 of hEnemyTick. */
void *gb_native_SelectKind2Animation(void) {
    uint8_t dir = rd(hEnemyDir);
    uint16_t de, bc;
    if (dir & 0x01) { set_flip(1); de = 0x59D9; bc = 0x59E0; }
    else if (dir & 0x02) { set_flip(0); de = 0x59D9; bc = 0x59E0; }
    else if (dir & 0x04) { bc = 0x59E7; de = 0x59EE; }
    else if (dir & 0x08) { bc = 0x59CB; de = 0x59D2; }
    else return 0;
    SET_BC(bc);
    set_anim((rd(hEnemyTick) & 0x04) ? bc : de);
    return 0;
}

/* SelectKind9Animation: up and down have their own pair; sideways uses a mirrored pair when bit 0 (right) is set. */
void *gb_native_SelectKind9Animation(void) {
    set_flip(0);
    uint8_t dir = rd(hEnemyDir);
    uint16_t de, bc;
    if (dir & 0x04) { de = 0x588B; bc = 0x5892; }
    else if (dir & 0x08) { de = 0x586F; bc = 0x5876; }
    else {
        if (dir & 0x01) gb_native_SetObjectFlipFlag();
        de = 0x587D; bc = 0x5884;
    }
    SET_BC(bc);
    set_anim((rd(hEnemyTick) & 0x08) ? bc : de);
    return 0;
}

/* EnemyErasePaint: enemies undo the player's work. When hEnemyDir bit 5 asks for it (set by EnemyGridStep), the map cell under the enemy is a painted cell (bit 4)
 * and the enemy is on the screen, the cell becomes unpainted again (its low nibble with bit 7) and its two tile rows are redrawn from D_00_3ac4; wPaintRemaining goes up by 1.
 * Not for kind 8, and not while the B.O.M card (5) runs. */
void *gb_native_EnemyErasePaint(void) {
    if (rd(hEnemyKind) == 0x08) return 0;
    if (rd(wActiveMagic) == 0x05 && (rd(wMagicState) & 0x01)) return 0;
    if (!(rd(hEnemyDir) & 0x20)) return 0;
    wr(hEnemyDir, rd(hEnemyDir) & ~0x20);
    r.a = rd(hEnemyX);
    gb_native_PixelXToColumn();
    r.a = (uint8_t)((rd(hEnemyY) & 0xF0) + 8);
    gb_native_LookupMapTile();
    uint16_t cell = HL();
    uint8_t tile = r.a;
    r.e = tile;
    if (tile & 0x80) return 0;
    if (!(tile & 0x10)) return 0;
    r.c = rd(hEnemyX);
    r.b = rd(hEnemyY);
    gb_native_EnemyScreenPosition();
    if (r.a) return 0;
    wr(cell, (tile & 0x0F) | 0x80);
    wr(hSpriteX, (uint8_t)((rd(hEnemyX) + 8) & 0xF0));
    wr(hSpriteY, (uint8_t)(rd(hEnemyY) & 0xF0));
    NCALL(GAME_PixelToTilemapAddr);
    r.l = r.a - 1;
    r.h = rd(hTilemapAddrHi);
    SET_DE(0x3AC4);
    NCALL(GAME_QueueVramCopyRows);
    NCALL(GAME_WaitVramCopyDone);
    wr(wPaintRemaining, rd(wPaintRemaining) + 1);
    return 0;
}

/* EnemyFlagOffPath: hEnemyFlags bit 1 = the map cell under the enemy is not a path (low nibble 0). */
void *gb_native_EnemyFlagOffPath(void) {
    gb_native_EnemyTileUnder();
    SET_HL(hEnemyFlags);
    if ((r.a & 0x0F) == 0) wr(hEnemyFlags, rd(hEnemyFlags) | 0x02);
    else wr(hEnemyFlags, rd(hEnemyFlags) & ~0x02);
    return 0;
}

/* EnemyTurnIfBlocked (kinds 3 and 4): a turn is requested when the way is blocked, and also for kind 3 while T.STOP (3) runs, otherwise the heading hEnemyAngle comes from the table at $363d
 * (direction bits to a heading: up 0, right 8, down $10, left $18). For kind 3 the speed is set to 5 first. */
void *gb_native_EnemyTurnIfBlocked(void) {
    uint8_t kind = rd(hEnemyKind);
    if (kind != 0x04 && kind == 0x03 && rd(wActiveMagic) == 0x03) {
        if (rd(wMagicState) & 0x01) return gb_native_EnemyRequestTurn();
        wr(hEnemySpeed, 0x05);
    }
    if ((rd(hEnemyBlocked) & 0x0F) & (rd(hEnemyDir) & 0x0F)) return gb_native_EnemyRequestTurn();
    r.c = (rd(hEnemyDir) & 0x0F) >> 1;
    SET_HL(0x363D);
    gb_native_LookupByte();
    wr(hEnemyAngle, r.a);
    return 0;
}

/* EnemyKind10Move: kind 10 flies: its heading comes from the table at $5782 by direction; it moves and applies the step, then ProjectileHitTest compares its position
 * (hScratch00-03) and hEnemyFlags bit 3 is set when that test says no hit. */
void *gb_native_EnemyKind10Move(void) {
    r.c = (rd(hEnemyDir) & 0x0F) >> 1;
    SET_HL(0x5782);
    gb_native_LookupByte();
    wr(hEnemyAngle, r.a);
    gb_native_SelectObject2();
    gb_native_MoveObject();
    gb_native_ApplyObjectStep();
    wr(hScratch00, rd(hEnemyX));
    wr(hScratch00 + 1, rd(hEnemyXHi));
    wr(hScratch00 + 2, rd(hEnemyY));
    wr(hScratch00 + 3, rd(hEnemyYHi));
    gb_native_ProjectileHitTest();
    if (r.a) return 0;
    SET_HL(hEnemyFlags);
    wr(hEnemyFlags, rd(hEnemyFlags) | 0x08);
    return 0;
}

/* EnemyIdleAnimate (kind 5): the enemy first shows an animation pair for $a0 counts (hEnemyCounter), then sets hEnemyDir bit 1; then a blink between two animations for
 * $50 counts, after which hEnemyDir bit 0 lets EnemyTeleportNext move it. */
void *gb_native_EnemyIdleAnimate(void) {
    if (!(rd(hEnemyDir) & 0x02)) {
        uint8_t count = rd(hEnemyCounter);
        if (count != 0xA0) {
            wr(hEnemyCounter, count + 1);
            anim_variant(0x3F3A, 0x3F3F);
            return 0;
        }
        wr(hEnemyCounter, 0);
        wr(hEnemyDir, rd(hEnemyDir) | 0x02);
    }
    uint8_t count = rd(hEnemyCounter);
    if (count == 0x50) { SET_HL(hEnemyDir); wr(hEnemyDir, rd(hEnemyDir) | 0x01); return 0; }
    wr(hEnemyCounter, count + 1);
    set_anim((rd(hEnemyTick) & 0x04) ? 0x3F3A : 0x3ACA);
    return 0;
}

/* EnemyBuildTeleportTable (kind 5 at its start): counter $20 and the table at $c489 of the places the enemy visits: left, up, right, down of where it stands and its own
 * place, ended by a zero; animation $3f3a and hEnemyDir = $90. */
void *gb_native_EnemyBuildTeleportTable(void) {
    wr(hEnemyCounter, 0x20);
    uint8_t x = rd(hEnemyX), y = rd(hEnemyY);
    wr(0xC48B, x); wr(0xC48F, x); wr(0xC491, x);
    wr(0xC489, (uint8_t)(x - 0x10));
    wr(0xC48D, (uint8_t)(x + 0x10));
    wr(0xC48A, y); wr(0xC48E, y); wr(0xC492, y);
    wr(0xC48C, (uint8_t)(y - 0x10));
    wr(0xC490, (uint8_t)(y + 0x10));
    wr(0xC493, 0);
    set_anim(0x3F3A);
    wr(hEnemyDir, 0x90);
    r.a = 0x90;
    return 0;
}

/* EnemyTeleportNext: once hEnemyDir bit 0 is set the enemy jumps to the next place of its table (box size 2, hEnemyStep indexes the pairs); a zero X ends it (RemoveEnemy). */
void *gb_native_EnemyTeleportNext(void) {
    if (!(rd(hEnemyDir) & 0x01)) return 0;
    wr(hEnemyBoxHalf, 0x02);
    uint16_t at = 0xC489 + (uint8_t)(rd(hEnemyStep) << 1);
    uint8_t x = rd(at);
    if (x == 0) return gb_native_RemoveEnemy();
    wr(hEnemyX, x);
    wr(hEnemyY, rd(at + 1));
    SET_HL(hEnemyStep);
    wr(hEnemyStep, rd(hEnemyStep) + 1);
    set_anim(0x3F44);
    return 0;
}

/* EnemySnapToGrid: box size 4; the low nibble of the enemy's X becomes the low nibble of hEnemyDir (with bits 4 and 7 set: $90) and X is rounded down to a multiple of 16. */
void *gb_native_EnemySnapToGrid(void) {
    wr(hEnemyBoxHalf, 0x04);
    uint8_t x = rd(hEnemyX);
    wr(hEnemyX, x & 0xF0);
    wr(hEnemyDir, (x & 0x0F) | 0x90);
    r.a = (x & 0x0F) | 0x90;
    return 0;
}

/* EnemyKind7NextStep (the path walking enemy): reads the next heading from the path script at wEnemyPathPtr (a byte per frame, 1 ends it and sets hEnemyDir bit 0 and speed 0).
 * While the T.STOP card runs the speed is 0 and the script steps back one byte so nothing is lost. */
void *gb_native_EnemyKind7NextStep(void) {
    if (rd(hEnemyDir) & 0x01) return 0;
    uint16_t at = rd(wEnemyPathPtr) | rd(wEnemyPathPtrHi) << 8;
    if (rd(wActiveMagic) == 0x03 && (rd(wMagicState) & 0x01)) { wr(hEnemySpeed, 0); at--; }
    else wr(hEnemySpeed, 0x05);
    uint8_t heading = rd(at);
    if (heading == 0x01) {
        SET_HL(hEnemyDir);
        wr(hEnemyDir, rd(hEnemyDir) | 0x01);
        wr(hEnemySpeed, 0);
        wr(wEnemyPathPtr, (uint8_t)at);
        wr(wEnemyPathPtrHi, at >> 8);
        return 0;
    }
    wr(hEnemyCounter, heading);
    wr(hEnemyAngle, heading);
    at++;
    wr(wEnemyPathPtr, (uint8_t)at);
    wr(wEnemyPathPtrHi, at >> 8);
    return 0;
}

/* EnemyKind7Init: speed 5, counters $20, animation $3e4d, snapped to the grid, and the path script chosen by the direction (table at $3d6a). */
void *gb_native_EnemyKind7Init(void) {
    wr(hEnemySpeed, 0x05);
    wr(hEnemyCounter, 0x20);
    wr(hEnemyAux, 0x20);
    SET_HL(hObject2);
    wr(hObject2, rd(hObject2) | 0x40);
    set_anim(0x3E4D);
    gb_native_EnemySnapToGrid();
    r.a = (rd(hEnemyDir) & 0x0F) >> 1;
    SET_HL(0x3D6A);
    gb_native_LookupWord();
    wr(wEnemyPathPtr, r.l);
    wr(wEnemyPathPtrHi, r.h);
    return 0;
}

/* EnemyKind7Update (the path walking enemy): once its path is finished (hEnemyDir bit 0) it blinks for hEnemyAux frames and is removed; while walking, the animation pair
 * depends on the heading in hEnemyCounter (0 up, 8 right (not mirrored), $10 down, $18 left (mirrored)). */
void *gb_native_EnemyKind7Update(void) {
    if (rd(hEnemyDir) & 0x01) {
        uint8_t aux = rd(hEnemyAux);
        if (aux == 0) return gb_native_RemoveEnemy();
        wr(hEnemyAux, aux - 1);
        anim_variant(0x3ACA, 0x3E4D);
        return 0;
    }
    wr(hObject2, rd(hObject2) | 0x60);
    switch (rd(hEnemyCounter)) {
    case 0x08: wr(hObject2, rd(hObject2) & ~0x20); anim_variant(0x3E57, 0x3E5C); break;
    case 0x10: anim_variant(0x3E4D, 0x3E52); break;
    case 0x18: anim_variant(0x3E57, 0x3E5C); break;
    default:   wr(hObject2, rd(hObject2) & ~0x40); anim_variant(0x3E4D, 0x3E52); break;
    }
    return 0;
}

void *gb_native_EnemyKind7SetAnimation(void) { anim_variant(0x3C87, 0x3C8C); return 0; }

/* EnemyKind7Start (kind 11): counter $20, hEnemyAux = the map tile under the enemy, hEnemyTimer = $fe, hEnemyDir = $90, animation $3c87. */
void *gb_native_EnemyKind7Start(void) {
    wr(hEnemyCounter, 0x20);
    gb_native_EnemyMapTile();
    wr(hEnemyAux, r.a);
    wr(hEnemyTimer, 0xFE);
    wr(hEnemyDir, 0x90);
    set_anim(0x3C87);
    return 0;
}

/* EnemyStoreAuxToTile: writes hEnemyAux back into the map cell under the enemy. EnemyClearTileSaveStep: keeps that cell in hEnemyStep and clears it. */
void *gb_native_EnemyStoreAuxToTile(void) {
    gb_native_EnemyMapTile();
    wr(HL(), rd(hEnemyAux));
    return 0;
}
void *gb_native_EnemyClearTileSaveStep(void) {
    gb_native_EnemyMapTile();
    wr(hEnemyStep, r.a);
    wr(HL(), 0);
    r.a = 0;
    return 0;
}

/* SpawnEnemyProjectile: the shot of a shooting enemy appears in the cell of the enemy (flags $82, box size 4, a timer of $a0 in $c4b4). */
void *gb_native_SpawnEnemyProjectile(void) {
    SET_HL(wProjectile);
    gb_native_Clear32Bytes();
    wr(wProjectileBox, 0x04);
    wr(0xC4B4, 0xA0);
    wr(wProjectileX, (uint8_t)((rd(hEnemyX) + 8) & 0xF0));
    wr(wProjectileY, (uint8_t)((rd(hEnemyY) & 0xF0) + 8));
    wr(wProjectile, 0x82);
    r.a = 0x82;
    return 0;
}

/* UpdateProjectile (kind 10): the shooter fires every $50 steps while on the screen and not already firing: the shot is aimed at the player, placed at the shooter and
 * switched on (flags $86; hEnemyFlags bit 0 says a shot is live). When the shooter is hit (bit 3) the shot is removed. */
void *gb_native_UpdateProjectile(void) {
    if (rd(hEnemyFlags) & 0x01) return 0;
    if (rd(hEnemyFlags) & 0x08) { wr(wProjectile, rd(wProjectile) & 0x7F); return 0; }
    r.c = rd(hEnemyX);
    r.b = rd(hEnemyY);
    gb_native_EnemyScreenPosition();
    if (!ZF()) return 0;                           /* the original tests the flags the routine leaves, not A */
    SET_HL(hEnemyStep);
    wr(hEnemyStep, rd(hEnemyStep) - 1);
    if (rd(hEnemyStep)) return 0;
    gb_native_ProjectileAimAtPlayer();
    wr(wProjectileX, rd(hEnemyX));
    wr(wProjectileY, rd(hEnemyY));
    wr(wProjectile, 0x86);
    uint16_t anim = rd(hEnemyKind) == 0x0A ? 0x57EC : 0x57C9;
    wr(wProjectileAnimLo, (uint8_t)anim);
    wr(wProjectileAnimHi, anim >> 8);
    wr(hEnemyStep, 0x50);
    SET_HL(hEnemyFlags);
    wr(hEnemyFlags, rd(hEnemyFlags) | 0x01);
    return 0;
}

/* ProjectileCheckPlayerHit (kind 10): while a shot is live (hEnemyFlags bit 0) its position is tested against the player (ProjectileHitTest on hScratch00-03). On a hit
 * hEnemyDir bit 5 is set, the shot speeds up to $0b (stopped while T.STOP runs), it animates, moves and is drawn; with no hit the shot is switched off and hEnemyFlags bit 1 is set. */
void *gb_native_ProjectileCheckPlayerHit(void) {
    if (!(rd(hEnemyFlags) & 0x01)) return 0;
    wr(hScratch00, rd(wProjectileX));
    wr(hScratch00 + 1, rd(wProjectileX + 1));
    wr(hScratch00 + 2, rd(wProjectileY));
    wr(hScratch00 + 3, rd(wProjectileY + 1));
    gb_native_ProjectileHitTest();
    if (!r.a) {
        SET_HL(hEnemyFlags);
        wr(wProjectile, rd(wProjectile) & 0x7F);
        wr(hEnemyFlags, rd(hEnemyFlags) | 0x02);
        return 0;
    }
    SET_HL(hEnemyDir);
    wr(hEnemyDir, rd(hEnemyDir) | 0x20);
    wr(wProjectileSpeed, 0x0B);
    if (rd(wActiveMagic) == 0x03 && (rd(wMagicState) & 0x01)) {
        wr(hEnemySpeed, 0);
        wr(wProjectileSpeed, 0);
    }
    NCALL(GAME_EnemyKind10Animate);
    SET_HL(wProjectile);
    gb_native_SetObjPtr();
    gb_native_MoveObject();
    gb_native_ApplyObjectStep();
    return gb_native_DrawObject();
}

/* ProjectileRemoveIfHit (kind 10): when the enemy has both bits 1 and 3 set the shot and the enemy are removed. */
void *gb_native_ProjectileRemoveIfHit(void) {
    if ((rd(hEnemyFlags) & 0x0A) != 0x0A) return 0;
    wr(wProjectile, rd(wProjectile) & 0x7F);
    return gb_native_RemoveEnemy();
}

/* PixelToTilemapAddr: hSpriteY/hSpriteX (OAM style pixel position: Y + 16, X + 8) to the address in background map 0: $9800 + row * 32 + column. The result is stored in
 * hTilemapAddrHi/Lo and A = the low byte. */
void *gb_native_PixelToTilemapAddr(void) {
    uint8_t row = (uint8_t)(rd(hSpriteY) - 0x10) >> 3;
    uint8_t column = (uint8_t)(rd(hSpriteX) - 0x08) >> 3;
    uint16_t address = (uint16_t)(vBGMap0 + row * 0x20 + column);
    wr(hTilemapAddrHi, address >> 8);
    wr(hTilemapAddrLo, (uint8_t)address);
    r.a = (uint8_t)address;
    r.b = 0;
    SET_DE(column);
    SET_HL(address);
    return 0;
}

/* MapCellToVramAddr: C = index of a map cell (16 per row); hScratch00/01 = the address in background map 0 of the cell's 2x2 tiles ($9800 + row * $40 + column * 2). */
void *gb_native_MapCellToVramAddr(void) {
    uint8_t c = r.c;
    uint16_t address = vBGMap0;
    while (c >= 0x10) { c -= 0x10; address += 0x40; }
    address += (uint8_t)(c << 1);
    wr(hScratch00, (uint8_t)address);
    wr(hScratch00 + 1, address >> 8);
    r.c = c;
    r.e = (uint8_t)(c << 1);
    return 0;
}

/* UnpackRoomMap: HL = a packed map of 64 bytes (4 cells of 2 bits per byte, the top bits first) unpacked to the 256 bytes of wRoomMap. */
void *gb_native_UnpackRoomMap(void) {
    uint16_t from = HL();
    uint8_t packed = 0;
    for (int i = 0; i < 64; i++) {
        packed = rd(from++);
        for (int k = 0; k < 4; k++) wr(wRoomMap + 4 * i + k, (packed >> (6 - 2 * k)) & 3);
    }
    wr(hScratch00 + 2, packed);
    wr(0xC1B5, 0);
    SET_HL(from);
    SET_DE(wRoomMap + 256);
    SET_BC(0);
    r.a = 0;
    r.f = 0x80;
    return 0;
}

/* The camera: a 16 bit position (wCameraX/Hi, wCameraY/Hi) that follows the player, clamped to 0..$60 horizontally and 0..$70 vertically. */
static void follow(uint16_t cam, uint16_t cam_hi, uint8_t player, uint8_t offset, uint8_t limit) {
    uint8_t lo = (uint8_t)(player - offset);
    wr(cam, lo);
    uint8_t hi = (uint8_t)(rd(cam_hi) - (player < offset ? 1 : 0));
    wr(cam_hi, hi);
    if (hi & 0x80) { wr(cam_hi, 0); wr(cam, 0); }
    else if (lo >= limit) { wr(cam, limit); wr(cam_hi, 0); }
}
void *gb_native_CameraFollowPlayerX(void) {
    follow(wCameraX, wCameraXHi, rd(wPlayerX), 0x58, 0x60);
    follow(wCameraY, wCameraYHi, rd(wPlayerY), 0x68, 0x70);
    return 0;
}

void *gb_native_ResetCamera(void) {
    wr(wCameraX, 0x20);
    wr(wCameraY, 0x20);
    wr(wCameraXHi, 0);
    wr(wCameraYHi, 0);
    r.a = 0;
    return 0;
}

/* UpdateCamera: follows the player, then the scroll registers of the next VBlank are the camera. */
void *gb_native_UpdateCamera(void) {
    gb_native_CameraFollowPlayerX();
    wr(wScrollX, rd(wCameraX));
    wr(wScrollY, rd(wCameraY));
    r.a = rd(wCameraY);
    return 0;
}

/* InitPlayer: a fresh player record (flags $a2, heading $10, X $80, Y $78, the first animation of PlayerAnimPtrs, all state cleared) and the cards the player starts
 * with: card 1, from round 2 also card 9, from round 3 also card 6; in a link game cards 1, 2, 3, 5 and 6. */
void *gb_native_InitPlayer(void) {
    SET_HL(wPlayer);
    gb_native_Clear32Bytes();
    wr(wPlayerAngle, 0x10);
    wr(wPlayer, 0xA2);
    wr(wPlayerX, 0x80);
    wr(wPlayerY, 0x78);
    wr(wMagicCastTimer, 0); wr(0xC4C2, 0); wr(wPlayerBlocked, 0); wr(wTrailIdx, 0);
    wr(wPlayerDir, 0); wr(wPlayerStatus, 0); wr(hMagicTimer, 0);
    wr(wPlayerAnimLo, rd(DATA_PlayerAnimPtrs));
    wr(wPlayerAnimHi, rd(DATA_PlayerAnimPtrs + 1));
    if (rd(hLinkFlags) & 0x01) {
        static const uint8_t cards[5] = {1, 2, 3, 5, 6};
        for (int i = 0; i < 5; i++) wr(wMagicCards + i, cards[i]);
        return 0;
    }
    wr(wMagicCards, 1);
    if (rd(wRound) < 2) return 0;
    wr(wMagicCards + 1, 9);
    if (rd(wRound) < 3) return 0;
    wr(wMagicCards + 2, 6);
    return 0;
}

/* PlayerDeath: the death sequence (entered by PlayFrame when wPlayerDir bit 5 is set). The first frame waits $27 frames and plays the death music; then every frame the
 * counter wMagicCastTimer runs through CounterToFrame (60 frames per step, 15 steps) and the player is drawn with the animation pointer taken from the table at $488c
 * (mirrored at steps 6 and $10). After the last step the game mode is chosen: a link game goes to mode 7 (link lose) or on; otherwise a life is lost and mode 3 (round
 * intro) follows after $50 frames; with no lives left the lives are reset to 3 and mode 5 (continue) or mode 4 (game over) follows. */
void *gb_native_PlayerDeath(void) {
    if (!(rd(wPlayerStatus) & 0x04)) {
        r.a = 0x27;
        NCALL(GAME_DelayFrames);
        r.a = SND_MUSIC_DEATH;
        NCALL(GAME_PlaySound);
        SET_HL(wPlayerStatus);
        wr(wPlayerStatus, rd(wPlayerStatus) | 0x04);
    }
    wr(wMagicCastTimer, rd(wMagicCastTimer) + 1);
    wr(hScratch00 + 6, 0x3C);
    wr(hScratch00 + 7, 0x02);
    wr(hScratch00 + 8, rd(wMagicCastTimer));
    r.a = 0x0F;
    gb_native_CounterToFrame();
    wr(wMagicCastTimer, rd(hScratch00 + 8));
    uint8_t step = r.c;
    if (step != 0x1E) {
        wr(wPlayer, (step == 0x06 || step == 0x10) ? (rd(wPlayer) | 0x20) : (rd(wPlayer) & ~0x20));
        uint16_t entry = 0x488C + step;
        wr(wPlayerAnimLo, rd(entry));
        wr(wPlayerAnimHi, rd(entry + 1));
        SET_HL(wPlayer);
        gb_native_SetObjPtr();
        return gb_native_DrawObject();
    }
    wr(wActiveMagic, 0);
    wr(wMagicCastTimer, 0);
    if (rd(hLinkFlags) & 0x02) {
        wr(hSerialByte, rd(hSerialByte) | 0x40);
        r.a = 7;
        return (void *)GAME_GameModeDispatch;
    }
    if (rd(hLinkFlags) & 0x01) {
        r.c = 0x04;
        NCALL(GAME_SerialSendByte);
        wr(hSerialByte, rd(hSerialByte) | 0x80);
        if (!(rd(hSerialByte) & 0x02)) { r.a = 7; return (void *)GAME_GameModeDispatch; }
    }
    wr(wLives, rd(wLives) - 1);
    if (rd(wLives) != 0) {
        r.a = 0x50;
        NCALL(GAME_DelayFrames);
        r.a = 3;
        return (void *)GAME_GameModeDispatch;
    }
    wr(wPlayerDir, 0);
    wr(wPlayerStatus, 0);
    wr(0xC47B, 0);
    wr(0xC1A8, 0);
    wr(wRoundFlags, (rd(wRoundFlags) | 0x01) & 0xF9);
    wr(wLives, 3);
    r.a = 0x50;
    NCALL(GAME_DelayFrames);
    r.a = (rd(wContinues) == 0 && !(rd(wCheatFlags) & 0x01)) ? 4 : 5;
    return (void *)GAME_GameModeDispatch;
}

/* CheckBonusRound: after the rounds 4, 8, 12, 20, 24 and 28 wGameFlags bit 6 is set (the bonus screens follow). */
void *gb_native_CheckBonusRound(void) {
    uint8_t round = rd(wRound);
    if (round == 4 || round == 8 || round == 12 || round == 20 || round == 24 || round == 28) {
        SET_HL(wGameFlags);
        wr(wGameFlags, rd(wGameFlags) | 0x40);
    }
    return 0;
}

/* NextRound: the counters advance (wRound, wRoundBackup, wRoomIndex and two more); after round $21 the ending (mode 6) follows, after a bonus round the bonus select
 * (mode 2), else the round intro (mode 3). */
void *gb_native_NextRound(void) {
    if (rd(wRound) == 0x21) { r.a = 6; return (void *)GAME_GameModeDispatch; }
    wr(0xC47B, rd(0xC47B) + 1);
    wr(wRound, rd(wRound) + 1);
    wr(wRoundBackup, rd(wRoundBackup) + 1);
    wr(0xC1A8, rd(0xC1A8) + 1);
    wr(wRoomIndex, rd(wRoomIndex) + 1);
    wr(wPlayerStatus, rd(wPlayerStatus) & ~0x20);
    gb_native_CheckBonusRound();
    if (rd(wGameFlags) & 0x40) {
        wr(wGameFlags, rd(wGameFlags) & 0xBE);
        r.a = 2;
    } else {
        wr(wGameFlags, rd(wGameFlags) & ~0x01);
        r.a = 3;
    }
    return (void *)GAME_GameModeDispatch;
}

/* RoundCleared: runs every frame once the last cell is painted. The first time the palettes are restored, the clear music plays, the player is drawn and wGameFlags bit 0
 * and wPlayerStatus bit 2 are set. Afterwards it waits $97 frames (leaving to the link lose screen when the other player won), fades out and goes on to the next round
 * (link games first exchange the result). */
void *gb_native_RoundCleared(void) {
    if (!(rd(wPlayerStatus) & 0x04)) {
        wr(rBGP, PAL_NORMAL);
        wr(rOBP0, PAL_NORMAL);
        wr(rOBP1, PAL_NORMAL);
        r.a = SND_MUSIC_ROUND_CLEAR;
        NCALL(GAME_PlaySound);
        SET_HL(wPlayer);
        gb_native_SetObjPtr();
        gb_native_DrawObject();
        SET_HL(wPlayerStatus);
        wr(wPlayerStatus, rd(wPlayerStatus) | 0x04);
        wr(wGameFlags, rd(wGameFlags) | 0x01);
        return 0;
    }
    wr(hScratch00, 0x97);
    do {
        NCALL(GAME_WaitVBlankFlag);
        uint8_t link = rd(hSerialByte);
        if ((link & 0x80) || (link & 0x08)) { r.a = 7; return (void *)GAME_GameModeDispatch; }
        wr(hScratch00, rd(hScratch00) - 1);
    } while (rd(hScratch00));
    NCALL(GAME_FadeOut);
    if (rd(hLinkFlags) & 0x04) {
        wr(hSerialByte, rd(hSerialByte) & ~0x40);
        r.a = 7;
        return (void *)GAME_GameModeDispatch;
    }
    if (!(rd(hLinkFlags) & 0x01)) return gb_native_NextRound();
    r.c = 0x08;
    NCALL(GAME_SerialSendByte);
    if (rd(hSerialByte) & 0x02) return 0;
    wr(hSerialByte, rd(hSerialByte) | 0x40);
    r.a = 7;
    return (void *)GAME_GameModeDispatch;
}

/* FadeOut: five times each: the palette steps normal -> $94 -> $50 -> $40 -> white, two frames per palette and five blinks per step (BGP, OBP0 and OBP1 together). */
void *gb_native_FadeOut(void) {
    static const uint8_t steps[5] = { PAL_NORMAL, PAL_FADE_1, PAL_FADE_2, PAL_FADE_3, PAL_WHITE };
    for (int s = 0; s < 4; s++) {
        for (int blink = 0; blink < 5; blink++) {
            for (int k = 0; k < 2; k++) {
                wr(rBGP, steps[s + k]);
                wr(rOBP0, steps[s + k]);
                wr(rOBP1, steps[s + k]);
                r.a = 0x02;
                NCALL(GAME_DelayFrames);
            }
        }
    }
    r.b = 0;
    return 0;
}

/* DrawMetatileMap: draws a map of 2x2 tile blocks into the background map. HL = destination of the first block, BC = the table of blocks (4 tile ids each), DE = the cells
 * (one byte per block, the index into the table), hScratch00 = blocks per row, hScratch01 = rows; every tile id is ANDed with wMapCellMask. Blocks are 2 tiles wide, a row of
 * blocks is $40 bytes (two map rows) below the one before. The scratch variables end as the original leaves them. */
void *gb_native_DrawMetatileMap(void) {
    wr(hScratch00 + 6, r.l); wr(hScratch00 + 8, r.l);
    wr(hScratch00 + 7, r.h); wr(hScratch00 + 9, r.h);
    wr(hScratch00 + 10, r.c); wr(hScratch00 + 11, r.b);
    wr(hScratch00 + 12, r.e); wr(hScratch00 + 13, r.d);
    wr(hScratch00 + 16, rd(hScratch00));
    wr(hScratch00 + 3, 0); wr(hScratch00 + 4, 0); wr(hScratch00 + 5, 0);
    for (;;) {
        uint16_t cells = rd(hScratch00 + 12) | rd(hScratch00 + 13) << 8;
        uint8_t cell = rd(cells + rd(hScratch00 + 4));
        uint16_t block = (uint16_t)((rd(hScratch00 + 10) | rd(hScratch00 + 11) << 8) + cell * 4);
        wr(hOtherObjLo, (uint8_t)block);
        wr(hOtherObjHi, block >> 8);
        uint16_t at = (uint16_t)((rd(hScratch00 + 6) | rd(hScratch00 + 7) << 8) + (rd(hScratch00 + 5) | rd(hScratch00 + 3) << 8));
        for (int row = 0; row < 2; row++) {
            for (int col = 0; col < 2; col++) wr(at++, rd(block++) & rd(wMapCellMask));
            at += 0x1E;
        }
        uint8_t left = rd(hScratch00) - 1;
        if (left != 0) {
            wr(hScratch00, left);
            wr(hScratch00 + 4, rd(hScratch00 + 4) + 1);
            uint8_t offset = (uint8_t)(rd(hScratch00 + 5) + 2);
            if (offset == 0) wr(hScratch00 + 3, rd(hScratch00 + 3) + 1);
            else wr(hScratch00 + 5, offset);
            continue;
        }
        uint8_t rows = rd(hScratch00 + 1) - 1;
        if (rows == 0) return 0;
        wr(hScratch00 + 1, rows);
        uint16_t base = (uint16_t)((rd(hScratch00 + 8) | rd(hScratch00 + 9) << 8) + 0x40);
        wr(hScratch00 + 6, (uint8_t)base); wr(hScratch00 + 8, (uint8_t)base);
        wr(hScratch00 + 7, base >> 8); wr(hScratch00 + 9, base >> 8);
        wr(hScratch00 + 5, 0);
        wr(hScratch00, rd(hScratch00 + 16));
        wr(hScratch00 + 4, rd(hScratch00 + 4) + 1);
    }
}

/* ---- the bonus screens (after the rounds 4, 8, 12, 20, 24 and 28) ----
 * wPlayerBlocked is the step: 0 the "SELECT JUST ONE!" intro wait, 1 the choice of one of three doors with a cursor, 2 the result (a magic card is awarded).
 * $c487 counts the bonus screens and picks the row of the prize table at $25cb; the prize is chosen by hFrameSpin. */
void *gb_native_InitBonusCursor(void) {
    wr(wCursorIndex, 0);
    wr(wCursorFlags, 0);
    wr(wCursorY, 0x50);
    wr(wCursorObject, 0x80);
    SET_HL(0x2704);
    return gb_native_SetCursorAnimation();
}

/* MenuCursorInput: left and right move the cursor over three places (sound $8f), A sets wCursorFlags bit 7 (chosen); the cursor object is placed (X from the table at $2630) and drawn. */
void *gb_native_MenuCursorInput(void) {
    if (rd(hJoyNew) & 0x20) {
        r.a = SND_SFX_CURSOR;
        NCALL(GAME_PlaySound);
        uint8_t index = rd(wCursorIndex) - 1;
        if (index & 0x80) index = 2;
        wr(wCursorIndex, index);
    }
    if (rd(hJoyNew) & 0x10) {
        r.a = SND_SFX_CURSOR;
        NCALL(GAME_PlaySound);
        uint8_t index = rd(wCursorIndex) + 1;
        if (index >= 3) index = 0;
        wr(wCursorIndex, index);
    }
    if (rd(hJoyNew) & 0x01) wr(wCursorFlags, rd(wCursorFlags) | 0x80);
    r.c = rd(wCursorIndex);
    SET_HL(0x2630);
    gb_native_LookupByte();
    wr(wCursorX, r.a);
    SET_HL(wCursorObject);
    gb_native_SetObjPtr();
    return (void *)GAME_DrawObjectBytePos;
}

void *gb_native_Mode2_Init(void);

/* BonusIntroWait: $d0 frames, then the step 1 and the screen is set up again. */
void *gb_native_BonusIntroWait(void) {
    wr(hScratch00, 0xD0);
    do {
        NCALL(GAME_WaitVBlankFlag);
        NCALL(GAME_ReadJoypad);
        wr(hScratch00, rd(hScratch00) - 1);
    } while (rd(hScratch00));
    SET_HL(wPlayerBlocked);
    wr(wPlayerBlocked, rd(wPlayerBlocked) + 1);
    return gb_native_Mode2_Init();
}

/* BonusResultWait: 100 points (D:E = 1:0 for AddScore), $e0 frames, then mode 3 (round intro). */
void *gb_native_BonusResultWait(void) {
    r.d = 1;
    r.e = 0;
    call_native(gb_native_AddScore);
    wr(hScratch00, 0xE0);
    do {
        NCALL(GAME_WaitVBlankFlag);
        NCALL(GAME_ReadJoypad);
        wr(hScratch00, rd(hScratch00) - 1);
    } while (rd(hScratch00));
    r.a = 3;
    return (void *)GAME_GameModeDispatch;
}

/* BonusSelectLoop: after $10 frames the cursor loop runs until A is pressed; the prize card is read from the table at $25cb (3 candidates per bonus screen, picked by
 * hFrameSpin: below $7f the first, below $cd the second, else the third); if the player already has it that is the choice, otherwise it is added to wMagicCards. */
void *gb_native_BonusSelectLoop(void) {
    r.a = 0x10;
    NCALL(GAME_DelayFrames);
    SET_HL(wPlayerBlocked);
    wr(wPlayerBlocked, rd(wPlayerBlocked) + 1);
    do {
        NCALL(GAME_WaitFrameAndSyncOam);
        NCALL(GAME_ReadJoypad);
        call_native(gb_native_MenuCursorInput);
    } while (!(rd(wCursorFlags) & 0x80));
    r.a = rd(0xC487);
    r.e = 3;
    gb_native_MultiplyByDE();
    uint16_t at = 0x25CB + r.a;
    uint8_t spin = rd(hFrameSpin);
    if (spin >= 0x7F) { at++; if (spin >= 0xCD) at++; }
    uint8_t prize = rd(at);
    wr(hScratch00, prize);
    for (uint16_t slot = wMagicCards;; slot++) {
        uint8_t have = rd(slot);
        if (have == 0) { wr(slot, prize); break; }
        if (have == prize) break;
    }
    wr(wBonusChoice, prize);
    return gb_native_Mode2_Init();
}

/* Mode2_Init: (re)draws the bonus screen of the current step (wPlayerBlocked: door picture lists from BonusSelectJobTable, the text strips; in the result step the card
 * name and picture) and continues with the routine of that step (BonusModeJumpTable). */
void *gb_native_Mode2_Init(void) {
    NCALL(GAME_LcdOff);
    ime = 0;
    r.a = rd(wPlayerBlocked);
    SET_HL(DATA_BonusSelectJobTable);
    gb_native_LookupWord();
    SET_DE(HL());
    SET_BC(0x270F);
    SET_HL(vBGMap0);
    wr(wMapCellMask, 0xFF);
    NCALL(GAME_DrawBonusMetatileMap);
    SET_BC(0x29B1);
    NCALL(GAME_RunVramCopyList);
    r.a = rd(wPlayerBlocked);
    if (r.a == 0) {
        SET_DE(0x264A);
        SET_HL(0x988C);
        NCALL(GAME_VramCopyStream);
    }
    if (r.a == 0x02) {
        r.a = rd(wBonusChoice);
        SET_HL(0x269B);
        gb_native_LookupWord();
        SET_DE(HL());
        SET_HL(0x9886);
        NCALL(GAME_VramCopyStream);
        r.a = rd(wBonusChoice);
        SET_HL(0x2651);
        gb_native_LookupWord();
        SET_DE(HL());
        SET_HL(0x98C9);
        NCALL(GAME_VramCopyStream);
    }
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadow);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    wr(rIE, IE_VBLANK);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    r.a = rd(wPlayerBlocked);
    SET_HL(0x253B);
    gb_native_LookupWord();
    return (void *)gb_dispatch(HL());
}

/* Mode2_BonusSelect: the bonus screen: counts the screen ($c487), step 0, the bonus music, tiles of bank 3, the cursor; then Mode2_Init. */
void *gb_native_Mode2_BonusSelect(void) {
    r.sp = wStackTop;
    wr(0xC487, rd(0xC487) + 1);
    wr(wPlayerBlocked, 0);
    r.a = SND_MUSIC_BONUS_SELECT;
    NCALL(GAME_PlaySound);
    NCALL(GAME_LcdOff);
    ime = 0;
    NCALL(GAME_LoadTilesBank3C);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    gb_native_InitBonusCursor();
    return gb_native_Mode2_Init();
}

/* Mode6_Ending: the castle scene after the last round. The setup draws the castle with metatiles (D_00_31a6 cells, D_00_3156 blocks), creates the two scene objects
 * (the hero walking in at X $80, Y $68, heading $18, and the castle flag object), starts the ending music and runs the scene (castle blink and walk) until the hero
 * has arrived (wEndingEvents bit 7). Then the credit pages scroll up (EndingSetup, scroll, credits window); wCheatFlags and wCheatTimer serve as counters here
 * ($10 frames per page step and 5 rounds after the last page). Finally the game restarts (Entry). */
void *gb_native_Mode6_Ending(void) {
    r.sp = wStackTop;
    NCALL(GAME_LcdOff);
    ime = 0;
    NCALL(GAME_LoadTilesBank3D);
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    SET_HL(0x9FFF);
    gb_native_FillBackwardsFF();
    NCALL(GAME_ClearOamShadowY);
    NCALL(GAME_RequestOamDma);
    wr(hScratch01, 0x06);
    wr(hScratch00, 0x0A);
    SET_HL(0x98C0);
    SET_BC(0x3156);
    SET_DE(0x31A6);
    wr(wMapCellMask, 0xFF);
    gb_native_DrawMetatileMap();
    SET_HL(wEndingObject);
    SET_BC(0x0041);
    gb_native_ClearMemory();
    wr(wEndingObject, 0x80);
    wr(wEndingObject2, 0x80);
    wr(0xC770, 0x31);
    wr(0xC76F, 0x43);
    wr(wEndingX, 0x80);
    wr(wEndingY, 0x68);
    wr(wEndingSpeed, 0x04);
    wr(wEndingAngle, 0x18);
    wr(wEnding2X, 0x70);
    wr(wEnding2Y, 0x68);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    NCALL(GAME_EndingCastleBlink);
    NCALL(GAME_EndingWalkStep);
    r.a = SND_MUSIC_ENDING;
    NCALL(GAME_PlaySound);
    r.a = 0x46;
    NCALL(GAME_DelayFrames);
    NCALL(GAME_EndingCastleBlink);
    NCALL(GAME_EndingWalkStep);
    do {
        NCALL(GAME_WaitFrameAndSyncOam);
        NCALL(GAME_EndingCastleBlink);
        NCALL(GAME_EndingWalkStep);
    } while (!(rd(wEndingEvents) & 0x80));
    NCALL(GAME_EndingSetup);
    wr(wCheatFlags, 0x10);
    wr(wCheatTimer, 0x05);
    for (;;) {
        NCALL(GAME_WaitFrameAndSyncOam);
        NCALL(GAME_EndingScrollStep);
        NCALL(GAME_EndingTick);
        NCALL(GAME_EndingCreditsWindow);
        NCALL(GAME_ReadJoypad);
        if (rd(wCreditsPage) != 0x08) continue;
        wr(wCheatFlags, rd(wCheatFlags) - 1);
        if (rd(wCheatFlags) != 0) continue;
        uint8_t timer = rd(wCheatTimer) - 1;
        wr(wCheatTimer, timer);
        if (!(timer & 0x80)) continue;
        return (void *)GAME_Entry;
    }
}

/* ---- the ending scene ----
 * Two objects: wEndingObject (the hero walking in, then standing in front of the castle) and wEndingObject2 (the castle with its blinking flag; its flag bits 0-2 also
 * track the credits window: 0 window shown, 1 slid in, 2 slid out). wEndingStep and wEndingPhase form a 16 bit counter; wEndingEvents bit 2 = the hero has arrived,
 * bit 7 = the walk-in has finished. The credit text pages (CreditsPageTable) are queued one by one while the window (rWX) slides in and out. */
void *gb_native_SelectEndingObject(void) { SET_HL(wEndingObject); return gb_native_SetObjPtr(); }

void *gb_native_EndingScrollStep(void) {
    uint8_t lo = rd(wEnding2Y);
    wr(wEnding2Y, lo - 0x5A);
    uint8_t hi = rd(wEnding2Y + 1) - (lo < 0x5A ? 1 : 0);
    wr(wEnding2Y + 1, hi);
    wr(wScrollX, hi);
    r.a = hi;
    return 0;
}

void *gb_native_EndingAdvance(void) {
    unsigned step = rd(wEndingStep) + 0x10;
    wr(wEndingStep, step);
    uint8_t phase = rd(wEndingPhase) + (step >> 8);
    wr(wEndingPhase, phase);
    if (phase != 0x05) return 0;
    SET_HL(wEndingEvents);
    wr(wEndingEvents, rd(wEndingEvents) | 0x80);
    return 0;
}

void *gb_native_EndingWalkStep(void) {
    if (rd(wEndingY) < 0x08) return gb_native_EndingAdvance();
    wr(0xC780, rd(0xC780) + 1);
    if (rd(0xC780) & 0x10) {
        wr(wEndingSpeed, rd(wEndingSpeed) + 1);
        wr(wEndingAngle, rd(wEndingAngle) + 1);
        wr(0xC780, 0);
    }
    gb_native_SelectEndingObject();
    gb_native_MoveObject();
    gb_native_ApplyObjectStep();
    gb_native_SelectEndingObject();
    return gb_native_DrawObject();
}

void *gb_native_EndingCastleBlink(void) {
    wr(0xC7A0, rd(0xC7A0) + 1);
    uint16_t entry = 0x3148 + ((rd(0xC7A0) & 0x08) >> 2);
    wr(wEndingObject2 + 1, rd(entry));
    wr(wEndingObject2 + 2, rd(entry + 1));
    SET_HL(wEndingObject2);
    gb_native_SetObjPtr();
    return gb_native_DrawObject();
}

void *gb_native_EndingHeroFrame(void) {
    wr(wEndingSpeed, 0x02);
    wr(wEndingAngle, (rd(wEndingPhase) & 0x01) ? 0x10 : 0x00);
    gb_native_SelectEndingObject();
    gb_native_MoveObject();
    gb_native_ApplyObjectStep();
    SET_HL(wEndingStep);
    wr(wEndingStep, rd(wEndingStep) - 1);
    if (rd(wEndingStep)) return 0;
    wr(wEndingStep, 0x0A);
    wr(wEndingPhase, rd(wEndingPhase) + 1);
    return 0;
}

void *gb_native_EndingMoveHero(void) {
    gb_native_EndingHeroFrame();
    if (rd(wEndingEvents) & 0x04) return 0;
    uint8_t x = rd(wEndingX);
    if (x == 0x50) { SET_HL(wEndingEvents); wr(wEndingEvents, rd(wEndingEvents) | 0x04); return 0; }
    wr(wEndingX, x - 1);
    return 0;
}

void *gb_native_EndingAnimateObject(void) {
    wr(0xC780, rd(0xC780) + 1);
    uint16_t table = (rd(wEndingEvents) & 0x04) ? 0x3111 : 0x30DF;
    uint16_t entry = table + ((rd(0xC780) & 0x08) >> 2);
    wr(0xC76F, rd(entry));
    wr(0xC770, rd(entry + 1));
    SET_HL(wEndingObject);
    gb_native_SetObjPtr();
    return gb_native_DrawObject();
}

void *gb_native_EndingTick(void) {
    gb_native_EndingMoveHero();
    return gb_native_EndingAnimateObject();
}

/* EndingSetup: after the walk-in the screen is cleared and the credits layout (jobs $30c4 and $3009) is loaded; the hero is placed at X $c8, Y $50. */
void *gb_native_EndingSetup(void) {
    NCALL(GAME_LcdOff);
    ime = 0;
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    NCALL(GAME_ClearOamShadowY);
    NCALL(GAME_RequestOamDma);
    SET_HL(wEndingObject);
    SET_BC(0x0041);
    gb_native_ClearMemory();
    wr(wCameraX, 0);
    wr(wCameraY, 0);
    SET_BC(0x30C4);
    gb_native_RunVramCopyList();
    wr(wEndingObject, 0x80);
    wr(wEndingX, 0xC8);
    wr(wEndingY, 0x50);
    wr(wEndingStep, 0x0A);
    SET_BC(0x3009);
    gb_native_RunVramCopyList();
    wr(rIF, 0);
    wr(rIE, IE_VBLANK);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    return 0;
}

void *gb_native_RunEndingTextListAndWait(void) {
    SET_BC(0x2DFF);
    gb_native_QueueVramCopyList();
    while (rd(wVramCopyFlags) & 0x01) gb_host_vblank();      /* the original spins on the flag; the frame is what clears it */
    return 0;
}

void *gb_native_EndingShowCreditsPage(void) {
    gb_native_EndingScrollStep();
    gb_native_RunEndingTextListAndWait();
    gb_native_EndingScrollStep();
    r.a = rd(wCreditsPage);
    SET_HL(DATA_CreditsPageTable);
    gb_native_LookupWord();
    gb_native_QueueVramCopyList();
    NCALL(GAME_WaitVramCopyDone);
    return 0;
}

/* EndingCreditsWindow: once the hero has arrived the window (rWY $5a, rWX $a5) is turned on and slides in 5 pixels a frame to X $0a, the page is shown until its timer
 * ends, the window slides out again and the next page follows (the last page is number 8). */
void *gb_native_EndingCreditsWindow(void) {
    if (!(rd(wEndingEvents) & 0x04)) return 0;
    if (!(rd(wEndingObject2) & 0x01)) {
        wr(rWY, 0x5A);
        wr(rWX, 0xA5);
        wr(rLCDC, rd(rLCDC) | 0x60);
        SET_HL(wEndingObject2);
        wr(wEndingObject2, rd(wEndingObject2) | 0x01);
        wr(wEndingObject2 + 1, 0xFF);
        gb_native_EndingShowCreditsPage();
    }
    if (!(rd(wEndingObject2) & 0x04)) {
        if (!(rd(wEndingObject2) & 0x02)) {
            wr(rWX, rd(rWX) - 5);
            SET_HL(rWX);
            r.a = rd(rWX);
            alu_cp(0x0A);
            if (r.a != 0x0A) return 0;
            SET_HL(wEndingObject2);
            wr(wEndingObject2, rd(wEndingObject2) | 0x02);
            return 0;
        }
        if (rd(wCreditsPage) == 0x08) return 0;
        SET_HL(wEndingObject2 + 1);
        wr(wEndingObject2 + 1, rd(wEndingObject2 + 1) - 1);
        if (rd(wEndingObject2 + 1)) return 0;
        wr(wEndingObject2 + 1, 0xFF);
        SET_HL(wEndingObject2);
        wr(wEndingObject2, (rd(wEndingObject2) & ~0x02) | 0x04);
        return 0;
    }
    wr(rWX, rd(rWX) + 5);
    SET_HL(rWX);
    r.a = rd(rWX);
    if (r.a != 0xA5) return 0;
    wr(wEndingObject2, 0);
    SET_HL(wCreditsPage);
    wr(wCreditsPage, rd(wCreditsPage) + 1);
    gb_native_EndingShowCreditsPage();
    return 0;
}

/* ContinueCursorInput: B (hJoyNew bit 5... the pad bits $30: left or right) puts the cursor on YES (X $3c, wMagicCol 0) or NO (X $74, wMagicCol 1). */
void *gb_native_ContinueCursorInput(void) {
    uint8_t pad = rd(hJoyNew) & 0x30;
    r.a = pad;
    if (!pad) return 0;
    if (pad & 0x10) { wr(wCursorX, 0x74); wr(wMagicCol, 1); r.a = 1; }
    else { wr(wCursorX, 0x3C); wr(wMagicCol, 0); r.a = 0; }
    return 0;
}

/* Mode5_Continue: "CONTINUE?" with YES and NO and a countdown (wPlayerBlocked from $f0, one per frame; at 0 the game restarts). YES (A on the left): the round and
 * the cards are kept and wContinues goes down, then mode 3; NO: everything is reset (round 1, no cards, new continues) and mode 4 (game over) follows. Link games exchange the
 * answer over the cable. wCheatFlags bit 0 (the title code) gives endless continues, shown as two special tiles. */
void *gb_native_Mode5_Continue(void) {
    r.sp = wStackTop;
    NCALL(GAME_LcdOff);
    ime = 0;
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    SET_HL(wCursorObject);
    gb_native_Clear32Bytes();
    NCALL(GAME_LoadTilesBank3A);
    NCALL(GAME_ClearOamShadow);
    SET_BC(0x2085);
    NCALL(GAME_RunVramCopyList);
    SET_HL(0x2083);
    gb_native_SetCursorAnimation();
    wr(wCursorX, 0x3C);
    wr(wCursorY, 0x50);
    wr(wCursorObject, 0x80);
    wr(wScrollX, 0);
    wr(wScrollY, 0);
    wr(wMagicCol, 0);
    NCALL(GAME_RequestOamDma);
    NCALL(GAME_ClearOamShadowY);
    if (rd(wCheatFlags) & 0x01) {
        wr(wContinues, 0xFF);
        wr(wTextBuf, 0x02);
        wr(wTextBuf + 1, 0x01);
        wr(wTextBuf + 2, 0xCD);
        wr(wTextBuf + 3, 0xCE);
    } else {
        wr(wTextBuf, 0x01);
        wr(wTextBuf + 1, 0x01);
        r.a = rd(wContinues);
        NCALL(GAME_NumberToTile);
        wr(wTextBuf + 2, r.a);
    }
    SET_DE(wTextBuf);
    SET_HL(0x98A9);
    NCALL(GAME_VramCopyStream);
    wr(rBGP, PAL_NORMAL);
    wr(rOBP0, PAL_NORMAL);
    wr(rOBP1, PAL_NORMAL);
    wr(rSB, 0xEE);
    NCALL(GAME_SerialStartTransfer);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    wr(wPlayerBlocked, 0xF0);
    for (;;) {
        NCALL(GAME_WaitFrameAndSyncOam);
        if (rd(hSerialByte) & 0x10) goto remote_round;
        if (rd(hLinkFlags) & 0x08) { r.a = 4; return (void *)GAME_GameModeDispatch; }
        NCALL(GAME_ReadJoypad);
        gb_native_ContinueCursorInput();
        SET_HL(wCursorObject);
        gb_native_SetObjPtr();
        NCALL(GAME_DrawObjectBytePos);
        SET_HL(wPlayerBlocked);
        wr(wPlayerBlocked, rd(wPlayerBlocked) - 1);
        if (rd(wPlayerBlocked) == 0) return (void *)GAME_Entry;
        if (!(rd(hJoyNew) & 0x01)) continue;
        break;
    }
    if (rd(wMagicCol) != 0) {                      /* NO */
        wr(wRoomIndex, 0);
        wr(wRound, 1);
        wr(wRoundBackup, 1);
        SET_HL(wMagicCards);
        SET_BC(0x0008);
        gb_native_ClearMemory();
        if (rd(hLinkFlags) & 0x01) { r.c = 0x10; NCALL(GAME_SerialSendByte); }
        wr(wContinues, (rd(wCheatFlags) & 0x01) ? 0xFF : 0x05);
        r.a = 4;
        return (void *)GAME_GameModeDispatch;
    }
    if (rd(hLinkFlags) & 0x01) {                   /* YES in a link game: pick the round and tell the other machine */
        NCALL(GAME_PickRandomRound);
        if (!(rd(rSC) & 0x80)) goto remote_round;
        r.c = rd(wRound) | 0x80;
        NCALL(GAME_SerialSendByte);
    }
    goto yes;
remote_round:
    wr(rSB, 0);
    wr(hSerialByte, 0);
    wr(wRound, rd(wRemoteRound));
    wr(wRoundBackup, rd(wRemoteRound));
    wr(wRoomIndex, rd(wRemoteRound) - 1);
yes:
    wr(wRoundFlags, rd(wRoundFlags) & ~0x04);
    wr(wContinues, rd(wContinues) - 1);
    r.a = 3;
    return (void *)GAME_GameModeDispatch;
}

/* ---- the title screen ---- */

/* InitTitleVariables: link flags, the code flags, the cards and the bonus counter are cleared; 5 continues; the cursor object at X $34, Y $64 with its animation. */
void *gb_native_InitTitleVariables(void) {
    wr(hLinkFlags, 0);
    wr(wCheatFlags, 0);
    for (int i = 0; i < 9; i++) wr(wMagicCards + i, 0);
    wr(0xC487, 0);
    wr(wContinues, 0x05);
    wr(wCursorX, 0x34);
    wr(wCursorY, 0x64);
    wr(wCursorObject, 0x80);
    SET_HL(0x2B84);
    return gb_native_SetCursorAnimation();
}

/* TitleCursorUpdate: Select (hJoyNew = 4) toggles the cursor between 1 PLAYER (Y $64) and 2 PLAYER (Y $74); the cursor object is drawn. */
void *gb_native_TitleCursorUpdate(void) {
    if (rd(hJoyNew) == 0x04) wr(wCursorY, rd(wCursorY) == 0x64 ? 0x74 : 0x64);
    SET_HL(wCursorObject);
    gb_native_SetObjPtr();
    return (void *)GAME_DrawObjectBytePos;
}

/* PickRandomRound (link games): wRound = a random number 1-30 from hRngCounter (the value $1f gives $1e); wRoundBackup and wRoomIndex follow. */
void *gb_native_PickRandomRound(void) {
    uint8_t round;
    for (;;) {
        gb_native_NextRandomDirection();
        round = rd(hRngCounter) & 0x1F;
        if (round) break;
    }
    if (round == 0x1F) round--;
    wr(wRound, round);
    wr(wRoundBackup, round);
    wr(wRoomIndex, round - 1);
    r.a = round - 1;
    return 0;
}

/* Mode0_Title: sets up the title (tiles, music, the logo list, the cursor) and runs TitleLoop. The loop: a serial byte with bit 4 means the other machine started a link game
 * (the round it sent is taken over); the pad value $93 held goes to the ending (mode 6, a test) and $47 sets the unlimited continues flag (wCheatFlags bit 0); Start (hJoyNew = 8)
 * on 1 PLAYER starts mode 3 at round 1 (the serial register is cleared and $88 sent so a partner machine joins as the second player); on 2 PLAYER a random round is sent and the
 * answer decides: no partner leaves the cursor on 1 PLAYER, a partner starts a link game. */
void *gb_native_Mode0_Title(void) {
    r.sp = wStackTop;
    NCALL(GAME_LcdOff);
    ime = 0;
    NCALL(GAME_LoadTilesBank3A);
    r.a = SND_MUSIC_TITLE;
    NCALL(GAME_PlaySound);
    SET_HL(vBGMapLast);
    gb_native_FillBackwardsFF();
    SET_BC(0x2B86);
    NCALL(GAME_RunVramCopyList);
    NCALL(GAME_RequestOamDma);
    SET_HL(wCursorObject);
    gb_native_Clear32Bytes();
    gb_native_InitTitleVariables();
    wr(rSB, 0xEE);
    NCALL(GAME_SerialStartTransfer);
    wr(rIF, 0);
    wr(rIE, IE_VBLANK_SERIAL);
    wr(rLCDC, LCDC_ON_BG_OBJ);
    ime = 1;
    for (;;) {
        NCALL(GAME_WaitFrameAndSyncOam);
        if (rd(hSerialByte) & 0x10) goto partner_started;
        NCALL(GAME_ReadJoypad);
        if (rd(hJoyHeld) == 0x93) { r.a = 6; return (void *)GAME_GameModeDispatch; }
        if (rd(hJoyHeld) == 0x47) wr(wCheatFlags, rd(wCheatFlags) | 0x01);
        call_native(gb_native_TitleCursorUpdate);
        if (rd(wCheatFlags) & 0x20) {
            wr(wCheatTimer, rd(wCheatTimer) - 1);
            if (rd(wCheatTimer) != 0) {
                if (rd(wCursorY) != 0x64) continue;
                if (rd(hJoyNew) != 0x08) continue;
                goto one_player;
            }
            wr(wCheatFlags, rd(wCheatFlags) & ~0x20);
        }
        if (rd(hJoyNew) != 0x08) continue;
        if (rd(wCursorY) == 0x64) goto one_player;
        NCALL(GAME_PickRandomRound);
        r.c = rd(wRound) | 0x80;
        NCALL(GAME_SerialSendByte);
        {
            uint8_t answer = rd(rSB);
            if (answer == 0xEE) { wr(wCheatFlags, rd(wCheatFlags) & ~0x22); }
            else if (answer == 0xFF) { wr(wCheatFlags, rd(wCheatFlags) | 0x02); }
            else if (answer == 0x88) { wr(wCheatTimer, 0xA0); wr(wCheatFlags, rd(wCheatFlags) | 0x20); }
            else { wr(wCursorY, 0x64); continue; }
        }
        if ((rd(wCheatFlags) & 0x02) || (rd(wCheatFlags) & 0x20)) { wr(wCursorY, 0x64); continue; }
        SET_HL(hLinkFlags);
        wr(hLinkFlags, rd(hLinkFlags) | 0x01);
        r.a = 3;
        return (void *)GAME_GameModeDispatch;
    }
partner_started:
    wr(hLinkFlags, rd(hLinkFlags) | 0x01);
    wr(wRound, rd(wRemoteRound));
    wr(wRoundBackup, rd(wRemoteRound));
    wr(wRoomIndex, rd(wRemoteRound) - 1);
    r.a = 3;
    return (void *)GAME_GameModeDispatch;
one_player:
    wr(rSC, rd(rSC) & ~0x80);
    wr(rSB, 0x88);
    NCALL(GAME_SerialStartTransfer);
    SET_HL(wCheatFlags);
    wr(wCheatFlags, rd(wCheatFlags) | 0x08);
    wr(wRound, 1);
    wr(wRoundBackup, 1);
    wr(wRoomIndex, 0);
    r.a = 3;
    return (void *)GAME_GameModeDispatch;
}

/* ---- small setup routines ---- */
void *gb_native_ClearRoundVariables(void) {
    wr(wExtraLifeIdx, 0);
    wr(wScoreDigits, 0); wr(wScoreDigits + 1, 0); wr(wScoreDigits + 2, 0);
    for (int i = 0; i < 6; i++) wr(wScoreDecimal + i, 0);
    wr(wScoreStream, 0x06);
    wr(wScoreStream + 1, 0x01);
    for (int i = 0; i < 6; i++) wr(wScoreStream + 2 + i, 0xAB);
    r.a = 0xAB;
    return 0;
}

/* CheckExtraLife: once the second score byte has reached 2 (a score of 200 or more in base 100 digits), a life is added each time the top score digit ($c46a) hits the next value of
 * the table at $11e7 (the index wExtraLifeIdx runs through 5 entries). */
void *gb_native_CheckExtraLife(void) {
    if (!(rd(wRoundFlags) & 0x02)) {
        if (rd(wScoreDigits + 1) < 0x02) return 0;
        SET_HL(wRoundFlags);
        wr(wRoundFlags, rd(wRoundFlags) | 0x02);
    }
    uint8_t digit = rd(wScoreDecimal + 3);
    uint8_t index = rd(wExtraLifeIdx);
    if (index == 0x05) { index = 0; wr(wExtraLifeIdx, 0); }
    if (rd(0x11E7 + index) != digit) return 0;
    wr(wLives, rd(wLives) + 1);
    SET_HL(wExtraLifeIdx);
    wr(wExtraLifeIdx, rd(wExtraLifeIdx) + 1);
    return 0;
}

/* InitMagicPoints: the magic points of the round from MagicPointsTable (16 bit per round), or $0140 in a link game. */
void *gb_native_InitMagicPoints(void) {
    if (rd(hLinkFlags) & 0x01) {
        wr(wMagicPoints, 0x40);
        wr(wMagicPointsHi, 0x01);
    } else {
        uint16_t entry = 0x1462 + (uint8_t)(rd(wRound) << 1);
        wr(wMagicPointsHi, rd(entry));
        wr(wMagicPoints, rd(entry + 1));
    }
    wr(0xFFEA, 0);
    r.a = 0;
    return 0;
}

void *gb_native_InitMagicScreenState(void) {
    wr(wMagicCol, 0); wr(wMagicRow, 0); wr(wCursorBlink, 0); wr(wMagicScreenFlags, 0);
    SET_HL(wCursorObject);
    gb_native_Clear32Bytes();
    wr(wCursorObject, 0xA0);
    wr(wCursorX, 0x28);
    wr(wCursorY, 0x68);
    SET_HL(0x1A30);
    return gb_native_SetCursorAnimation();
}

void *gb_native_ClearEnemySlot(void) { SET_HL(hObject2); return gb_native_Clear32Bytes(); }

void *gb_native_ClearAllEnemies(void) {
    for (int i = 15; i >= 0; i--) {
        wr(wEnemyLoopIdx, i);
        r.a = i;
        SET_HL(DATA_EnemySlotTable);
        gb_native_SelectEnemySlot();
        wr(HL(), 0);
    }
    wr(wEnemyLoopIdx, 0xFF);
    r.a = 0xFF;
    return 0;
}

/* FindFreeEnemySlot: scans the 16 slots from 15 down for one that is not in use and creates an enemy there from hScratch07 (kind), hScratch08 (X), hScratch0A (Y)
 * and hSpawnFlag: flags $82, then the slot is stored. */
void *gb_native_FindFreeEnemySlot(void) {
    for (int i = 15; i >= 0; i--) {
        wr(hScratch00 + 6, i);
        r.a = i;
        SET_HL(DATA_EnemySlotTable);
        gb_native_SelectEnemySlot();
        if (rd(HL()) & 0x80) continue;
        gb_native_ClearEnemySlot();
        wr(hObject2, 0x82);
        wr(hEnemyKind, rd(hScratch00 + 7));
        wr(hEnemyX, rd(hScratch00 + 8));
        wr(hEnemyY, rd(hScratch00 + 10));
        wr(hEnemySpawnFlag, rd(hSpawnFlag));
        return gb_native_StoreEnemySlot();
    }
    wr(hScratch00 + 6, 0xFF);
    return 0;
}

/* DrawDecimalDigits: HL = one byte of the score, BC = index into wScoreDecimal: its two digits go there (tens first); BC advances by 2; HL is kept. */
void *gb_native_DrawDecimalDigits(void) {
    uint16_t hl = HL(), bc = BC();
    r.a = rd(hl);
    r.c = 0;
    gb_native_ByteToBCD();
    uint8_t digits = rd(hScratch00 + 2);
    wr(wScoreDecimal + bc, digits >> 4);
    wr(wScoreDecimal + bc + 1, digits & 0x0F);
    SET_BC(bc + 2);
    SET_HL(hl);
    r.d = digits;
    return 0;
}

void *gb_native_SetEnemyHitFlag(void) { SET_HL(hEnemyFlags); wr(hEnemyFlags, rd(hEnemyFlags) | 0x04); return 0; }
void *gb_native_CancelMagic(void) { wr(wActiveMagic, 0); wr(wMagicState, 0); r.a = 0; return 0; }
void *gb_native_EndMagic(void) { wr(wMagicState, 0); r.a = 0; return 0; }
void *gb_native_ClearBonusFlags(void) { SET_HL(wGameFlags); wr(wGameFlags, rd(wGameFlags) & 0x7E); return 0; }
void *gb_native_SetPlayerStatusBit0(void) { SET_HL(wPlayerStatus); wr(wPlayerStatus, rd(wPlayerStatus) | 0x01); wr(wPlayerSpeed, 0); r.a = 0; return 0; }
void *gb_native_BeginMagicCast(void) {
    r.a = SND_SFX_82;
    NCALL(GAME_PlaySound);
    SET_HL(wMagicState);
    wr(wMagicState, rd(wMagicState) | 0x02);
    return 0;
}

/* AnimatePlayerWalk: while a direction is held (hJoyHeld high nibble) the walk counter wWalkAnimCount runs through CounterToFrame (mask $0c, shift 2, 4 frames) and
 * wPlayerAnim takes the animation pointer at that position of the table chosen by SelectPlayerAnimation (wPlayerAnimPtr). */
void *gb_native_AnimatePlayerWalk(void) {
    if (!(rd(hJoyHeld) & 0xF0)) { r.a = 0; r.f = 0x80; return 0; }
    wr(wWalkAnimCount, rd(wWalkAnimCount) + 1);
    wr(hScratch00 + 6, 0x0C);
    wr(hScratch00 + 7, 0x02);
    wr(hScratch00 + 8, rd(wWalkAnimCount));
    r.a = 0x04;
    gb_native_CounterToFrame();
    wr(wWalkAnimCount, rd(hScratch00 + 8));
    uint16_t entry = (uint16_t)((rd(wPlayerAnimPtrLo) | rd(wPlayerAnimPtrHi) << 8) + r.c);
    wr(wPlayerAnimLo, rd(entry));
    wr(wPlayerAnimHi, rd(entry + 1));
    return 0;
}

/* EnemyShooterAI (kind 2): the shot of the enemy. While T.STOP (3) or B.O.M (5) runs, or when its timer $c4b4 ($a0 frames) ends, the shot is removed and the enemy gets
 * a short pause (hEnemyStep = 5). While a shot is live it blinks between two animations (every 16 counts of $c4b9) and is drawn. */
void *gb_native_EnemyShooterAI(void) {
    uint8_t card = rd(wActiveMagic);
    int cut = ((card == 0x03) || (card == 0x05)) && (rd(wMagicState) & 0x01);
    if (!cut) {
        if (!(rd(wProjectile) & 0x80)) return 0;
        wr(0xC4B4, rd(0xC4B4) - 1);
        if (rd(0xC4B4) != 0) {
            wr(0xC4B9, rd(0xC4B9) + 1);
            uint16_t anim = (rd(0xC4B9) & 0x10) ? 0x59F5 : 0x59FA;
            wr(wProjectileAnimLo, (uint8_t)anim);
            wr(wProjectileAnimHi, anim >> 8);
            SET_HL(wProjectile);
            gb_native_SetObjPtr();
            return gb_native_DrawObject();
        }
    }
    wr(hEnemyStep, 0x05);
    wr(0xC4B4, 0xA0);
    SET_HL(wProjectile);
    wr(wProjectile, rd(wProjectile) & 0x7F);
    return 0;
}

/* EnemyKind10Animate: the projectile of kind 10 alternates between two animations ($57ec and $57ee) every 4 counts of hEnemyCounter2. */
void *gb_native_EnemyKind10Animate(void) {
    if (rd(hEnemyKind) != 0x0A) return 0;
    SET_HL(hEnemyCounter2);
    wr(hEnemyCounter2, rd(hEnemyCounter2) + 1);
    uint16_t anim = (rd(hEnemyCounter2) & 0x04) ? 0x57EE : 0x57EC;
    wr(wProjectileAnimLo, (uint8_t)anim);
    wr(wProjectileAnimHi, anim >> 8);
    return 0;
}

void *gb_native_EnemyFlagBit3IfDead(void) {
    if (rd(hEnemyDir) & 0x20) { SET_HL(hEnemyFlags); wr(hEnemyFlags, rd(hEnemyFlags) | 0x08); }
    return 0;
}

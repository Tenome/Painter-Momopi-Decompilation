/* Native replacements for the routines that wait for hardware timing (VBlank, LY, serial, joypad register).
 * The recompiler generates stubs for the labels listed in port/overrides.txt that call gb_native_<Label>() and then return.
 * With these in place nothing in the runtime counts cycles or raises interrupts: the game is driven one frame at a time by
 * gb_host_vblank(), which renders, mixes sound, presents the frame and runs the game's own VBlankHandler. */
#include "gb_rt.h"

#define hVBlankFlag  0xFF91
#define hSavedIE     0xFF92
#define hVBlankTasks 0xFFB3
#define hFrameCounter 0xFFB4
#define hJoyHeld     0xFF8B
#define hJoyNew      0xFF8C
#define hRngCounter  0xFFDA
#define hFrameSpin   0xFFDB
#define hLinkFlags   0xFFED
#define hSerialByte  0xFFEB
#define rSB          0xFF01
#define rSC          0xFF02
#define rIF          0xFF0F
#define rLCDC        0xFF40
#define rIE          0xFFFF

static void rng_tick(void) {
    /* the original counts loop iterations while waiting for VBlank: effectively random; any varying value will do */
    wr(hRngCounter, (uint8_t)(rd(hRngCounter) + 61 + ((gb_frames * 7) & 0x3F)));
    wr(hFrameSpin, (uint8_t)(rd(hFrameSpin) + 3));
}

/* WaitVBlankFlag: spin until the VBlank handler has run once (preserves all registers) */
void *gb_native_WaitVBlankFlag(void) {
    Regs s = r;
    wr(hVBlankFlag, 0);
    rng_tick();
    gb_host_vblank();
    r = s;
    return 0;
}

/* DelayFrames: A frames (256 when A is 0) */
void *gb_native_DelayFrames(void) {
    Regs s = r;
    unsigned n = r.a ? r.a : 256;
    while (n--) { rng_tick(); gb_host_vblank(); }
    r = s;
    return 0;
}

/* WaitFrameAndSyncOam: wait for one VBlank, request OAM DMA for the next one, wait for it, clear the frame counter */
void *gb_native_WaitFrameAndSyncOam(void) {
    Regs s = r;
    if (rd(hFrameCounter) < 1) { rng_tick(); gb_host_vblank(); }
    wr(hVBlankTasks, rd(hVBlankTasks) | 2);
    wr(hVBlankFlag, 0);
    gb_host_vblank();
    wr(hFrameCounter, 0);
    r = s;
    r.a = 0;
    return 0;
}

/* LcdOff: switch the LCD off (no need to wait for the scanline: nothing is being drawn) */
void *gb_native_LcdOff(void) {
    uint8_t ie_now = rd(rIE);
    wr(hSavedIE, ie_now);
    wr(rLCDC, rd(rLCDC) & 0x7F);
    r.a = ie_now;
    return 0;
}

/* ReadJoypad: hJoyHeld = D-pad in the high nibble, buttons in the low nibble; hJoyNew = newly pressed */
void *gb_native_ReadJoypad(void) {
    uint8_t held = (uint8_t)(((gb_joy & 0x0F) << 4) | ((gb_joy >> 4) & 0x0F));
    uint8_t old = rd(hJoyHeld);
    wr(hJoyNew, (uint8_t)((old ^ held) & held));
    wr(hJoyHeld, held);
    r.a = held;
    return 0;
}

/* Serial port: there is no link partner in the native build. A transfer as master completes at once and reads $ff. */
static void serial_master_done(void) {
    wr(rSB, 0xFF);
    wr(rSC, rd(rSC) & 0x7F);
    wr(hLinkFlags, rd(hLinkFlags) & 0xF1);
    wr(hSerialByte, 5);                      /* what SerialHandler stores for a finished internal clock transfer */
}

void *gb_native_SerialStartTransfer(void) {
    wr(rSC, (uint8_t)((rd(rSC) & 0xFE) | 0x80));
    return 0;
}

void *gb_native_WaitSerialByte(void) {
    serial_master_done();
    wr(rIF, 0);
    wr(rIE, 9);
    return 0;
}

void *gb_native_SerialSendByte(void) {
    serial_master_done();
    wr(hVBlankFlag, 0);
    gb_host_vblank();
    return 0;
}

/* WaitVramCopyDone: the VBlank handler clears bit 2 of hVBlankTasks when the queued row copy has been done */
void *gb_native_WaitVramCopyDone(void) {
    while (rd(hVBlankTasks) & 4) gb_host_vblank();
    r.a = rd(hVBlankTasks);
    return 0;
}

/* Headless driver for the recompiled game: scripted input, PGM screenshots, exit after N frames.
 *   game_headless ROM FRAMES [--press FRAME:BUTTON:HOLD]... [--shot FRAME]... [--outdir DIR] */
#include "gb_rt.h"

extern void gb_game_main(void);

#define MAXP 32
static struct { unsigned from, hold; uint8_t bit; } press[MAXP];
static int npress;
static unsigned shots[MAXP];
static int nshots;
static unsigned limit;
static const char *outdir = ".";

static void hook(unsigned frame) {
    uint8_t j = 0;
    for (int i = 0; i < npress; i++)
        if (frame >= press[i].from && frame < press[i].from + press[i].hold) j |= press[i].bit;
    gb_joy = j;
    for (int i = 0; i < nshots; i++)
        if (shots[i] == frame) {
            char p[512];
            snprintf(p, sizeof p, "%s/rc_%04u.pgm", outdir, frame);
            FILE *f = fopen(p, "wb");
            if (f) {
                fprintf(f, "P5\n160 144\n255\n");
                static const uint8_t sh[4] = {255, 170, 85, 0};
                for (int k = 0; k < 160 * 144; k++) fputc(sh[gb_framebuf[k] & 3], f);
                fclose(f);
            }
        }
    if (frame >= limit) { fprintf(stderr, "done after %u frames (cycles %llu)\n", frame, (unsigned long long)cycles); exit(0); }
}

static uint8_t button(const char *s) {
    static const char *n[] = {"right", "left", "up", "down", "a", "b", "select", "start"};
    for (int i = 0; i < 8; i++) if (!strcmp(s, n[i])) return 1u << i;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s ROM FRAMES [--press F:BTN:HOLD] [--shot F] [--outdir D]\n", argv[0]); return 1; }
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("rom"); return 1; }
    static uint8_t rom[1 << 20];
    size_t n = fread(rom, 1, sizeof rom, f);
    fclose(f);
    gb_load_rom(rom, n);
    limit = (unsigned)atoi(argv[2]);
    for (int i = 3; i < argc; i++) {
        if (!strcmp(argv[i], "--press") && i + 1 < argc && npress < MAXP) {
            char b[32]; unsigned fr, h;
            if (sscanf(argv[++i], "%u:%31[^:]:%u", &fr, b, &h) == 3) { press[npress].from = fr; press[npress].hold = h; press[npress].bit = button(b); npress++; }
        } else if (!strcmp(argv[i], "--shot") && i + 1 < argc && nshots < MAXP) shots[nshots++] = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--outdir") && i + 1 < argc) outdir = argv[++i];
    }
    if (getenv("GB_TRACE")) gb_trace = atoi(getenv("GB_TRACE"));
    gb_frame_hook = hook;
    gb_game_main();
    return 0;
}

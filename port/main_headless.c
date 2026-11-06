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
static unsigned rnd_seed;
static int random_mode;
static unsigned rnd(void) { rnd_seed = rnd_seed * 1103515245u + 12345u; return rnd_seed >> 16; }
static FILE *wav;
static unsigned wav_frames;
static int wav_peak;
static void audio(const int16_t *st, int n) {
    for (int i = 0; i < n * 2; i++) { int v = st[i] < 0 ? -st[i] : st[i]; if (v > wav_peak) wav_peak = v; }
    if (wav) { fwrite(st, 4, n, wav); wav_frames += n; }
}
static const char *outdir = ".";

static void hook(unsigned frame) {
    uint8_t j = 0;
    for (int i = 0; i < npress; i++)
        if (frame >= press[i].from && frame < press[i].from + press[i].hold) j |= press[i].bit;
    if (random_mode && frame > 253) {
        static uint8_t cur;
        if (frame % 25 == 0) { static const uint8_t pick[] = {0, 1, 2, 4, 8, 1, 2, 4, 8, 0x10, 0x20, 0x80, 0x40}; cur = pick[rnd() % 13]; }
        j |= cur;
    }
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
    if (frame >= limit) { fprintf(stderr, "done after %u frames (cycles %llu), audio peak %d\n", frame, (unsigned long long)cycles, wav_peak);
        if (wav) { unsigned bytes = wav_frames * 4, h[11] = {0x46464952, 36 + bytes, 0x45564157, 0x20746d66, 16, 0x20001, 44100, 44100 * 4, 0x100004, 0x61746164, bytes}; fseek(wav, 0, SEEK_SET); fwrite(h, 4, 11, wav); fclose(wav); } exit(0); }
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
        else if (!strcmp(argv[i], "--random") && i + 1 < argc) { random_mode = 1; rnd_seed = (unsigned)atoi(argv[++i]); }
        else if (!strcmp(argv[i], "--wav") && i + 1 < argc) { wav = fopen(argv[++i], "wb"); for (int k = 0; k < 44; k++) fputc(0, wav); }
    }
    if (getenv("GB_TRACE")) gb_trace = atoi(getenv("GB_TRACE"));
    gb_frame_hook = hook;
    gb_audio_hook = audio;
    gb_game_main();
    return 0;
}

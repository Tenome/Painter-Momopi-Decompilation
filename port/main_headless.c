/* Headless driver for the recompiled game: scripted input, PGM screenshots, exit after N frames.
 *   game_headless ROM FRAMES [--press FRAME:BUTTON:HOLD]... [--shot FRAME]... [--outdir DIR] */
#include "gb_rt.h"
#include "config.h"
#include "texture.h"

extern void gb_game_main(void);
extern const unsigned char gb_rom_image[];
extern const size_t gb_rom_image_size;

#define MAXP 32
static struct { unsigned from, hold; uint8_t bit; } press[MAXP];
static int npress;
static unsigned shots[MAXP];
static int nshots;
static unsigned limit;
static int force_round;
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

uint32_t gb_state_hash(void);
extern int gb_watch;
static FILE *hashes;
void gb_dump_state(const char *path);
static unsigned dump_frame = 0xFFFFFFFFu;
static const char *dump_path;

static struct { unsigned frame; uint16_t addr; uint8_t value; } pokes[64];
static int npokes;

static const char *song_path;

static void hook(unsigned frame) {
    if (song_path && frame == 120) gb_play_custom_song(song_path);     /* --song FILE: audition a music text file (with --wav) */
    for (int i = 0; i < npokes; i++)
        if (pokes[i].frame == frame) wr(pokes[i].addr, pokes[i].value);
    if (dump_path && frame == dump_frame) gb_dump_state(dump_path);
    if (hashes) fprintf(hashes, "%u %08x\n", frame, gb_state_hash());
    uint8_t j = 0;
    for (int i = 0; i < npress; i++)
        if (frame >= press[i].from && frame < press[i].from + press[i].hold) j |= press[i].bit;
    if (random_mode && frame > 253) {
        static uint8_t cur;
        if (frame % 25 == 0) { static const uint8_t pick[] = {0, 1, 2, 4, 8, 1, 2, 4, 8, 0x10, 0x20, 0x80, 0x40}; cur = pick[rnd() % 13]; }
        j |= cur;
    }
    if (force_round && frame == 254) { wr(0xC522, force_round); wr(0xC523, force_round); wr(0xC524, force_round - 1); }
    gb_joy = j;
    for (int i = 0; i < nshots; i++)
        if (shots[i] == frame) {
            char p[512];
            snprintf(p, sizeof p, "%s/rc_%04u.pgm", outdir, frame);
            int vw = gb_view_w;
            if (gb_tex_count) {                          /* a texture pack is active: save the colour picture as a PPM */
                snprintf(p, sizeof p, "%s/rc_%04u.ppm", outdir, frame);
                FILE *c = fopen(p, "wb");
                if (c) {
                    fprintf(c, "P6\n%d %d\n255\n", vw * gb_color_scale, 144 * gb_color_scale);
                    for (int k = 0; k < vw * gb_color_scale * 144 * gb_color_scale; k++) { uint32_t v = gb_colorbuf[k]; fputc(v >> 16, c); fputc(v >> 8, c); fputc(v, c); }
                    fclose(c);
                }
                continue;
            }
            FILE *f = fopen(p, "wb");
            if (f) {
                fprintf(f, "P5\n%d 144\n255\n", vw);
                static const uint8_t sh[4] = {255, 170, 85, 0};
                for (int k = 0; k < vw * 144; k++) fputc(sh[gb_framebuf[k] & 3], f);
                fclose(f);
            }
        }
    if (frame >= limit) { if (hashes) fclose(hashes); fprintf(stderr, "done after %u frames (cycles %llu), audio peak %d\n", frame, (unsigned long long)cycles, wav_peak);
        if (wav) { unsigned bytes = wav_frames * 4, h[11] = {0x46464952, 36 + bytes, 0x45564157, 0x20746d66, 16, 0x20001, 44100, 44100 * 4, 0x100004, 0x61746164, bytes}; fseek(wav, 0, SEEK_SET); fwrite(h, 4, 11, wav); fclose(wav); } exit(0); }
}

static uint8_t button(const char *s) {
    static const char *n[] = {"right", "left", "up", "down", "a", "b", "select", "start"};
    for (int i = 0; i < 8; i++) if (!strcmp(s, n[i])) return 1u << i;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s ROM FRAMES [--press F:BTN:HOLD] [--shot F] [--outdir D]\n", argv[0]); return 1; }
    static uint8_t rom[1 << 20];
    if (strcmp(argv[1], "-")) {                       /* a ROM file (for testing mods); "-" uses the data built into the program */
        FILE *f = fopen(argv[1], "rb");
        if (!f) { perror("rom"); return 1; }
        size_t n = fread(rom, 1, sizeof rom, f);
        fclose(f);
        gb_load_rom(rom, n);
    } else gb_load_rom(gb_rom_image, gb_rom_image_size);
    limit = (unsigned)atoi(argv[2]);
    for (int i = 3; i < argc; i++) {
        if (!strcmp(argv[i], "--press") && i + 1 < argc && npress < MAXP) {
            char b[32]; unsigned fr, h;
            if (sscanf(argv[++i], "%u:%31[^:]:%u", &fr, b, &h) == 3) { press[npress].from = fr; press[npress].hold = h; press[npress].bit = button(b); npress++; }
        } else if (!strcmp(argv[i], "--shot") && i + 1 < argc && nshots < MAXP) shots[nshots++] = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--ini") && i + 1 < argc) { gb_config_load(argv[++i]); gb_sprite_limit_off = gb_config.no_sprite_limit; }
        else if (!strcmp(argv[i], "--song") && i + 1 < argc) song_path = argv[++i];
        else if (!strcmp(argv[i], "--round") && i + 1 < argc) force_round = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--outdir") && i + 1 < argc) outdir = argv[++i];
        else if (!strcmp(argv[i], "--dump") && i + 2 < argc) { dump_frame = (unsigned)atoi(argv[i + 1]); dump_path = argv[i + 2]; i += 2; }
        else if (!strcmp(argv[i], "--poke") && i + 1 < argc && npokes < 64) {   /* FRAME:ADDRESS(hex):VALUE */
            unsigned f, a, v;
            if (sscanf(argv[++i], "%u:%x:%u", &f, &a, &v) == 3) { pokes[npokes].frame = f; pokes[npokes].addr = (uint16_t)a; pokes[npokes].value = (uint8_t)v; npokes++; }
        }
        else if (!strcmp(argv[i], "--watch") && i + 1 < argc) gb_watch = (int)strtol(argv[++i], 0, 16);
        else if (!strcmp(argv[i], "--hashes") && i + 1 < argc) hashes = fopen(argv[++i], "w");
        else if (!strcmp(argv[i], "--random") && i + 1 < argc) { random_mode = 1; rnd_seed = (unsigned)atoi(argv[++i]); }
        else if (!strcmp(argv[i], "--wav") && i + 1 < argc) { wav = fopen(argv[++i], "wb"); for (int k = 0; k < 44; k++) fputc(0, wav); }
    }
    if (getenv("GB_TRACE")) gb_trace = atoi(getenv("GB_TRACE"));
    gb_frame_hook = hook;
    gb_audio_hook = audio;
    gb_game_main();
    return 0;
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "texture.h"
#include "png.h"

GbTex *gb_texs;
int gb_tex_count, gb_tex_scale = 1;
static int table[8192];                 /* open addressing: index + 1 */
static int cap;

static uint64_t hash16(const uint8_t *p) {
    uint64_t h = 1469598103934665603ull;
    for (int i = 0; i < 16; i++) h = (h ^ p[i]) * 1099511628211ull;
    return h;
}

int gb_texture_find(const uint8_t *tile16) {
    if (!gb_tex_count) return -1;
    uint64_t h = hash16(tile16);
    for (unsigned i = (unsigned)h & 8191;; i = (i + 1) & 8191) {
        if (!table[i]) return -1;
        if (gb_texs[table[i] - 1].hash == h) return table[i] - 1;
    }
}

static void add(const GbTex *t) {
    if (gb_tex_count == cap) { cap = cap ? cap * 2 : 64; gb_texs = realloc(gb_texs, (size_t)cap * sizeof *gb_texs); }
    for (unsigned i = (unsigned)t->hash & 8191;; i = (i + 1) & 8191) {
        if (!table[i]) { gb_texs[gb_tex_count] = *t; table[i] = ++gb_tex_count; return; }
        if (gb_texs[table[i] - 1].hash == t->hash) { free(t->rgba); return; }       /* the same tile content in another sheet: the first one wins */
    }
}

int gb_texture_load(const char *folder) {
    static const uint8_t grey[4] = {255, 170, 85, 0};
    gb_tex_count = 0; gb_tex_scale = 1;
    memset(table, 0, sizeof table);
    int sheets_found = 0;
    for (int s = 0; s < gb_nsheets; s++) {
        char path[512];
        snprintf(path, sizeof path, "%s/%s.png", folder, gb_sheets[s].name);
        PngImage im;
        int rc = png_load(path, &im);
        if (rc == -1) continue;
        if (rc) { fprintf(stderr, "texture pack: cannot read %s (code %d)\n", path, rc); continue; }
        int n = im.w / 128, rows = (gb_sheets[s].ntiles + 15) / 16;
        if (n < 1 || n > 8 || im.w != 128 * n || im.h != rows * 8 * n) {
            fprintf(stderr, "texture pack: %s must be 128*N pixels wide and %d*N high (N = 1-8); it is %dx%d\n", path, rows * 8, im.w, im.h);
            png_free(&im);
            continue;
        }
        sheets_found++;
        int changed = 0;
        for (int t = 0; t < gb_sheets[s].ntiles; t++) {
            const uint8_t *d = gb_sheets[s].data + t * 16;
            GbTex tx = {0};
            tx.hash = hash16(d);
            tx.scale = n;
            int ts = 8 * n;
            tx.rgba = malloc((size_t)ts * ts * 4);
            for (int y = 0; y < ts; y++) for (int x = 0; x < ts; x++) {
                int ox = x / n, oy = y / n;
                const uint8_t *p = im.rgba + ((size_t)((t / 16) * ts + y) * im.w + (t % 16) * ts + x) * 4;
                memcpy(tx.rgba + ((size_t)y * ts + x) * 4, p, 4);
                int shade = ((d[oy * 2 + 1] >> (7 - ox)) & 1) << 1 | ((d[oy * 2] >> (7 - ox)) & 1);
                uint64_t bit = 1ull << (oy * 8 + ox);
                if (!(p[0] == grey[shade] && p[1] == grey[shade] && p[2] == grey[shade] && p[3] == 255)) tx.edited |= bit;
            }
            for (int oy = 0; oy < 8; oy++) for (int ox = 0; ox < 8; ox++) {      /* fully transparent original pixels */
                int all = 1;
                for (int y = 0; y < n && all; y++) for (int x = 0; x < n; x++)
                    if (tx.rgba[((size_t)(oy * n + y) * ts + ox * n + x) * 4 + 3]) { all = 0; break; }
                if (all) tx.clear |= 1ull << (oy * 8 + ox);
            }
            if (!tx.edited) { free(tx.rgba); continue; }                        /* untouched: keeps the Game Boy palette behaviour */
            if (n > gb_tex_scale) gb_tex_scale = n;
            add(&tx);
            changed++;
        }
        fprintf(stderr, "texture pack: %s: %d of %d tiles replaced (scale %d)\n", gb_sheets[s].name, changed, gb_sheets[s].ntiles, n);
        png_free(&im);
    }
    if (!sheets_found) fprintf(stderr, "texture pack: no sheets found in %s\n", folder);
    return gb_tex_count;
}

/* A small PNG reader (8 bit grey, grey+alpha, RGB, RGBA and palette images, not interlaced) with its own inflate: no library needed.
 * Used to load the texture pack (see docs/TEXTURES.md). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "png.h"

typedef struct { const uint8_t *in; size_t n, pos; uint32_t bits; int nbits; uint8_t *out; size_t olen, ocap; int err; } Inf;
typedef struct { uint16_t count[16], symbol[288]; } Huff;

static int getbit(Inf *s) {
    if (!s->nbits) {
        if (s->pos >= s->n) { s->err = 1; return 0; }
        s->bits = s->in[s->pos++];
        s->nbits = 8;
    }
    int b = s->bits & 1;
    s->bits >>= 1; s->nbits--;
    return b;
}
static unsigned getbits(Inf *s, int n) { unsigned v = 0; for (int i = 0; i < n; i++) v |= (unsigned)getbit(s) << i; return v; }
static void build(Huff *h, const uint8_t *len, int n) {
    uint16_t offs[16];
    memset(h->count, 0, sizeof h->count);
    for (int i = 0; i < n; i++) h->count[len[i]]++;
    h->count[0] = 0;
    offs[1] = 0;
    for (int i = 1; i < 15; i++) offs[i + 1] = offs[i] + h->count[i];
    for (int i = 0; i < n; i++) if (len[i]) h->symbol[offs[len[i]]++] = (uint16_t)i;
}
static int decode(Inf *s, const Huff *h) {
    int code = 0, first = 0, index = 0;
    for (int len = 1; len <= 15; len++) {
        code |= getbit(s);
        int count = h->count[len];
        if (code - count < first) return h->symbol[index + (code - first)];
        index += count; first += count; first <<= 1; code <<= 1;
        if (s->err) return -1;
    }
    return -1;
}
static void put(Inf *s, uint8_t b) {
    if (s->olen == s->ocap) { s->ocap = s->ocap ? s->ocap * 2 : 1 << 16; s->out = realloc(s->out, s->ocap); }
    s->out[s->olen++] = b;
}
static const uint16_t lbase[] = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258};
static const uint16_t lext[] = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0};
static const uint16_t dbase[] = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577};
static const uint16_t dext[] = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13};

static int codes(Inf *s, const Huff *lit, const Huff *dist) {
    for (;;) {
        int sym = decode(s, lit);
        if (sym < 0 || s->err) return -1;
        if (sym < 256) put(s, (uint8_t)sym);
        else if (sym == 256) return 0;
        else {
            sym -= 257;
            if (sym >= 29) return -1;
            int len = lbase[sym] + (int)getbits(s, lext[sym]);
            int ds = decode(s, dist);
            if (ds < 0 || ds >= 30) return -1;
            size_t d = dbase[ds] + getbits(s, dext[ds]);
            if (d > s->olen) return -1;
            for (int i = 0; i < len; i++) put(s, s->out[s->olen - d]);
        }
    }
}

static int inflate_data(Inf *s) {
    int last;
    do {
        last = getbit(s);
        int type = (int)getbits(s, 2);
        if (type == 0) {
            s->nbits = 0;
            if (s->pos + 4 > s->n) return -1;
            unsigned len = s->in[s->pos] | s->in[s->pos + 1] << 8;
            s->pos += 4;
            if (s->pos + len > s->n) return -1;
            for (unsigned i = 0; i < len; i++) put(s, s->in[s->pos++]);
        } else if (type == 1) {
            uint8_t l[288];
            Huff lit, dist;
            for (int i = 0; i < 144; i++) l[i] = 8;
            for (int i = 144; i < 256; i++) l[i] = 9;
            for (int i = 256; i < 280; i++) l[i] = 7;
            for (int i = 280; i < 288; i++) l[i] = 8;
            build(&lit, l, 288);
            for (int i = 0; i < 30; i++) l[i] = 5;
            build(&dist, l, 30);
            if (codes(s, &lit, &dist)) return -1;
        } else if (type == 2) {
            static const uint8_t order[19] = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15};
            uint8_t l[320] = {0};
            int nlen = (int)getbits(s, 5) + 257, ndist = (int)getbits(s, 5) + 1, ncode = (int)getbits(s, 4) + 4;
            for (int i = 0; i < ncode; i++) l[order[i]] = (uint8_t)getbits(s, 3);
            Huff lencode, lit, dist;
            for (int i = ncode; i < 19; i++) l[order[i]] = 0;
            build(&lencode, l, 19);
            uint8_t ll[320] = {0};
            int idx = 0;
            while (idx < nlen + ndist) {
                int sym = decode(s, &lencode);
                if (sym < 0) return -1;
                if (sym < 16) ll[idx++] = (uint8_t)sym;
                else {
                    int rep, val = 0;
                    if (sym == 16) { if (!idx) return -1; val = ll[idx - 1]; rep = 3 + (int)getbits(s, 2); }
                    else if (sym == 17) rep = 3 + (int)getbits(s, 3);
                    else rep = 11 + (int)getbits(s, 7);
                    if (idx + rep > nlen + ndist) return -1;
                    while (rep--) ll[idx++] = (uint8_t)val;
                }
            }
            build(&lit, ll, nlen);
            build(&dist, ll + nlen, ndist);
            if (codes(s, &lit, &dist)) return -1;
        } else return -1;
        if (s->err) return -1;
    } while (!last);
    return 0;
}

/* raw deflate data (as inside zip files): returns a malloc'd buffer of *olen bytes, or 0 */
uint8_t *gb_inflate(const uint8_t *in, size_t n, size_t *olen) {
    Inf s = {0};
    s.in = in; s.n = n;
    if (inflate_data(&s)) { free(s.out); return 0; }
    *olen = s.olen;
    if (!s.out) s.out = malloc(1);
    return s.out;
}

static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }

int png_load(const char *path, PngImage *img) {
    memset(img, 0, sizeof *img);
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *file = malloc((size_t)size);
    if (!file || fread(file, 1, (size_t)size, f) != (size_t)size) { fclose(f); free(file); return -1; }
    fclose(f);
    static const uint8_t sig[8] = {0x89, 'P', 'N', 'G', 13, 10, 26, 10};
    if (size < 33 || memcmp(file, sig, 8)) { free(file); return -2; }
    uint32_t w = 0, h = 0;
    int depth = 0, ctype = 0, interlace = 0;
    uint8_t pal[256][4];
    int npal = 0;
    uint8_t *idat = 0;
    size_t idat_len = 0;
    for (size_t pos = 8; pos + 12 <= (size_t)size;) {
        uint32_t len = be32(file + pos);
        const uint8_t *type = file + pos + 4, *d = file + pos + 8;
        if (pos + 12 + len > (size_t)size) break;
        if (!memcmp(type, "IHDR", 4)) { w = be32(d); h = be32(d + 4); depth = d[8]; ctype = d[9]; interlace = d[12]; }
        else if (!memcmp(type, "PLTE", 4)) { npal = (int)len / 3; if (npal > 256) npal = 256; for (int i = 0; i < npal; i++) { pal[i][0] = d[i * 3]; pal[i][1] = d[i * 3 + 1]; pal[i][2] = d[i * 3 + 2]; pal[i][3] = 255; } }
        else if (!memcmp(type, "tRNS", 4) && ctype == 3) { for (uint32_t i = 0; i < len && i < 256; i++) pal[i][3] = d[i]; }
        else if (!memcmp(type, "IDAT", 4)) { idat = realloc(idat, idat_len + len); memcpy(idat + idat_len, d, len); idat_len += len; }
        else if (!memcmp(type, "IEND", 4)) break;
        pos += 12 + len;
    }
    free(file);
    int chans = ctype == 0 ? 1 : ctype == 2 ? 3 : ctype == 3 ? 1 : ctype == 4 ? 2 : ctype == 6 ? 4 : 0;
    if (!w || !h || !chans || interlace || !idat || w > 16384 || h > 16384 || (depth != 8 && !(ctype == 3 && (depth == 1 || depth == 2 || depth == 4 || depth == 8)))) { free(idat); return -3; }
    Inf s = {0};
    s.in = idat + 2; s.n = idat_len > 2 ? idat_len - 2 : 0;
    int bad = inflate_data(&s);
    free(idat);
    int bpp_bits = chans * depth, stride = (int)((w * bpp_bits + 7) / 8), bpp = (bpp_bits + 7) / 8;
    if (bad || s.olen < (size_t)(stride + 1) * h) { free(s.out); return -4; }
    uint8_t *raw = s.out;
    for (uint32_t y = 0; y < h; y++) {                       /* undo the scanline filters */
        uint8_t *row = raw + (size_t)y * (stride + 1) + 1, *prev = y ? row - (stride + 1) : 0;
        int ft = row[-1];
        for (int x = 0; x < stride; x++) {
            int a = x >= bpp ? row[x - bpp] : 0, b = prev ? prev[x] : 0, c = (prev && x >= bpp) ? prev[x - bpp] : 0, v = row[x];
            switch (ft) {
            case 1: v += a; break;
            case 2: v += b; break;
            case 3: v += (a + b) / 2; break;
            case 4: { int p = a + b - c, pa = abs(p - a), pb = abs(p - b), pc = abs(p - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); break; }
            }
            row[x] = (uint8_t)v;
        }
    }
    uint8_t *out = malloc((size_t)w * h * 4);
    for (uint32_t y = 0; y < h; y++) {
        const uint8_t *row = raw + (size_t)y * (stride + 1) + 1;
        for (uint32_t x = 0; x < w; x++) {
            uint8_t *o = out + ((size_t)y * w + x) * 4;
            switch (ctype) {
            case 0: o[0] = o[1] = o[2] = row[x]; o[3] = 255; break;
            case 2: o[0] = row[x * 3]; o[1] = row[x * 3 + 1]; o[2] = row[x * 3 + 2]; o[3] = 255; break;
            case 4: o[0] = o[1] = o[2] = row[x * 2]; o[3] = row[x * 2 + 1]; break;
            case 6: memcpy(o, row + x * 4, 4); break;
            case 3: {
                int idx = depth == 8 ? row[x] : (row[(x * depth) / 8] >> (8 - depth - (int)((x * depth) % 8))) & ((1 << depth) - 1);
                if (idx >= npal) idx = 0;
                memcpy(o, pal[idx], 4);
                break;
            }
            }
        }
    }
    free(raw);
    img->w = (int)w; img->h = (int)h; img->rgba = out;
    return 0;
}

void png_free(PngImage *img) { free(img->rgba); img->rgba = 0; }

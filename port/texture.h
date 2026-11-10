/* Full-colour texture packs: a folder of PNG sheets whose tiles replace the Game Boy tiles (see docs/TEXTURES.md). */
#ifndef GB_TEXTURE_H
#define GB_TEXTURE_H
#include <stdint.h>
typedef struct { const char *name; int ntiles; const uint8_t *data; } GbSheet;     /* generated: tile_index.c */
extern const GbSheet gb_sheets[];
extern const int gb_nsheets;

typedef struct {
    uint64_t hash;          /* of the 16 byte tile */
    int scale;              /* pixels per original pixel (the replacement is 8 * scale pixels square) */
    uint64_t edited;        /* bit y * 8 + x: that original pixel differs from the plain greyscale tile */
    uint64_t clear;         /* bit y * 8 + x: that original pixel is fully transparent */
    uint8_t *rgba;
} GbTex;
extern GbTex *gb_texs;      /* the loaded replacements */
extern int gb_tex_count;    /* 0 = no texture pack: the renderer stays in the Game Boy shades */
extern int gb_tex_scale;    /* the largest scale among them (the colour picture is this many times larger) */

int gb_texture_load(const char *folder);           /* returns the number of replaced tiles; prints what it found to stderr */
int gb_texture_find(const uint8_t *tile16);        /* index into gb_texs or -1 */
#endif

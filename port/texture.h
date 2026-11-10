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
/* Three layers, the last one wins: 0 = the player's own pack (texture_pack option), 1 = the pack of a level pack, 2 = the current level of a level pack.
 * A texture id is layer << 20 | index. */
#define GB_TEX_LAYERS 3
extern int gb_tex_count;    /* replacements in all layers; 0 = no texture pack: the renderer stays in the Game Boy shades */
extern int gb_tex_scale;    /* the largest scale among them (the colour picture is this many times larger) */

int gb_texture_load(int layer, const char *folder);   /* (re)loads a layer from a folder ("" or NULL empties it); returns the number of replaced tiles */
int gb_texture_find(const uint8_t *tile16);           /* texture id or -1 */
const GbTex *gb_texture_get(int id);
#endif

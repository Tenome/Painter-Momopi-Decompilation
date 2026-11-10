/* Custom level packs: an ordered list of levels (map, look, enemies, ...) read from a .pmpack text file instead of the game's 33 built-in rounds.
 * Format and editor: docs/LEVELS.md, tools/level_editor.py. */
#ifndef GB_LEVELPACK_H
#define GB_LEVELPACK_H
#include <stdint.h>
#define GB_MAX_LEVELS 99
typedef struct {
    int theme;              /* look of the room: 0-16 (tile set, floor and wall tiles, room name); -1 = as in the original at this position */
    int music;              /* song id ($81-$8b); -1 = as in the original at this position */
    int time;               /* seconds for the round; -1 = original */
    int magic;              /* magic points at the start; -1 = original */
    int bonus;              /* 1 = the bonus screens follow this level, 0 = not, -1 = original */
    int variant;            /* spawn flag bit (1 or 2); -1 = original */
    uint8_t map[256];       /* 16 x 16 cells, 0-3 (row by row) */
    int paint;              /* cells to paint: the number of cells that are not 0 */
    char name[48];
    char song[160];         /* music text file played as this level's music (relative to the pack file); empty = the music id above */
    char textures[160];     /* folder of texture sheets used only in this level (relative to the pack file); empty = none */
} GbLevel;
extern int gb_pack_count;           /* 0 = no pack: the original 33 rounds */
extern GbLevel gb_pack[GB_MAX_LEVELS];
extern char gb_pack_title[64];
extern uint8_t gb_pack_win[0x4000]; /* spawn data as the game's own wave lists, visible at $4000 while gb_pack_view is set */
extern int gb_pack_view;
void gb_pack_select_textures(int level);   /* loads the textures of a level (layer 2) and, once, those of the pack (layer 1); -1 = none */
void gb_pack_resolve(const char *rel, char *out, int n);    /* a path from the pack file, made absolute against the pack's folder */
int gb_pack_load(const char *path);     /* returns the number of levels, 0 on failure (the error goes to stderr) */
#endif

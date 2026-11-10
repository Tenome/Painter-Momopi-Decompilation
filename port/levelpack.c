#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "levelpack.h"
#include "texture.h"

int gb_pack_count;
GbLevel gb_pack[GB_MAX_LEVELS];
char gb_pack_title[64];
uint8_t gb_pack_win[0x4000];
int gb_pack_view;

typedef struct { int kind, x, y, delay; } Spawn;
static char pack_dir[512], pack_textures[160];

static void resolve(const char *rel, char *out, size_t n) {
    int absolute = rel[0] == '/' || rel[0] == 92 || (rel[0] && rel[1] == ':');
    if (absolute) snprintf(out, n, "%s", rel); else snprintf(out, n, "%s%s", pack_dir, rel);
}

void gb_pack_resolve(const char *rel, char *out, int n) { resolve(rel, out, (size_t)n); }

void gb_pack_select_textures(int level) {
    char dir[700];
    if (!gb_pack_count) return;
    resolve(pack_textures, dir, sizeof dir);
    gb_texture_load(1, pack_textures[0] ? dir : "");
    if (level < 0 || level >= gb_pack_count || !gb_pack[level].textures[0]) { gb_texture_load(2, ""); return; }
    resolve(gb_pack[level].textures, dir, sizeof dir);
    gb_texture_load(2, dir);
}

int gb_pack_load(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "level pack: cannot open %s\n", path); return 0; }
    gb_pack_count = 0;
    gb_pack_title[0] = 0;
    pack_textures[0] = 0;
    {   /* the folder of the file: texture folders are relative to it */
        const char *sl = strrchr(path, '/'), *bs = strrchr(path, 92);
        if (bs > sl) sl = bs;
        snprintf(pack_dir, sizeof pack_dir, "%.*s", sl ? (int)(sl - path + 1) : 0, path);
    }
    memset(gb_pack_win, 0, sizeof gb_pack_win);
    static Spawn waves[GB_MAX_LEVELS][6][64];
    static int nwave[GB_MAX_LEVELS][6];
    memset(nwave, 0, sizeof nwave);
    char line[512];
    int cur = -1, in_map = 0, map_row = 0, wave = 0, lineno = 0;
    while (fgets(line, sizeof line, f)) {
        lineno++;
        char *p = line;
        while (isspace((unsigned char)*p)) p++;
        char *e = p + strlen(p);
        while (e > p && isspace((unsigned char)e[-1])) *--e = 0;
        if (!*p || *p == '#' || *p == ';') continue;
        if (in_map && cur >= 0) {
            int ok = (int)strlen(p) == 16;
            for (int i = 0; ok && i < 16; i++) ok = p[i] >= '0' && p[i] <= '3';
            if (ok) {
                for (int i = 0; i < 16; i++) gb_pack[cur].map[map_row * 16 + i] = (uint8_t)(p[i] - '0');
                if (++map_row == 16) in_map = 0;
                continue;
            }
            fprintf(stderr, "level pack: %s:%d: map rows are 16 digits 0-3\n", path, lineno);
            fclose(f);
            return gb_pack_count = 0;
        }
        char key[32] = "";
        char *rest = p;
        int n = 0;
        sscanf(p, "%31s%n", key, &n);
        rest += n;
        while (isspace((unsigned char)*rest)) rest++;
        if (!strcmp(key, "pack")) { strncpy(gb_pack_title, rest, sizeof gb_pack_title - 1); continue; }
        if (!strcmp(key, "author")) continue;
        if (!strcmp(key, "textures") && cur < 0) { strncpy(pack_textures, rest, sizeof pack_textures - 1); continue; }
        if (!strcmp(key, "level")) {
            if (gb_pack_count >= GB_MAX_LEVELS) { fprintf(stderr, "level pack: more than %d levels\n", GB_MAX_LEVELS); break; }
            cur = gb_pack_count++;
            GbLevel *l = &gb_pack[cur];
            memset(l, 0, sizeof *l);
            l->theme = l->music = l->time = l->magic = l->bonus = l->variant = -1;
            strncpy(l->name, rest, sizeof l->name - 1);
            in_map = 0; wave = 0;
            continue;
        }
        if (cur < 0) continue;
        GbLevel *l = &gb_pack[cur];
        if (!strcmp(key, "theme")) l->theme = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "music")) l->music = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "time")) l->time = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "magic")) l->magic = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "bonus")) l->bonus = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "variant")) l->variant = (int)strtol(rest, 0, 0);
        else if (!strcmp(key, "song")) strncpy(l->song, rest, sizeof l->song - 1);
        else if (!strcmp(key, "textures")) strncpy(l->textures, rest, sizeof l->textures - 1);
        else if (!strcmp(key, "map")) { in_map = 1; map_row = 0; }
        else if (!strcmp(key, "wave")) { wave = (int)strtol(rest, 0, 0); if (wave < 0 || wave > 5) { fprintf(stderr, "level pack: %s:%d: wave 0-5\n", path, lineno); wave = 0; } }
        else if (!strcmp(key, "end")) cur = -1;
        else if (isdigit((unsigned char)key[0])) {                 /* kind x y delay */
            int k, x, y, d;
            if (sscanf(p, "%d %d %d %d", &k, &x, &y, &d) == 4 && nwave[cur][wave] < 64) waves[cur][wave][nwave[cur][wave]++] = (Spawn){k, x, y, d};
            else fprintf(stderr, "level pack: %s:%d: spawn lines are `kind x y delay`\n", path, lineno);
        }
    }
    fclose(f);
    int off = gb_pack_count * 12;                      /* wave pointer tables first, then the lists */
    for (int i = 0; i < gb_pack_count; i++) {
        GbLevel *l = &gb_pack[i];
        l->paint = 0;
        for (int c = 0; c < 256; c++) if (l->map[c]) l->paint++;
        for (int w = 0; w < 6; w++) {
            int cnt = nwave[i][w], need = 1 + cnt * 4 + 4;
            if (off + need > (int)sizeof gb_pack_win) { fprintf(stderr, "level pack: too many enemies in total (the spawn data is limited to 16 KB)\n"); return gb_pack_count = 0; }
            gb_pack_win[i * 12 + w * 2] = (uint8_t)((0x4000 + off) & 255);
            gb_pack_win[i * 12 + w * 2 + 1] = (uint8_t)((0x4000 + off) >> 8);
            gb_pack_win[off] = (uint8_t)cnt;
            for (int s = 0; s < cnt; s++) {
                gb_pack_win[off + 1 + s * 4] = (uint8_t)waves[i][w][s].kind;
                gb_pack_win[off + 2 + s * 4] = (uint8_t)waves[i][w][s].x;
                gb_pack_win[off + 3 + s * 4] = (uint8_t)waves[i][w][s].y;
                gb_pack_win[off + 4 + s * 4] = (uint8_t)waves[i][w][s].delay;
            }
            off += 1 + cnt * 4 + (cnt ? 0 : 4);        /* an empty wave keeps a few spare bytes: the spawn code peeks at the entry after the last one */
        }
    }
    if (gb_pack_count) fprintf(stderr, "level pack: %s: %d levels\n", gb_pack_title[0] ? gb_pack_title : path, gb_pack_count);
    return gb_pack_count;
}

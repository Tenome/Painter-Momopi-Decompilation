#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "config.h"
#include "gb_rt.h"
#include "texture.h"
#include "levelpack.h"

GbConfig gb_config = {4, 0, 0, 0, 0, 100, 0, 1, 100, 0, "", "textures", 0, 0};

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

static void set(const char *key, const char *val) {
    int v = atoi(val);
    if (!strcmp(key, "scale")) gb_config.scale = clampi(v, 1, 16);
    else if (!strcmp(key, "fullscreen")) gb_config.fullscreen = v != 0;
    else if (!strcmp(key, "palette")) gb_config.palette = clampi(v, 0, 2);
    else if (!strcmp(key, "widescreen")) gb_config.widescreen = clampi(v, 0, 40);
    else if (!strcmp(key, "no_sprite_limit")) gb_config.no_sprite_limit = v != 0;
    else if (!strcmp(key, "volume")) gb_config.volume = clampi(v, 0, 100);
    else if (!strcmp(key, "mute")) gb_config.mute = v != 0;
    else if (!strcmp(key, "integer_scale")) gb_config.integer_scale = v != 0;
    else if (!strcmp(key, "speed")) gb_config.speed = clampi(v, 50, 400);
    else if (!strcmp(key, "infinite_lives")) gb_config.infinite_lives = v != 0;
    else if (!strcmp(key, "level_pack")) { strncpy(gb_config.level_pack, val, sizeof gb_config.level_pack - 1); gb_config.level_pack[sizeof gb_config.level_pack - 1] = 0; }
    else if (!strcmp(key, "texture_pack")) { strncpy(gb_config.texture_pack, val, sizeof gb_config.texture_pack - 1); gb_config.texture_pack[sizeof gb_config.texture_pack - 1] = 0; }
    else if (!strcmp(key, "start_lives")) gb_config.start_lives = clampi(v, 0, 99);
    else if (!strcmp(key, "start_round")) gb_config.start_round = clampi(v, 0, 33);
}

void gb_config_load(const char *path) {
    FILE *f = fopen(path, "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof line, f)) {
            char *p = line;
            while (isspace((unsigned char)*p)) p++;
            if (*p == ';' || *p == '#' || *p == '[' || !*p) continue;
            char *eq = strchr(p, '=');
            if (!eq) continue;
            *eq = 0;
            char *end = eq - 1;
            while (end >= p && isspace((unsigned char)*end)) *end-- = 0;
            char *val = eq + 1;
            while (isspace((unsigned char)*val)) val++;
            for (end = val + strlen(val) - 1; end >= val && isspace((unsigned char)*end); end--) *end = 0;
            for (char *q = p; *q; q++) *q = (char)tolower((unsigned char)*q);
            set(p, val);
        }
        fclose(f);
    }
    if (gb_config.texture_pack[0]) {                  /* the texture pack folder: absolute, or next to the ini file */
        char dir[600];
        const char *slash = path ? strrchr(path, 47) : 0;
        const char *bslash = path ? strrchr(path, 92) : 0;
        if (bslash > slash) slash = bslash;
        int absolute = gb_config.texture_pack[0] == 47 || gb_config.texture_pack[0] == 92 || (gb_config.texture_pack[1] == 58);
        if (slash && !absolute) snprintf(dir, sizeof dir, "%.*s%s", (int)(slash - path + 1), path, gb_config.texture_pack);
        else snprintf(dir, sizeof dir, "%s", gb_config.texture_pack);
        gb_texture_load(0, dir);
    }
    if (gb_config.level_pack[0]) {                    /* a level pack file: absolute, or next to the ini file */
        char file[600];
        const char *slash = path ? strrchr(path, 47) : 0;
        const char *bslash = path ? strrchr(path, 92) : 0;
        if (bslash > slash) slash = bslash;
        int absolute = gb_config.level_pack[0] == 47 || gb_config.level_pack[0] == 92 || (gb_config.level_pack[1] == 58);
        if (slash && !absolute) snprintf(file, sizeof file, "%.*s%s", (int)(slash - path + 1), path, gb_config.level_pack);
        else snprintf(file, sizeof file, "%s", gb_config.level_pack);
        gb_pack_load(file);
    }
    gb_margin = gb_config.widescreen;
    gb_view_w = 160 + 2 * gb_margin;
}

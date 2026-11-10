#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "config.h"
#include "gb_rt.h"
#include "texture.h"
#include "levelpack.h"
#include "save.h"

GbConfig gb_config = {4, 0, 0, 0, 0, 100, 0, 1, 100, 0, "", "textures", 0, 0, 0, 0, 0, 0};

static const char *const key_option[10] = {"key_right", "key_left", "key_up", "key_down", "key_a", "key_b", "key_select", "key_start", "key_card_prev", "key_card_next"};
static const char *const key_default[10] = {"Right", "Left", "Up", "Down", "Z", "X", "RShift,Backspace", "Enter", "Q", "E"};

static const char *const pad_option[6] = {"pad_a", "pad_b", "pad_select", "pad_start", "pad_card_prev", "pad_card_next"};
static const unsigned pad_default[6] = {0x01, 0x02, 0x40 | 0x100, 0x80 | 0x200, 0x10, 0x20};

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

static void set(const char *key, const char *val) {
    int v = atoi(val);
    for (int k = 0; k < 6; k++) if (!strcmp(key, pad_option[k])) {      /* button numbers 1-32 separated by commas */
        unsigned m = 0;
        for (const char *q = val; *q;) { if (*q >= '0' && *q <= '9') { int b = atoi(q); if (b >= 1 && b <= 32) m |= 1u << (b - 1); while (*q >= '0' && *q <= '9') q++; } else if (*q == ';') break; else q++; }
        gb_config.pad[k] = m;
        return;
    }
    for (int k = 0; k < 10; k++) if (!strcmp(key, key_option[k])) { strncpy(gb_config.keys[k], val, 47); gb_config.keys[k][47] = 0; return; }
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
    else if (!strcmp(key, "all_cards")) gb_config.all_cards = v != 0;
    else if (!strcmp(key, "infinite_magic")) gb_config.infinite_magic = v != 0;
    else if (!strcmp(key, "no_time_limit")) gb_config.no_time_limit = v != 0;
    else if (!strcmp(key, "filter")) gb_config.filter = clampi(v, 0, 2);
    else if (!strcmp(key, "pause_on_focus_loss")) gb_config.pause_on_focus_loss = v != 0;
    else if (!strcmp(key, "high_score")) gb_config.high_score = v != 0;
    else if (!strcmp(key, "resume")) gb_config.resume = v != 0;
    else if (!strcmp(key, "quick_magic")) gb_config.quick_magic = v != 0;
    else if (!strcmp(key, "start_round")) gb_config.start_round = clampi(v, 0, 33);
}

void gb_config_load(const char *path) {
    gb_save_init(path);
    for (int k = 0; k < 10; k++) strcpy(gb_config.keys[k], key_default[k]);
    for (int k = 0; k < 6; k++) gb_config.pad[k] = pad_default[k];
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "save.h"

GbSave gb_save;
static char path[600];

void gb_save_init(const char *ini_path) {
    snprintf(path, sizeof path, "%s", ini_path);
    char *dot = strrchr(path, '.'), *slash = strrchr(path, '/'), *bs = strrchr(path, 92);
    if (!dot || dot < slash || dot < bs) dot = path + strlen(path);
    snprintf(dot, sizeof path - (size_t)(dot - path), ".sav");
    memset(&gb_save, 0, sizeof gb_save);
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[160];
    while (fgets(line, sizeof line, f)) {
        if (!strncmp(line, "best_score=", 11)) gb_save.best_score = (unsigned)strtoul(line + 11, 0, 10);
        else if (!strncmp(line, "best_round=", 11)) gb_save.best_round = (unsigned)strtoul(line + 11, 0, 10);
        else if (!strncmp(line, "resume=", 7)) {
            int ok = 1;
            for (int i = 0; i < GB_RESUME_BYTES; i++) {
                unsigned v;
                if (sscanf(line + 7 + i * 2, "%2x", &v) != 1) { ok = 0; break; }
                gb_save.resume[i] = (uint8_t)v;
            }
            gb_save.has_resume = ok;
        }
    }
    fclose(f);
}

void gb_save_write(void) {
    if (!path[0]) return;
    FILE *f = fopen(path, "w");
    if (!f) return;
    fprintf(f, "best_score=%u%cbest_round=%u%c", gb_save.best_score, 10, gb_save.best_round, 10);
    if (gb_save.has_resume) {
        fprintf(f, "resume=");
        for (int i = 0; i < GB_RESUME_BYTES; i++) fprintf(f, "%02x", gb_save.resume[i]);
        fputc(10, f);
    }
    fclose(f);
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gb_rt.h"
#include "config.h"
#include "levelpack.h"
#include "replay.h"

int gb_replay_active, gb_replay_finished;
static FILE *rec;
static unsigned last_joy = 0xFFFF;
static int last_q = 99;

typedef struct { unsigned frame; uint8_t joy; int8_t q; } Ev;
static Ev *evs;
static int nev, next_ev;
static uint8_t cur_joy;

/* the options that change what happens in the game (display and sound options do not) */
#define OPTS(X) X(infinite_lives) X(start_lives) X(all_cards) X(infinite_magic) X(no_time_limit) X(quick_magic) X(start_round)

int gb_replay_record(const char *path) {
    rec = fopen(path, "w");
    if (!rec) { fprintf(stderr, "replay: cannot write %s\n", path); return 0; }
    fprintf(rec, "pmrec 1%c", 10);
    fprintf(rec, "pack %s%c", gb_pack_count ? gb_pack_path : "-", 10);
#define W(n) fprintf(rec, "opt " #n " %d%c", gb_config.n, 10);
    OPTS(W)
#undef W
    last_joy = 0xFFFF; last_q = 99;
    return 1;
}

int gb_replay_play(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "replay: cannot open %s\n", path); return 0; }
    char line[1200];
    int cap = 0;
    gb_config.resume = 0; gb_config.high_score = 0;
    while (fgets(line, sizeof line, f)) {
        size_t n = strlen(line);
        while (n && (line[n - 1] == 10 || line[n - 1] == 13)) line[--n] = 0;
        if (!strncmp(line, "pack ", 5)) { if (strcmp(line + 5, "-") && !gb_pack_load(line + 5)) fprintf(stderr, "replay: the level pack %s could not be loaded\n", line + 5); }
        else if (!strncmp(line, "opt ", 4)) {
            char name[64];
            int v;
            if (sscanf(line + 4, "%63s %d", name, &v) == 2) {
#define S(n) if (!strcmp(name, #n)) gb_config.n = v;
                OPTS(S)
#undef S
            }
        } else if (line[0] >= '0' && line[0] <= '9') {
            unsigned fr, j;
            int q;
            if (sscanf(line, "%u %x %d", &fr, &j, &q) == 3) {
                if (nev == cap) { cap = cap ? cap * 2 : 1024; evs = realloc(evs, (size_t)cap * sizeof *evs); }
                evs[nev].frame = fr; evs[nev].joy = (uint8_t)j; evs[nev].q = (int8_t)q; nev++;
            }
        }
    }
    fclose(f);
    gb_replay_active = 1;
    return 1;
}

void gb_replay_tick(unsigned frame) {
    if (rec) {
        unsigned j = gb_joy;
        int q = gb_quick_cycle;
        if (j != last_joy || q != 0) {                              /* only changes, and every quick magic press */
            fprintf(rec, "%u %02x %d%c", frame, j, q, 10);
            fflush(rec);
            last_joy = j; last_q = q;
        }
    }
    if (gb_replay_active) {
        int q = 0;
        while (next_ev < nev && evs[next_ev].frame <= frame) { cur_joy = evs[next_ev].joy; q = evs[next_ev].q; next_ev++; }
        gb_joy = cur_joy;
        if (q) gb_quick_cycle = q;
        else gb_quick_cycle = 0;
        if (next_ev >= nev && !gb_replay_finished) gb_replay_finished = 1;
    }
}

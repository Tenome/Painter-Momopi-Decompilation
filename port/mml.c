/* A music macro language (MML) compiler for custom songs: text in, the game's own sound stream format out (see docs/MUSIC.md).
 * The output is a song region as the sound engine reads it (channel count, 10 byte channel headers, streams) for the base address $a000. */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mml.h"

#define BASE 0xA000
#define MAXTEXT 16384

typedef struct { uint8_t data[4096]; int n; } Buf;
static char errmsg[160];

static void put(Buf *b, int v) { if (b->n < (int)sizeof b->data) b->data[b->n++] = (uint8_t)v; }

static int note_semitone(char c) {
    switch (c) { case 'c': return 0; case 'd': return 2; case 'e': return 4; case 'f': return 5; case 'g': return 7; case 'a': return 9; case 'b': return 11; }
    return -1;
}

typedef struct {
    const char *name;
    int hw, duty, volume, decay, pattern, level;
    char text[MAXTEXT];
} Chan;

/* the notes of one channel: appends the stream (without the header) to b, positions are relative to the start of the stream */
static int compile_stream(Chan *ch, int ticks_per_quarter, Buf *b, int stream_base) {
    const char *p = ch->text;
    int octave = 4, deflen = 8, loop_at = -1;
    int note_pending = 0, pending_tok = 0, pending_ticks = 0, tie_next = 0;
    /* repeats are expanded: collect the tokens of a bracket by recursion on the text */
    typedef struct { const char *start; int times, done; } Rep;
    Rep reps[8];
    int nrep = 0;
    if (ch->hw == 0 || ch->hw == 1) { put(b, 0xE8); put(b, ch->duty << 6); }
    if (ch->hw == 2) { put(b, 0xEA); put(b, ch->pattern); }

#define FLUSH() do { if (note_pending) { put(b, pending_tok); if (pending_ticks > 127) pending_ticks = 127; put(b, pending_ticks < 1 ? 1 : pending_ticks); note_pending = 0; } } while (0)
    while (*p) {
        char c = (char)tolower((unsigned char)*p);
        if (isspace((unsigned char)c) || c == '|') { p++; continue; }
        if (c == ';') { while (*p && *p != '\n') p++; continue; }
        if (*p == 'L') { FLUSH(); loop_at = b->n; p++; continue; }              /* upper case L: where the song repeats from */
        if (c == 'o') { p++; octave = (int)strtol(p, (char **)&p, 10); continue; }
        if (c == '<') { octave--; p++; continue; }
        if (c == '>') { octave++; p++; continue; }
        if (c == 'l') { p++; deflen = (int)strtol(p, (char **)&p, 10); if (deflen < 1 || deflen > 64) { snprintf(errmsg, sizeof errmsg, "bad note length l%d", deflen); return -1; } continue; }
        if (c == 'v') { p++; int v = (int)strtol(p, (char **)&p, 10); FLUSH(); put(b, 0xE6); put(b, (v & 15) << 4 | ch->decay); continue; }
        if (c == '@') { p++; int d = (int)strtol(p, (char **)&p, 10); FLUSH(); put(b, 0xE8); put(b, (d & 3) << 6); continue; }
        if (c == '[') {
            if (nrep >= 8) { snprintf(errmsg, sizeof errmsg, "repeats nested more than 8 deep"); return -1; }
            reps[nrep].start = p + 1; reps[nrep].times = 0; reps[nrep].done = 1; nrep++;
            p++;
            continue;
        }
        if (c == ']') {
            if (!nrep) { snprintf(errmsg, sizeof errmsg, "] without ["); return -1; }
            p++;
            int times = (int)strtol(p, (char **)&p, 10);
            if (times < 1) times = 2;
            Rep *r = &reps[nrep - 1];
            if (r->done < times) { r->done++; p = r->start; } else nrep--;
            continue;
        }
        if (c == '&') { tie_next = 1; p++; continue; }
        int tok = -1, semi = note_semitone(c);
        if (c == 'r') tok = 0x80;
        else if (c == 'x') { p++; tok = (int)strtol(p, (char **)&p, 16); p--; }
        else if (semi >= 0) {
            int s = semi;
            while (p[1] == '+' || p[1] == '#' || p[1] == '-') { s += p[1] == '-' ? -1 : 1; p++; }
            int midi = 12 * (octave + 1) + s;
            tok = 0x82 + (midi - 37);
            if (tok < 0x82 || tok > 0xD4) { snprintf(errmsg, sizeof errmsg, "note out of range (o%d)", octave); return -1; }
        } else { snprintf(errmsg, sizeof errmsg, "unexpected '%c' in the music text", *p); return -1; }
        p++;
        int len = deflen;
        if (isdigit((unsigned char)*p)) len = (int)strtol(p, (char **)&p, 10);
        if (len < 1 || len > 64) { snprintf(errmsg, sizeof errmsg, "bad note length %d", len); return -1; }
        int ticks = ticks_per_quarter * 4 / len;
        if (*p == '.') { ticks += ticks / 2; p++; }
        if (ticks < 1) ticks = 1;
        if (tie_next && note_pending && tok == pending_tok) { pending_ticks += ticks; tie_next = 0; continue; }     /* tied: one longer note */
        tie_next = 0;
        FLUSH();
        pending_tok = tok; pending_ticks = ticks; note_pending = 1;
    }
    FLUSH();
    if (nrep) { snprintf(errmsg, sizeof errmsg, "[ without ]"); return -1; }
    if (loop_at >= 0) { put(b, 0xE5); put(b, (stream_base + loop_at) & 255); put(b, (stream_base + loop_at) >> 8); }
    else put(b, 0xEB);
    return 0;
}

int gb_mml_compile(const char *path, uint8_t *out, int cap, char *err, int errn) {
    FILE *f = fopen(path, "r");
    if (!f) { snprintf(err, errn, "cannot open %s", path); return -1; }
    static Chan chans[4];
    int nch = 0, bpm = 120, tpq = 12;
    char line[512];
    Chan *cur = 0;
    memset(chans, 0, sizeof chans);
    while (fgets(line, sizeof line, f)) {
        char *s = line;
        while (isspace((unsigned char)*s)) s++;
        if (!*s || *s == ';' || *s == '#') continue;
        char word[32] = "";
        int n = 0;
        sscanf(s, "%31s%n", word, &n);
        for (char *q = word; *q; q++) *q = (char)tolower((unsigned char)*q);
        if (!strcmp(word, "title") || !strcmp(word, "author")) continue;
        if (!strcmp(word, "tempo")) { bpm = atoi(s + n); continue; }
        if (!strcmp(word, "ticks")) { tpq = atoi(s + n); continue; }
        int hw = !strcmp(word, "pulse1") ? 0 : !strcmp(word, "pulse2") ? 1 : !strcmp(word, "wave") ? 2 : !strcmp(word, "noise") ? 3 : -1;
        if (hw >= 0) {
            if (nch >= 4) { snprintf(err, errn, "more than 4 channels"); fclose(f); return -1; }
            cur = &chans[nch++];
            cur->hw = hw; cur->duty = 2; cur->volume = 12; cur->decay = 0; cur->pattern = 0; cur->level = 1;
            for (char *o = s + n; *o;) {                      /* key=value options on the channel line */
                while (isspace((unsigned char)*o)) o++;
                char key[24] = "";
                int v = 0, m = 0;
                if (sscanf(o, "%23[a-z]=%d%n", key, &v, &m) == 2) {
                    if (!strcmp(key, "duty")) cur->duty = v & 3;
                    else if (!strcmp(key, "volume")) cur->volume = v & 15;
                    else if (!strcmp(key, "decay")) cur->decay = v & 7;
                    else if (!strcmp(key, "pattern")) cur->pattern = v & 15;
                    else if (!strcmp(key, "level")) cur->level = v < 1 ? 1 : v > 3 ? 3 : v;
                    o += m;
                } else break;
            }
            s += n;
            while (*s && *s != '\n') s++;                       /* the rest of this line after the options is music too */
            continue;
        }
        if (!cur) { snprintf(err, errn, "music text before the first channel (pulse1, pulse2, wave or noise)"); fclose(f); return -1; }
        size_t used = strlen(cur->text);
        if (used + strlen(s) + 2 < sizeof cur->text) { strcat(cur->text, s); }
    }
    fclose(f);
    if (!nch) { snprintf(err, errn, "no channels"); return -1; }
    if (tpq < 1 || tpq > 48) tpq = 12;
    int tempo = (int)(bpm * tpq / 60.0 / 59.7275 * 256 + 0.5);
    if (tempo < 1) tempo = 1;
    if (tempo > 255) tempo = 255;
    Buf streams[4];
    int base = 1 + 10 * nch, size = base;
    int starts[4];
    for (int i = 0; i < nch; i++) {
        starts[i] = size;
        streams[i].n = 0;
        errmsg[0] = 0;
        if (compile_stream(&chans[i], tpq, &streams[i], BASE + size)) { snprintf(err, errn, "channel %d: %s", i + 1, errmsg); return -1; }
        size += streams[i].n;
    }
    if (size > cap) { snprintf(err, errn, "the song is too long (%d bytes, at most %d)", size, cap); return -1; }
    out[0] = (uint8_t)nch;
    for (int i = 0; i < nch; i++) {
        uint8_t *h = out + 1 + 10 * i;
        Chan *c = &chans[i];
        h[0] = 0x80; h[1] = (uint8_t)c->hw; h[2] = 0xFF;
        h[3] = (uint8_t)((BASE + starts[i]) & 255); h[4] = (uint8_t)((BASE + starts[i]) >> 8);
        h[5] = 0; h[6] = 0;
        h[7] = c->hw == 2 ? (uint8_t)(c->level << 5) : (uint8_t)(c->volume << 4 | c->decay);
        h[8] = (uint8_t)tempo; h[9] = 0;
        memcpy(out + starts[i], streams[i].data, (size_t)streams[i].n);
    }
    return size;
}

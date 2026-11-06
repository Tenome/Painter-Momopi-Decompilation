/* Small Game Boy APU: two pulse channels (sweep on 1), wave, noise; frame sequencer at 512 Hz. Not cycle exact. */
#include "apu.h"
#include <string.h>
#include <stdio.h>
extern int gb_trace;

typedef struct {
    int on, dac;
    int len, len_en;
    int vol, env_init, env_dir, env_period, env_timer;
    int duty, freq;
    double phase;
    int sw_period, sw_dir, sw_shift, sw_timer, sw_en, sw_shadow;
    int wave_code;
    int lfsr, nwidth, ndiv, nshift;
    double ntimer;
} Ch;

static Ch ch[4];
static uint8_t regs[0x30];
static uint8_t wave[16];
static int master = 1;
static double seq_acc;
static int seq_step;

static const uint8_t DUTY[4][8] = {{0, 0, 0, 0, 0, 0, 0, 1}, {1, 0, 0, 0, 0, 0, 0, 1}, {1, 0, 0, 0, 0, 1, 1, 1}, {0, 1, 1, 1, 1, 1, 1, 0}};

void apu_reset(void) {
    memset(ch, 0, sizeof ch);
    memset(regs, 0, sizeof regs);
    memset(wave, 0, sizeof wave);
    ch[3].lfsr = 0x7FFF;
    master = 1;
    seq_acc = 0;
    seq_step = 0;
}

static void trigger(int n) {
    Ch *c = &ch[n];
    c->on = c->dac;
    int maxlen = n == 2 ? 256 : 64;
    if (c->len == 0) c->len = maxlen;
    c->env_timer = c->env_period ? c->env_period : 8;
    c->vol = c->env_init;
    c->phase = 0;
    if (n == 0) {
        c->sw_shadow = c->freq;
        c->sw_timer = c->sw_period ? c->sw_period : 8;
        c->sw_en = c->sw_period || c->sw_shift;
    }
    if (n == 3) c->lfsr = 0x7FFF;
}

void apu_write(uint16_t a, uint8_t v) {
    if (gb_trace == 3) fprintf(stderr, "apu %04x <- %02x\n", a, v);
    if (a >= 0xFF30 && a < 0xFF40) { wave[a - 0xFF30] = v; return; }
    if (a < 0xFF10 || a > 0xFF26) return;
    regs[a - 0xFF10] = v;
    if (a == 0xFF26) {
        master = (v & 0x80) != 0;
        if (!master) for (int k = 0; k < 4; k++) ch[k].on = 0;
        return;
    }
    switch (a) {
    case 0xFF10: ch[0].sw_period = (v >> 4) & 7; ch[0].sw_dir = (v >> 3) & 1; ch[0].sw_shift = v & 7; break;
    case 0xFF11: ch[0].duty = v >> 6; ch[0].len = 64 - (v & 63); break;
    case 0xFF12: ch[0].env_init = v >> 4; ch[0].env_dir = (v >> 3) & 1; ch[0].env_period = v & 7; ch[0].dac = (v & 0xF8) != 0; if (!ch[0].dac) ch[0].on = 0; break;
    case 0xFF13: ch[0].freq = (ch[0].freq & 0x700) | v; break;
    case 0xFF14: ch[0].freq = (ch[0].freq & 0xFF) | ((v & 7) << 8); ch[0].len_en = (v >> 6) & 1; if (v & 0x80) trigger(0); break;
    case 0xFF16: ch[1].duty = v >> 6; ch[1].len = 64 - (v & 63); break;
    case 0xFF17: ch[1].env_init = v >> 4; ch[1].env_dir = (v >> 3) & 1; ch[1].env_period = v & 7; ch[1].dac = (v & 0xF8) != 0; if (!ch[1].dac) ch[1].on = 0; break;
    case 0xFF18: ch[1].freq = (ch[1].freq & 0x700) | v; break;
    case 0xFF19: ch[1].freq = (ch[1].freq & 0xFF) | ((v & 7) << 8); ch[1].len_en = (v >> 6) & 1; if (v & 0x80) trigger(1); break;
    case 0xFF1A: ch[2].dac = (v & 0x80) != 0; if (!ch[2].dac) ch[2].on = 0; break;
    case 0xFF1B: ch[2].len = 256 - v; break;
    case 0xFF1C: ch[2].wave_code = (v >> 5) & 3; break;
    case 0xFF1D: ch[2].freq = (ch[2].freq & 0x700) | v; break;
    case 0xFF1E: ch[2].freq = (ch[2].freq & 0xFF) | ((v & 7) << 8); ch[2].len_en = (v >> 6) & 1; if (v & 0x80) trigger(2); break;
    case 0xFF20: ch[3].len = 64 - (v & 63); break;
    case 0xFF21: ch[3].env_init = v >> 4; ch[3].env_dir = (v >> 3) & 1; ch[3].env_period = v & 7; ch[3].dac = (v & 0xF8) != 0; if (!ch[3].dac) ch[3].on = 0; break;
    case 0xFF22: ch[3].nshift = v >> 4; ch[3].nwidth = (v >> 3) & 1; ch[3].ndiv = v & 7; break;
    case 0xFF23: ch[3].len_en = (v >> 6) & 1; if (v & 0x80) trigger(3); break;
    }
}

uint8_t apu_read(uint16_t a, uint8_t stored) {
    if (a >= 0xFF30 && a < 0xFF40) return wave[a - 0xFF30];
    if (a == 0xFF26) return (master ? 0x80 : 0) | 0x70 | ch[0].on | (ch[1].on << 1) | (ch[2].on << 2) | (ch[3].on << 3);
    return stored;
}

static void seq_tick(void) {
    int s = seq_step;
    seq_step = (seq_step + 1) & 7;
    if ((s & 1) == 0)
        for (int k = 0; k < 4; k++) if (ch[k].len_en && ch[k].len && --ch[k].len == 0) ch[k].on = 0;
    if (s == 2 || s == 6) {
        Ch *c = &ch[0];
        if (c->on && c->sw_en && c->sw_period && --c->sw_timer <= 0) {
            c->sw_timer = c->sw_period;
            int d = c->sw_shadow >> c->sw_shift;
            int nf = c->sw_dir ? c->sw_shadow - d : c->sw_shadow + d;
            if (nf > 2047) c->on = 0;
            else if (c->sw_shift) { c->sw_shadow = nf; c->freq = nf; }
        }
    }
    if (s == 7)
        for (int k = 0; k < 4; k++) {
            Ch *c = &ch[k];
            if (k == 2 || !c->env_period || !c->on) continue;
            if (--c->env_timer <= 0) {
                c->env_timer = c->env_period;
                if (c->env_dir && c->vol < 15) c->vol++;
                else if (!c->env_dir && c->vol > 0) c->vol--;
            }
        }
}

static double sample_ch(int k) {
    Ch *c = &ch[k];
    if (!c->on || !c->dac) return 0;
    if (k < 2) {
        double hz = 1048576.0 / (2048 - c->freq);             /* duty steps per second: 8 per period of 131072/(2048-x) Hz */
        c->phase += hz / APU_RATE;
        int step = (int)c->phase & 7;
        return DUTY[c->duty][step] ? c->vol / 15.0 : -c->vol / 15.0;
    }
    if (k == 2) {
        double hz = 2097152.0 / (2048 - c->freq);             /* wave samples per second: 32 per period of 65536/(2048-x) Hz */
        c->phase += hz / APU_RATE;
        int idx = (int)c->phase & 31;
        int nib = (wave[idx >> 1] >> ((idx & 1) ? 0 : 4)) & 15;
        static const int sh[4] = {4, 0, 1, 2};
        nib >>= sh[c->wave_code];
        return (nib / 7.5 - 1.0) * (c->wave_code ? 1 : 0);
    }
    static const int divs[8] = {8, 16, 32, 48, 64, 80, 96, 112};
    double hz = 4194304.0 / (divs[c->ndiv] * (double)(1 << (c->nshift + 1)));
    c->ntimer += hz / APU_RATE;
    while (c->ntimer >= 1.0) {
        c->ntimer -= 1.0;
        int x = (c->lfsr ^ (c->lfsr >> 1)) & 1;
        c->lfsr = (c->lfsr >> 1) | (x << 14);
        if (c->nwidth) c->lfsr = (c->lfsr & ~0x40) | (x << 6);
    }
    return (c->lfsr & 1) ? -c->vol / 15.0 : c->vol / 15.0;
}

void apu_mix(int16_t *out, int frames) {
    uint8_t nr50 = regs[0x14], nr51 = regs[0x15];
    for (int i = 0; i < frames; i++) {
        seq_acc += 512.0 / APU_RATE;
        while (seq_acc >= 1.0) { seq_acc -= 1.0; seq_tick(); }
        double l = 0, rr = 0;
        for (int k = 0; k < 4; k++) {
            double s = master ? sample_ch(k) : 0;
            if (nr51 & (1 << k)) rr += s;
            if (nr51 & (1 << (k + 4))) l += s;
        }
        double lv = ((nr50 >> 4) & 7) + 1, rv = (nr50 & 7) + 1;
        out[i * 2] = (int16_t)(int)(l * lv / 8.0 * 2000);
        out[i * 2 + 1] = (int16_t)(int)(rr * rv / 8.0 * 2000);
    }
}

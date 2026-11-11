/* SDL2 front end for the recompiled game (Linux, macOS, or Windows with SDL2). Same features as main_win32.c:
 * painter_momopie.ini (options, [keys], pad_*), texture packs (full colour), widescreen, level packs (--pack / --round),
 * P = pause, M = mute, F2 = next palette, F5 = reload the texture folders, F11 = fullscreen, F12 = screenshot (momopie_N.bmp in the current folder),
 * hold Tab = fast forward, a gamepad (SDL game controller) with D-pad / left stick.
 * Not yet run on this project's machine (no SDL2 here): it only uses plain SDL2 calls.
 *   game_sdl [ROM] [--ini FILE] [--pack FILE] [--round N]   (the built-in data is used without a ROM argument) */
#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "gb_rt.h"
#include "config.h"
#include "texture.h"
#include "levelpack.h"
#include "replay.h"

extern void gb_game_main(void);
extern const unsigned char gb_rom_image[];
extern const size_t gb_rom_image_size;

static SDL_Window *win;
static SDL_Renderer *ren;
static SDL_Texture *tex;
static int tex_w, tex_h;
static SDL_AudioDeviceID dev;
static SDL_GameController *pad;
static uint32_t pixels[GB_MAX_W * 144];
static int pal_index, paused, muted, fast, want_shot, want_reload;
static SDL_Keycode binds[10][4];

static SDL_Keycode key_of(const char *n) {
    static const struct { const char *name, *sdl; } names[] = {
        {"enter", "Return"}, {"rshift", "Right Shift"}, {"lshift", "Left Shift"}, {"shift", "Left Shift"}, {"ctrl", "Left Ctrl"}, {"lctrl", "Left Ctrl"},
        {"rctrl", "Right Ctrl"}, {"alt", "Left Alt"}, {"ins", "Insert"}, {"del", "Delete"}, {"pgup", "PageUp"}, {"pgdn", "PageDown"}, {"comma", ","},
        {"period", "."}, {"num0", "Keypad 0"}, {"num1", "Keypad 1"}, {"num2", "Keypad 2"}, {"num3", "Keypad 3"}, {"num4", "Keypad 4"}, {"num5", "Keypad 5"},
        {"num6", "Keypad 6"}, {"num7", "Keypad 7"}, {"num8", "Keypad 8"}, {"num9", "Keypad 9"}};
    char low[32];
    size_t len = strlen(n);
    if (len == 0 || len >= sizeof low) return SDLK_UNKNOWN;
    for (size_t i = 0; i <= len; i++) low[i] = (char)tolower((unsigned char)n[i]);
    if (!strcmp(low, "none")) return SDLK_UNKNOWN;
    for (size_t i = 0; i < sizeof names / sizeof *names; i++) if (!strcmp(low, names[i].name)) return SDL_GetKeyFromName(names[i].sdl);
    return SDL_GetKeyFromName(n);                  /* letters, digits, Up, Down, Left, Right, Space, Tab, Backspace ... */
}
static void bind_keys(void) {
    for (int a = 0; a < 10; a++) {
        char list[48];
        strcpy(list, gb_config.keys[a]);
        int n = 0;
        for (char *tok = strtok(list, ", "); tok && n < 4; tok = strtok(0, ", ")) { SDL_Keycode k = key_of(tok); if (k != SDLK_UNKNOWN) binds[a][n++] = k; }
    }
}
static int bound_down(const Uint8 *ks, int action) {
    for (int i = 0; i < 4 && binds[action][i]; i++) if (ks[SDL_GetScancodeFromKey(binds[action][i])]) return 1;
    return 0;
}
static int bound_is(int action, SDL_Keycode k) {
    for (int i = 0; i < 4 && binds[action][i]; i++) if (binds[action][i] == k) return 1;
    return 0;
}

/* the controller buttons use the numbers of the Windows player: 1 A, 2 B, 3 X, 4 Y, 5 left shoulder, 6 right shoulder, 7 Back, 8 Start */
static unsigned pad_buttons(void) {
    static const int map[8] = {SDL_CONTROLLER_BUTTON_A, SDL_CONTROLLER_BUTTON_B, SDL_CONTROLLER_BUTTON_X, SDL_CONTROLLER_BUTTON_Y,
                               SDL_CONTROLLER_BUTTON_LEFTSHOULDER, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER, SDL_CONTROLLER_BUTTON_BACK, SDL_CONTROLLER_BUTTON_START};
    unsigned m = 0;
    for (int i = 0; i < 8; i++) if (SDL_GameControllerGetButton(pad, (SDL_GameControllerButton)map[i])) m |= 1u << i;
    return m;
}

static void present(void) {
    int cs = gb_tex_count ? gb_color_scale : 1, vw = gb_view_w;
    const uint32_t *src = gb_tex_count ? gb_colorbuf : pixels;
    if (!tex || tex_w != vw * cs || tex_h != 144 * cs) {
        if (tex) SDL_DestroyTexture(tex);
        tex_w = vw * cs; tex_h = 144 * cs;
        tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, tex_w, tex_h);
        SDL_RenderSetLogicalSize(ren, vw, 144);
        SDL_SetHintWithPriority(SDL_HINT_RENDER_SCALE_QUALITY, cs > 1 ? "1" : "0", SDL_HINT_OVERRIDE);
    }
    SDL_UpdateTexture(tex, 0, src, tex_w * 4);
    SDL_RenderClear(ren);
    SDL_RenderCopy(ren, tex, 0, 0);
    SDL_RenderPresent(ren);
}

static void save_screenshot(void) {
    int cs = gb_tex_count ? gb_color_scale : 1, w = gb_view_w * cs, h = 144 * cs;
    const uint32_t *src = gb_tex_count ? gb_colorbuf : pixels;
    SDL_Surface *s = SDL_CreateRGBSurfaceWithFormatFrom((void *)src, w, h, 32, w * 4, SDL_PIXELFORMAT_ARGB8888);
    if (!s) return;
    char name[64];
    snprintf(name, sizeof name, "momopie_%u.bmp", (unsigned)SDL_GetTicks());
    SDL_SaveBMP(s, name);
    SDL_FreeSurface(s);
}

static void frame(unsigned f) {
    SDL_Event e;
    (void)f;
    for (;;) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT || (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)) exit(0);
            if (e.type == SDL_CONTROLLERDEVICEADDED && !pad) pad = SDL_GameControllerOpen(e.cdevice.which);
            if (e.type == SDL_CONTROLLERBUTTONDOWN && gb_config.quick_magic) {
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_LEFTSHOULDER) gb_quick_cycle = -1;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_RIGHTSHOULDER) gb_quick_cycle = 1;
            }
            if (e.type != SDL_KEYDOWN || e.key.repeat) continue;
            SDL_Keycode k = e.key.keysym.sym;
            if (k == SDLK_F11) SDL_SetWindowFullscreen(win, (SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN_DESKTOP) ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP);
            else if (k == SDLK_p) paused = !paused;
            else if (k == SDLK_m) muted = !muted;
            else if (k == SDLK_F2) pal_index = (pal_index + 1) % gb_palette_count;
            else if (k == SDLK_F5) want_reload = 1;
            else if (k == SDLK_F12) want_shot = 1;
            if (bound_is(8, k)) gb_quick_cycle = -1;
            if (bound_is(9, k)) gb_quick_cycle = 1;
        }
        memcpy(gb_color_pal, gb_palettes[pal_index], sizeof gb_color_pal);
        for (int i = 0; i < gb_view_w * 144; i++) pixels[i] = gb_palettes[pal_index][gb_framebuf[i] & 3];
        present();
        if (!paused) break;
        SDL_Delay(30);
    }
    if (want_shot) { want_shot = 0; save_screenshot(); }
    if (want_reload) { want_reload = 0; gb_texture_reload_all(); }
    const Uint8 *ks = SDL_GetKeyboardState(0);
    fast = ks[SDL_SCANCODE_TAB];
    uint8_t j = 0;
    for (int a = 0; a < 8; a++) if (bound_down(ks, a)) j |= (uint8_t)(1 << a);
    if (pad) {
        unsigned b = pad_buttons();
        int lx = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTX), ly = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTY);
        if (SDL_GameControllerGetButton(pad, SDL_CONTROLLER_BUTTON_DPAD_RIGHT) || lx > 16000) j |= 0x01;
        if (SDL_GameControllerGetButton(pad, SDL_CONTROLLER_BUTTON_DPAD_LEFT) || lx < -16000) j |= 0x02;
        if (SDL_GameControllerGetButton(pad, SDL_CONTROLLER_BUTTON_DPAD_UP) || ly < -16000) j |= 0x04;
        if (SDL_GameControllerGetButton(pad, SDL_CONTROLLER_BUTTON_DPAD_DOWN) || ly > 16000) j |= 0x08;
        if (b & gb_config.pad[0]) j |= 0x10;
        if (b & gb_config.pad[1]) j |= 0x20;
        if (b & gb_config.pad[2]) j |= 0x40;
        if (b & gb_config.pad[3]) j |= 0x80;
    }
    gb_joy = j;
}

static void audio(const int16_t *st, int n) {
    static int16_t silence[735 * 2], scaled[735 * 2];
    if (fast) return;                                                   /* fast forward: no audio, no pacing */
    if (gb_config.speed != 100) {                                       /* option speed: paced by the clock, no sound */
        static Uint64 next;
        Uint64 freq = SDL_GetPerformanceFrequency(), now = SDL_GetPerformanceCounter();
        if (next < now - freq / 10) next = now;
        next += (Uint64)(freq * 70224.0 / 4194304.0 * 100.0 / gb_config.speed);
        while (SDL_GetPerformanceCounter() < next) SDL_Delay(1);
        return;
    }
    if (muted) st = silence;
    else if (gb_config.volume < 100) {
        for (int i = 0; i < n * 2; i++) scaled[i] = (int16_t)(st[i] * gb_config.volume / 100);
        st = scaled;
    }
    while (SDL_GetQueuedAudioSize(dev) > (Uint32)n * 4 * 3) SDL_Delay(1);   /* the audio clock paces the game */
    SDL_QueueAudio(dev, st, (Uint32)n * 4);
}

int main(int argc, char **argv) {
    static uint8_t rom[1 << 20];
    const char *ini = 0, *pack = 0;
    int round = 0, first = 1;
    if (argc > 1 && strncmp(argv[1], "--", 2)) {
        FILE *f = fopen(argv[1], "rb");
        if (f) {                                    /* optional ROM file (to try a modded ROM); otherwise the built-in data is used */
            size_t n = fread(rom, 1, sizeof rom, f);
            fclose(f);
            gb_load_rom(rom, n);
            first = 2;
        }
    }
    if (first == 1) gb_load_rom(gb_rom_image, gb_rom_image_size);
    for (int i = 1; i + 1 < argc; i++) {
        if (!strcmp(argv[i], "--ini")) ini = argv[i + 1];
        else if (!strcmp(argv[i], "--pack")) pack = argv[i + 1];
        else if (!strcmp(argv[i], "--round")) round = atoi(argv[i + 1]);
    }
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMECONTROLLER) != 0) { fprintf(stderr, "SDL: %s\n", SDL_GetError()); return 1; }
    {   /* options: painter_momopie.ini next to the program, else in the current folder */
        char path[1024] = "painter_momopie.ini";
        if (!ini) {
            char *base = SDL_GetBasePath();
            if (base) {
                snprintf(path, sizeof path, "%spainter_momopie.ini", base);
                FILE *t = fopen(path, "r");
                if (t) fclose(t); else strcpy(path, "painter_momopie.ini");
                SDL_free(base);
            }
            ini = path;
        }
        gb_config_load(ini);
        if (pack) gb_pack_load(pack);
        if (round) gb_config.start_round = round;
        for (int i = 1; i + 1 < argc; i++) if (!strcmp(argv[i], "--replay")) gb_replay_play(argv[i + 1]);
        for (int i = 1; i + 1 < argc; i++) if (!strcmp(argv[i], "--record") && !gb_replay_active) gb_replay_record(argv[i + 1]);
        bind_keys();
        pal_index = gb_config.palette < gb_palette_count ? gb_config.palette : 0;
        muted = gb_config.mute;
        gb_sprite_limit_off = gb_config.no_sprite_limit;
    }
    win = SDL_CreateWindow("Painter Momopie", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, gb_view_w * gb_config.scale, 144 * gb_config.scale,
                           SDL_WINDOW_RESIZABLE | (gb_config.fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0));
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_PRESENTVSYNC);
    SDL_RenderSetIntegerScale(ren, gb_config.integer_scale ? SDL_TRUE : SDL_FALSE);
    for (int i = 0; i < SDL_NumJoysticks(); i++) if (SDL_IsGameController(i)) { pad = SDL_GameControllerOpen(i); break; }
    SDL_AudioSpec want = {0}, have;
    want.freq = 44100; want.format = AUDIO_S16SYS; want.channels = 2; want.samples = 735;
    dev = SDL_OpenAudioDevice(0, 0, &want, &have, 0);
    gb_frame_hook = frame;
    if (dev) { SDL_PauseAudioDevice(dev, 0); gb_audio_hook = audio; }
    gb_game_main();
    return 0;
}

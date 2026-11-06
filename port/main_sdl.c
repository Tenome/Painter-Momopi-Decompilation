/* SDL2 front end for the recompiled game (Linux, macOS, or Windows with SDL2). Same keys as main_win32.c.
 * Not yet tested on this project's CI machine: it only uses plain SDL2 calls.
 *   game_sdl [ROM]   (default: painter_momopie.gb in the current directory, then orig/painter_momopie.gb) */
#include <SDL.h>
#include "gb_rt.h"

extern void gb_game_main(void);

static SDL_Window *win;
static SDL_Renderer *ren;
static SDL_Texture *tex;
static SDL_AudioDeviceID dev;
static uint32_t pixels[160 * 144];
static const uint32_t shades[4] = {0xFFE0F8D0, 0xFF88C070, 0xFF346856, 0xFF081820};

static void frame(unsigned f) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT || (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)) exit(0);
        if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_F11)
            SDL_SetWindowFullscreen(win, (SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN_DESKTOP) ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP);
    }
    for (int i = 0; i < 160 * 144; i++) pixels[i] = shades[gb_framebuf[i] & 3];
    SDL_UpdateTexture(tex, 0, pixels, 160 * 4);
    SDL_RenderClear(ren);
    SDL_RenderCopy(ren, tex, 0, 0);
    SDL_RenderPresent(ren);
    const Uint8 *k = SDL_GetKeyboardState(0);
    uint8_t j = 0;
    if (k[SDL_SCANCODE_RIGHT]) j |= 0x01;
    if (k[SDL_SCANCODE_LEFT]) j |= 0x02;
    if (k[SDL_SCANCODE_UP]) j |= 0x04;
    if (k[SDL_SCANCODE_DOWN]) j |= 0x08;
    if (k[SDL_SCANCODE_Z]) j |= 0x10;
    if (k[SDL_SCANCODE_X]) j |= 0x20;
    if (k[SDL_SCANCODE_RSHIFT] || k[SDL_SCANCODE_BACKSPACE]) j |= 0x40;
    if (k[SDL_SCANCODE_RETURN]) j |= 0x80;
    gb_joy = j;
}

static void audio(const int16_t *st, int n) {
    while (SDL_GetQueuedAudioSize(dev) > (Uint32)n * 4 * 3) SDL_Delay(1);   /* the audio clock paces the game */
    SDL_QueueAudio(dev, st, (Uint32)n * 4);
}

int main(int argc, char **argv) {
    static uint8_t rom[1 << 20];
    FILE *f = argc > 1 ? fopen(argv[1], "rb") : 0;
    if (!f) f = fopen("painter_momopie.gb", "rb");
    if (!f) f = fopen("orig/painter_momopie.gb", "rb");
    if (!f) { fprintf(stderr, "ROM not found. Usage: %s ROM.gb\n", argv[0]); return 1; }
    size_t n = fread(rom, 1, sizeof rom, f);
    fclose(f);
    gb_load_rom(rom, n);
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) { fprintf(stderr, "SDL: %s\n", SDL_GetError()); return 1; }
    win = SDL_CreateWindow("Painter Momopie", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 640, 576, SDL_WINDOW_RESIZABLE);
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_PRESENTVSYNC);
    SDL_RenderSetLogicalSize(ren, 160, 144);
    SDL_RenderSetIntegerScale(ren, SDL_TRUE);
    tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 160, 144);
    SDL_AudioSpec want = {0}, have;
    want.freq = 44100; want.format = AUDIO_S16SYS; want.channels = 2; want.samples = 735;
    dev = SDL_OpenAudioDevice(0, 0, &want, &have, 0);
    gb_frame_hook = frame;
    if (dev) { SDL_PauseAudioDevice(dev, 0); gb_audio_hook = audio; }
    gb_game_main();
    return 0;
}

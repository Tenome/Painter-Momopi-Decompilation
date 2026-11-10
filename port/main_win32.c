/* Windows front end for the recompiled game: window, keyboard, audio (waveOut), frame pacing by the audio clock.
 * Keys: arrows = D-pad, Z = A, X = B, Enter = Start, Right Shift / Backspace = Select, F11 = fullscreen toggle, Esc = quit,
 * P = pause, M = mute, F2 = next palette (green/grey/sepia), F12 = screenshot (screenshots folder), hold Tab = fast forward.
 *   game_win [ROM]     (no argument: the game data built into the program; a ROM file argument is for testing mods) */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <mmsystem.h>
#include "gb_rt.h"
#include "config.h"
#include "texture.h"
#include "levelpack.h"

extern void gb_game_main(void);
extern const unsigned char gb_rom_image[];
extern const size_t gb_rom_image_size;

static HWND hwnd;
static uint32_t pixels[GB_MAX_W * 144];     /* the picture without a texture pack; with one gb_colorbuf is shown */
static const uint32_t palettes[3][4] = {
    {0x00E0F8D0, 0x0088C070, 0x00346856, 0x00081820},   /* DMG green */
    {0x00FFFFFF, 0x00AAAAAA, 0x00555555, 0x00000000},   /* grey */
    {0x00F8E8C8, 0x00D8A860, 0x00985820, 0x00301810},   /* sepia */
};
static int pal_index;
static int paused, muted, fast;
static int fullscreen;
static WINDOWPLACEMENT saved_pos;
#define NBUF 4
static WAVEHDR hdr[NBUF];
static int16_t abuf[NBUF][735 * 2];
static HWAVEOUT wave;
static int quit;

static void toggle_fullscreen(HWND h) {
    DWORD st = GetWindowLong(h, GWL_STYLE);
    if (!fullscreen) {
        MONITORINFO mi = {sizeof mi};
        saved_pos.length = sizeof saved_pos;
        GetWindowPlacement(h, &saved_pos);
        GetMonitorInfo(MonitorFromWindow(h, MONITOR_DEFAULTTOPRIMARY), &mi);
        SetWindowLong(h, GWL_STYLE, st & ~WS_OVERLAPPEDWINDOW);
        SetWindowPos(h, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top, SWP_FRAMECHANGED);
    } else {
        SetWindowLong(h, GWL_STYLE, st | WS_OVERLAPPEDWINDOW);
        SetWindowPlacement(h, &saved_pos);
        SetWindowPos(h, 0, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    }
    fullscreen = !fullscreen;
}

/* F12: the picture as a PNG (stored, uncompressed deflate blocks) in the screenshots folder next to the program */
static uint32_t crc_table[256];
static uint32_t crc32_of(uint32_t crc, const uint8_t *p, size_t n) {
    if (!crc_table[1]) for (uint32_t i = 0; i < 256; i++) { uint32_t c = i; for (int k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320u ^ (c >> 1) : c >> 1; crc_table[i] = c; }
    crc = ~crc;
    while (n--) crc = crc_table[(crc ^ *p++) & 255] ^ (crc >> 8);
    return ~crc;
}
static void be32w(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }
static void chunk(FILE *f, const char *type, const uint8_t *data, uint32_t n) {
    uint8_t h[8], c[4];
    be32w(h, n); memcpy(h + 4, type, 4);
    fwrite(h, 1, 8, f);
    if (n) fwrite(data, 1, n, f);
    uint8_t *tmp = malloc(4 + n);                         /* the crc covers the type and the data */
    memcpy(tmp, type, 4);
    if (n) memcpy(tmp + 4, data, n);
    uint32_t crc = crc32_of(0, tmp, 4 + n);
    free(tmp);
    be32w(c, crc);
    fwrite(c, 1, 4, f);
}
static void save_screenshot(void) {
    int cs = gb_tex_count ? gb_color_scale : 1, w = gb_view_w * cs, h = 144 * cs;
    const uint32_t *src = gb_tex_count ? gb_colorbuf : pixels;
    size_t raw_n = (size_t)(w * 3 + 1) * h;
    uint8_t *raw = malloc(raw_n), *o = raw;
    for (int y = 0; y < h; y++) {
        *o++ = 0;
        for (int x = 0; x < w; x++) { uint32_t v = src[y * w + x]; *o++ = (uint8_t)(v >> 16); *o++ = (uint8_t)(v >> 8); *o++ = (uint8_t)v; }
    }
    size_t zn = 2 + raw_n + 5 * (raw_n / 65535 + 1) + 4;
    uint8_t *z = malloc(zn), *q = z;
    *q++ = 0x78; *q++ = 1;
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < raw_n; i++) { a = (a + raw[i]) % 65521; b = (b + a) % 65521; }
    for (size_t pos = 0; pos < raw_n || pos == 0;) {
        size_t n = raw_n - pos > 65535 ? 65535 : raw_n - pos;
        *q++ = pos + n >= raw_n; *q++ = (uint8_t)n; *q++ = (uint8_t)(n >> 8); *q++ = (uint8_t)~n; *q++ = (uint8_t)(~n >> 8);
        memcpy(q, raw + pos, n); q += n; pos += n;
        if (pos >= raw_n) break;
    }
    be32w(q, (b << 16) | a); q += 4;
    char exe[MAX_PATH], path[MAX_PATH];
    GetModuleFileNameA(0, exe, MAX_PATH);
    char *slash = strrchr(exe, 92);
    if (slash) slash[1] = 0; else exe[0] = 0;
    snprintf(path, sizeof path, "%sscreenshots", exe);
    CreateDirectoryA(path, 0);
    SYSTEMTIME t;
    GetLocalTime(&t);
    snprintf(path, sizeof path, "%sscreenshots%cpm_%04d%02d%02d_%02d%02d%02d.png", exe, 92, t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
    FILE *f = fopen(path, "wb");
    if (f) {
        static const uint8_t sig[8] = {0x89, 'P', 'N', 'G', 13, 10, 26, 10};
        uint8_t ihdr[13];
        be32w(ihdr, (uint32_t)w); be32w(ihdr + 4, (uint32_t)h);
        ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = ihdr[11] = ihdr[12] = 0;
        fwrite(sig, 1, 8, f);
        chunk(f, "IHDR", ihdr, 13);
        chunk(f, "IDAT", z, (uint32_t)(q - z));
        chunk(f, "IEND", 0, 0);
        fclose(f);
    }
    free(raw); free(z);
}
static int want_shot;

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
    case WM_DESTROY: quit = 1; PostQuitMessage(0); return 0;
    case WM_KEYDOWN:
        if (w == VK_ESCAPE) { quit = 1; DestroyWindow(h); }
        if (w == 'P') paused = !paused;
        if (w == 'M') muted = !muted;
        if (w == VK_F2) pal_index = (pal_index + 1) % 3;
        if (w == VK_F11) toggle_fullscreen(h);
        if (w == VK_F12) want_shot = 1;
        if (w == 'Q') gb_quick_cycle = -1;                   /* option quick_magic: previous / next magic card */
        if (w == 'E') gb_quick_cycle = 1;
        return 0;
    case WM_ERASEBKGND: return 1;
    }
    return DefWindowProc(h, m, w, l);
}

static void present(void) {
    RECT rc;
    GetClientRect(hwnd, &rc);
    int cw = rc.right, ch = rc.bottom, vw = gb_view_w;
    int cs = gb_tex_count ? gb_color_scale : 1;           /* the colour picture is cs times larger than the Game Boy one */
    const uint32_t *src = gb_tex_count ? gb_colorbuf : pixels;
    int w, h;
    if (gb_config.integer_scale) {
        int scale = cw / vw < ch / 144 ? cw / vw : ch / 144;
        if (scale < 1) scale = 1;
        w = vw * scale; h = 144 * scale;
    } else {                                           /* fill the window, keep the aspect ratio */
        if (cw * 144 < ch * vw) { w = cw; h = cw * 144 / vw; } else { h = ch; w = ch * vw / 144; }
    }
    int x = (cw - w) / 2, y = (ch - h) / 2;
    BITMAPINFO bi = {{sizeof(BITMAPINFOHEADER), vw * cs, -144 * cs, 1, 32, BI_RGB}};
    HDC dc = GetDC(hwnd);
    /* only the bars around the picture are cleared: clearing the whole window first made it flicker */
    if (y > 0) { PatBlt(dc, 0, 0, cw, y, BLACKNESS); }
    if (y + h < ch) { PatBlt(dc, 0, y + h, cw, ch - y - h, BLACKNESS); }
    if (x > 0) { PatBlt(dc, 0, y, x, h, BLACKNESS); }
    if (x + w < cw) { PatBlt(dc, x + w, y, cw - x - w, h, BLACKNESS); }
    SetStretchBltMode(dc, cs > 1 ? HALFTONE : COLORONCOLOR);
    StretchDIBits(dc, x, y, w, h, 0, 0, vw * cs, 144 * cs, src, &bi, DIB_RGB_COLORS, SRCCOPY);
    ReleaseDC(hwnd, dc);
}

static uint8_t keys(void) {
    uint8_t j = 0;
    if (GetForegroundWindow() != hwnd) return 0;
    if (GetAsyncKeyState(VK_RIGHT) & 0x8000) j |= 0x01;
    if (GetAsyncKeyState(VK_LEFT) & 0x8000) j |= 0x02;
    if (GetAsyncKeyState(VK_UP) & 0x8000) j |= 0x04;
    if (GetAsyncKeyState(VK_DOWN) & 0x8000) j |= 0x08;
    if (GetAsyncKeyState('Z') & 0x8000) j |= 0x10;
    if (GetAsyncKeyState('X') & 0x8000) j |= 0x20;
    if ((GetAsyncKeyState(VK_RSHIFT) & 0x8000) || (GetAsyncKeyState(VK_BACK) & 0x8000)) j |= 0x40;
    if (GetAsyncKeyState(VK_RETURN) & 0x8000) j |= 0x80;
    {   /* a gamepad (first joystick, winmm): D-pad or left stick, button 1 = A, 2 = B, 7/8 = Select/Start (or 9/10) */
        JOYINFOEX ji = {sizeof ji, JOY_RETURNALL};
        if (joyGetPosEx(0, &ji) == JOYERR_NOERROR) {
            static DWORD prev_buttons;
            if ((ji.dwButtons & 0x10) && !(prev_buttons & 0x10)) gb_quick_cycle = -1;        /* shoulder buttons 5 and 6 */
            if ((ji.dwButtons & 0x20) && !(prev_buttons & 0x20)) gb_quick_cycle = 1;
            prev_buttons = ji.dwButtons;
            if (ji.dwXpos > 0xC000) j |= 0x01;
            if (ji.dwXpos < 0x4000) j |= 0x02;
            if (ji.dwYpos < 0x4000) j |= 0x04;
            if (ji.dwYpos > 0xC000) j |= 0x08;
            if (ji.dwPOV != JOY_POVCENTERED && ji.dwPOV <= 36000) {
                unsigned d = ji.dwPOV / 100;
                if (d > 0 && d < 180) j |= 0x01;
                if (d > 180) j |= 0x02;
                if (d > 270 || d < 90) j |= 0x04;
                if (d > 90 && d < 270) j |= 0x08;
            }
            if (ji.dwButtons & 0x01) j |= 0x10;
            if (ji.dwButtons & 0x02) j |= 0x20;
            if (ji.dwButtons & (0x40 | 0x100)) j |= 0x40;
            if (ji.dwButtons & (0x80 | 0x200)) j |= 0x80;
        }
    }
    return j;
}

static void frame(unsigned f) {
    MSG msg;
    while (PeekMessage(&msg, 0, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    if (quit) { if (wave) waveOutReset(wave); ExitProcess(0); }
    for (;;) {
        memcpy(gb_color_pal, palettes[pal_index], sizeof gb_color_pal);
        for (int i = 0; i < gb_view_w * 144; i++) pixels[i] = palettes[pal_index][gb_framebuf[i] & 3];
        present();
        if (!paused) break;
        while (PeekMessage(&msg, 0, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
        if (quit) { if (wave) waveOutReset(wave); ExitProcess(0); }
        Sleep(30);
    }
    if (want_shot) { want_shot = 0; save_screenshot(); }
    fast = (GetAsyncKeyState(VK_TAB) & 0x8000) && GetForegroundWindow() == hwnd;
    gb_joy = keys();
}

static void audio(const int16_t *st, int n) {
    if (fast) return;                                  /* fast forward: no audio, no pacing */
    if (gb_config.speed != 100) {                      /* option speed: paced by the clock, no sound */
        static LARGE_INTEGER freq, next;
        LARGE_INTEGER now;
        if (!freq.QuadPart) QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&now);
        if (next.QuadPart < now.QuadPart - freq.QuadPart / 10) next = now;
        next.QuadPart += (LONGLONG)(freq.QuadPart * 70224.0 / 4194304.0 * 100.0 / gb_config.speed);
        while (now.QuadPart < next.QuadPart) {
            LONGLONG left = (next.QuadPart - now.QuadPart) * 1000 / freq.QuadPart;
            if (left > 1) Sleep((DWORD)(left - 1));
            QueryPerformanceCounter(&now);
        }
        return;
    }
    static int16_t silence[735 * 2], scaled[735 * 2];
    if (muted) st = silence;
    else if (gb_config.volume < 100) {
        for (int i = 0; i < n * 2; i++) scaled[i] = (int16_t)(st[i] * gb_config.volume / 100);
        st = scaled;
    }
    for (;;) {
        for (int i = 0; i < NBUF; i++) {
            if (!(hdr[i].dwFlags & WHDR_INQUEUE)) {
                if (hdr[i].dwFlags & WHDR_PREPARED) waveOutUnprepareHeader(wave, &hdr[i], sizeof hdr[i]);
                memcpy(abuf[i], st, (size_t)n * 4);
                hdr[i].lpData = (LPSTR)abuf[i];
                hdr[i].dwBufferLength = (DWORD)n * 4;
                hdr[i].dwFlags = 0;
                waveOutPrepareHeader(wave, &hdr[i], sizeof hdr[i]);
                waveOutWrite(wave, &hdr[i], sizeof hdr[i]);
                return;
            }
        }
        Sleep(1);                                   /* all buffers queued: the audio clock paces the game */
    }
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show) {
    static uint8_t rom[1 << 20];
    char path[MAX_PATH] = "";
    int argc;
    LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    FILE *f = 0;
    if (argc > 1) { WideCharToMultiByte(CP_ACP, 0, argv[1], -1, path, MAX_PATH, 0, 0); f = fopen(path, "rb"); }
    if (f) {                                        /* optional ROM file argument (to try a modded ROM); otherwise the built-in data is used */
        size_t n = fread(rom, 1, sizeof rom, f);
        fclose(f);
        gb_load_rom(rom, n);
    } else gb_load_rom(gb_rom_image, gb_rom_image_size);

    {   /* options: painter_momopie.ini next to the program, else in the current folder */
        char ini[MAX_PATH];
        GetModuleFileNameA(0, ini, MAX_PATH);
        char *slash = strrchr(ini, 92);
        if (slash) strcpy(slash + 1, "painter_momopie.ini"); else strcpy(ini, "painter_momopie.ini");
        FILE *t = fopen(ini, "r");
        if (t) fclose(t); else strcpy(ini, "painter_momopie.ini");
        gb_config_load(ini);
        for (int i = 1; i + 1 < argc; i++) {              /* command line: --pack FILE (a level pack) and --round N (first round) override the ini */
            char arg[MAX_PATH];
            WideCharToMultiByte(CP_ACP, 0, argv[i], -1, arg, MAX_PATH, 0, 0);
            if (!strcmp(arg, "--pack")) { WideCharToMultiByte(CP_ACP, 0, argv[i + 1], -1, path, MAX_PATH, 0, 0); gb_pack_load(path); }
            else if (!strcmp(arg, "--round")) gb_config.start_round = atoi((WideCharToMultiByte(CP_ACP, 0, argv[i + 1], -1, path, MAX_PATH, 0, 0), path));
        }
        pal_index = gb_config.palette;
        muted = gb_config.mute;
        gb_sprite_limit_off = gb_config.no_sprite_limit;
    }
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = proc; wc.hInstance = inst; wc.lpszClassName = "gbrecomp"; wc.hCursor = LoadCursor(0, IDC_ARROW);
    RegisterClassA(&wc);
    RECT r = {0, 0, gb_view_w * gb_config.scale, 144 * gb_config.scale};
    AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, 0);
    hwnd = CreateWindowA("gbrecomp", "Painter Momopie", WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
                         r.right - r.left, r.bottom - r.top, 0, 0, inst, 0);
    if (gb_config.fullscreen) toggle_fullscreen(hwnd);
    WAVEFORMATEX wf = {WAVE_FORMAT_PCM, 2, 44100, 44100 * 4, 4, 16, 0};
    if (waveOutOpen(&wave, WAVE_MAPPER, &wf, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) wave = 0;
    gb_frame_hook = frame;
    if (wave) gb_audio_hook = audio;
    gb_game_main();
    return 0;
}

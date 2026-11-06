/* Windows front end for the recompiled game: window, keyboard, audio (waveOut), frame pacing by the audio clock.
 * Keys: arrows = D-pad, Z = A, X = B, Enter = Start, Right Shift / Backspace = Select, F11 = fullscreen toggle, Esc = quit,
 * P = pause, M = mute, F2 = next palette (green/grey/sepia), hold Tab = fast forward.
 *   game_win [ROM]     (no argument: the game data built into the program; a ROM file argument is for testing mods) */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <mmsystem.h>
#include "gb_rt.h"

extern void gb_game_main(void);
extern const unsigned char gb_rom_image[];
extern const size_t gb_rom_image_size;

static HWND hwnd;
static uint32_t pixels[160 * 144];
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

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
    case WM_DESTROY: quit = 1; PostQuitMessage(0); return 0;
    case WM_KEYDOWN:
        if (w == VK_ESCAPE) { quit = 1; DestroyWindow(h); }
        if (w == 'P') paused = !paused;
        if (w == 'M') muted = !muted;
        if (w == VK_F2) pal_index = (pal_index + 1) % 3;
        if (w == VK_F11) {
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
        return 0;
    case WM_ERASEBKGND: return 1;
    }
    return DefWindowProc(h, m, w, l);
}

static void present(void) {
    RECT rc;
    GetClientRect(hwnd, &rc);
    int cw = rc.right, ch = rc.bottom;
    int scale = cw / 160 < ch / 144 ? cw / 160 : ch / 144;
    if (scale < 1) scale = 1;
    int w = 160 * scale, h = 144 * scale, x = (cw - w) / 2, y = (ch - h) / 2;
    BITMAPINFO bi = {{sizeof(BITMAPINFOHEADER), 160, -144, 1, 32, BI_RGB}};
    HDC dc = GetDC(hwnd);
    PatBlt(dc, 0, 0, cw, ch, BLACKNESS);
    StretchDIBits(dc, x, y, w, h, 0, 0, 160, 144, pixels, &bi, DIB_RGB_COLORS, SRCCOPY);
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
        for (int i = 0; i < 160 * 144; i++) pixels[i] = palettes[pal_index][gb_framebuf[i] & 3];
        present();
        if (!paused) break;
        while (PeekMessage(&msg, 0, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
        if (quit) { if (wave) waveOutReset(wave); ExitProcess(0); }
        Sleep(30);
    }
    fast = (GetAsyncKeyState(VK_TAB) & 0x8000) && GetForegroundWindow() == hwnd;
    gb_joy = keys();
}

static void audio(const int16_t *st, int n) {
    if (fast) return;                                  /* fast forward: no audio, no pacing */
    static int16_t silence[735 * 2];
    if (muted) st = silence;
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

    WNDCLASSA wc = {0};
    wc.lpfnWndProc = proc; wc.hInstance = inst; wc.lpszClassName = "gbrecomp"; wc.hCursor = LoadCursor(0, IDC_ARROW);
    RegisterClassA(&wc);
    RECT r = {0, 0, 160 * 4, 144 * 4};
    AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, 0);
    hwnd = CreateWindowA("gbrecomp", "Painter Momopie", WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
                         r.right - r.left, r.bottom - r.top, 0, 0, inst, 0);
    WAVEFORMATEX wf = {WAVE_FORMAT_PCM, 2, 44100, 44100 * 4, 4, 16, 0};
    if (waveOutOpen(&wave, WAVE_MAPPER, &wf, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) wave = 0;
    gb_frame_hook = frame;
    if (wave) gb_audio_hook = audio;
    gb_game_main();
    return 0;
}

/* Painter Momopie player settings: a small Windows window that edits painter_momopie.ini (next to this program) and can start the game.
 * Build: tools/build_port.py (clang ... config_gui.c -mwindows -luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32 -lole32). */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>
#include <commctrl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

enum { ID_SCALE = 100, ID_FULL, ID_INT, ID_PAL, ID_WIDE, ID_WIDE_L, ID_SPR, ID_VOL, ID_VOL_L, ID_MUTE, ID_SPEED, ID_SPEED_L, ID_INF, ID_LIVES, ID_ROUND,
       ID_TEX, ID_TEX_ON, ID_BROWSE, ID_OPEN, ID_SAVE, ID_PLAY, ID_RESET, ID_CLOSE, ID_TEX_HELP, ID_PACK, ID_PACKBR, ID_CARDS, ID_MAGIC, ID_TIME, ID_QUICK, ID_BEST, ID_RESUME, ID_EDITOR };

static HWND wnd, hscale, hfull, hint, hpal, hwide, hwide_l, hspr, hvol, hvol_l, hmute, hspeed, hspeed_l, hinf, hlives, hround, htex, hbrowse, hopen, hpack, hcards, hmagic, htime, hquick, hbest, hresume;
static char ini_path[MAX_PATH], exe_dir[MAX_PATH];
static HFONT font;

typedef struct { int scale, fullscreen, integer_scale, palette, widescreen, no_sprite_limit, volume, mute, speed, infinite_lives, start_lives, start_round; char texture_pack[MAX_PATH]; char level_pack[MAX_PATH]; int all_cards, infinite_magic, no_time_limit, quick_magic, high_score, resume; } Cfg;
static const Cfg defaults = {4, 0, 1, 0, 0, 0, 100, 0, 100, 0, 3, 0, "textures", "", 0, 0, 0, 0, 0, 0};
static Cfg cfg;
static char keylines[1024];                    /* the [keys] lines of the ini are kept as they are */

static int clampi(int v, int lo, int hi) { return v < lo ? lo : v > hi ? hi : v; }

static void load(void) {
    cfg = defaults;
    FILE *f = fopen(ini_path, "r");
    if (!f) return;
    char line[512];
    while (fgets(line, sizeof line, f)) {
        char *p = line;
        while (isspace((unsigned char)*p)) p++;
        if (*p == ';' || *p == '#' || *p == '[' || !*p) continue;
        char *eq = strchr(p, '=');
        if (!eq) continue;
        *eq = 0;
        char *e = eq - 1;
        while (e >= p && isspace((unsigned char)*e)) *e-- = 0;
        char *v = eq + 1;
        char *semi = strchr(v, ';');                   /* trailing comment */
        if (semi) *semi = 0;
        while (isspace((unsigned char)*v)) v++;
        for (e = v + strlen(v) - 1; e >= v && isspace((unsigned char)*e); e--) *e = 0;
        for (char *q = p; *q; q++) *q = (char)tolower((unsigned char)*q);
        int n = atoi(v);
        if (!strncmp(p, "key_", 4) || !strncmp(p, "pad_", 4) || !strcmp(p, "music_folder") || !strcmp(p, "palette_colors") || !strcmp(p, "filter") || !strcmp(p, "pause_on_focus_loss")) { size_t n = strlen(keylines); snprintf(keylines + n, sizeof keylines - n, "%s=%s%c", p, v, 10); continue; }
        if (!strcmp(p, "scale")) cfg.scale = clampi(n, 1, 16);
        else if (!strcmp(p, "fullscreen")) cfg.fullscreen = n != 0;
        else if (!strcmp(p, "integer_scale")) cfg.integer_scale = n != 0;
        else if (!strcmp(p, "palette")) cfg.palette = clampi(n, 0, 4);
        else if (!strcmp(p, "widescreen")) cfg.widescreen = clampi(n, 0, 40);
        else if (!strcmp(p, "no_sprite_limit")) cfg.no_sprite_limit = n != 0;
        else if (!strcmp(p, "volume")) cfg.volume = clampi(n, 0, 100);
        else if (!strcmp(p, "mute")) cfg.mute = n != 0;
        else if (!strcmp(p, "speed")) cfg.speed = clampi(n, 50, 400);
        else if (!strcmp(p, "infinite_lives")) cfg.infinite_lives = n != 0;
        else if (!strcmp(p, "start_lives")) cfg.start_lives = n ? clampi(n, 1, 99) : 3;
        else if (!strcmp(p, "start_round")) cfg.start_round = clampi(n, 0, 33);
        else if (!strcmp(p, "quick_magic")) cfg.quick_magic = n != 0;
        else if (!strcmp(p, "high_score")) cfg.high_score = n != 0;
        else if (!strcmp(p, "resume")) cfg.resume = n != 0;
        else if (!strcmp(p, "all_cards")) cfg.all_cards = n != 0;
        else if (!strcmp(p, "infinite_magic")) cfg.infinite_magic = n != 0;
        else if (!strcmp(p, "no_time_limit")) cfg.no_time_limit = n != 0;
        else if (!strcmp(p, "level_pack")) { strncpy(cfg.level_pack, v, MAX_PATH - 1); cfg.level_pack[MAX_PATH - 1] = 0; }
        else if (!strcmp(p, "texture_pack")) { strncpy(cfg.texture_pack, v, MAX_PATH - 1); cfg.texture_pack[MAX_PATH - 1] = 0; }
    }
    fclose(f);
}

static int save(void) {
    FILE *f = fopen(ini_path, "w");
    if (!f) { MessageBoxA(wnd, "Cannot write painter_momopie.ini (is the folder read-only?).", "Painter Momopie settings", MB_ICONERROR); return 0; }
    fprintf(f,
        "; Options of the native Painter Momopie player (written by the settings program; you can also edit it by hand).\n\n"
        "[display]\nscale=%d\nfullscreen=%d\ninteger_scale=%d\npalette=%d\nwidescreen=%d\nno_sprite_limit=%d\ntexture_pack=%s\n\n"
        "[keys]\n%s\n"
        "[audio]\nvolume=%d\nmute=%d\n\n"
        "[game]\nlevel_pack=%s\nspeed=%d\ninfinite_lives=%d\nstart_lives=%d\nstart_round=%d\nall_cards=%d\ninfinite_magic=%d\nno_time_limit=%d\nquick_magic=%d\nhigh_score=%d\nresume=%d\n",
        cfg.scale, cfg.fullscreen, cfg.integer_scale, cfg.palette, cfg.widescreen, cfg.no_sprite_limit, cfg.texture_pack,
        keylines,
        cfg.volume, cfg.mute, cfg.level_pack, cfg.speed, cfg.infinite_lives, cfg.start_lives, cfg.start_round, cfg.all_cards, cfg.infinite_magic, cfg.no_time_limit, cfg.quick_magic, cfg.high_score, cfg.resume);
    fclose(f);
    return 1;
}

static void to_controls(void) {
    char b[64];
    SendMessage(hscale, CB_SETCURSEL, cfg.scale - 1 > 7 ? 7 : cfg.scale - 1, 0);
    SendMessage(hfull, BM_SETCHECK, cfg.fullscreen, 0);
    SendMessage(hint, BM_SETCHECK, cfg.integer_scale, 0);
    SendMessage(hpal, CB_SETCURSEL, cfg.palette, 0);
    SendMessage(hwide, TBM_SETPOS, TRUE, cfg.widescreen);
    snprintf(b, sizeof b, "%d px", cfg.widescreen); SetWindowTextA(hwide_l, b);
    SendMessage(hspr, BM_SETCHECK, cfg.no_sprite_limit, 0);
    SendMessage(hvol, TBM_SETPOS, TRUE, cfg.volume);
    snprintf(b, sizeof b, "%d%%", cfg.volume); SetWindowTextA(hvol_l, b);
    SendMessage(hmute, BM_SETCHECK, cfg.mute, 0);
    SendMessage(hspeed, TBM_SETPOS, TRUE, cfg.speed);
    snprintf(b, sizeof b, "%d%%", cfg.speed); SetWindowTextA(hspeed_l, b);
    SendMessage(hinf, BM_SETCHECK, cfg.infinite_lives, 0);
    snprintf(b, sizeof b, "%d", cfg.start_lives); SetWindowTextA(hlives, b);
    SendMessage(hround, CB_SETCURSEL, cfg.start_round, 0);
    SetWindowTextA(htex, cfg.texture_pack);
    SetWindowTextA(hpack, cfg.level_pack);
    SendMessage(hcards, BM_SETCHECK, cfg.all_cards, 0);
    SendMessage(hmagic, BM_SETCHECK, cfg.infinite_magic, 0);
    SendMessage(htime, BM_SETCHECK, cfg.no_time_limit, 0);
    SendMessage(hquick, BM_SETCHECK, cfg.quick_magic, 0);
    SendMessage(hbest, BM_SETCHECK, cfg.high_score, 0);
    SendMessage(hresume, BM_SETCHECK, cfg.resume, 0);
}

static void from_controls(void) {
    char b[MAX_PATH];
    cfg.scale = (int)SendMessage(hscale, CB_GETCURSEL, 0, 0) + 1;
    cfg.fullscreen = (int)SendMessage(hfull, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.integer_scale = (int)SendMessage(hint, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.palette = (int)SendMessage(hpal, CB_GETCURSEL, 0, 0);
    cfg.widescreen = (int)SendMessage(hwide, TBM_GETPOS, 0, 0);
    cfg.no_sprite_limit = (int)SendMessage(hspr, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.volume = (int)SendMessage(hvol, TBM_GETPOS, 0, 0);
    cfg.mute = (int)SendMessage(hmute, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.speed = (int)SendMessage(hspeed, TBM_GETPOS, 0, 0);
    cfg.infinite_lives = (int)SendMessage(hinf, BM_GETCHECK, 0, 0) == BST_CHECKED;
    GetWindowTextA(hlives, b, sizeof b);
    cfg.start_lives = clampi(atoi(b), 1, 99);
    cfg.start_round = (int)SendMessage(hround, CB_GETCURSEL, 0, 0);
    GetWindowTextA(htex, cfg.texture_pack, MAX_PATH);
    GetWindowTextA(hpack, cfg.level_pack, MAX_PATH);
    cfg.all_cards = (int)SendMessage(hcards, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.infinite_magic = (int)SendMessage(hmagic, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.no_time_limit = (int)SendMessage(htime, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.quick_magic = (int)SendMessage(hquick, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.high_score = (int)SendMessage(hbest, BM_GETCHECK, 0, 0) == BST_CHECKED;
    cfg.resume = (int)SendMessage(hresume, BM_GETCHECK, 0, 0) == BST_CHECKED;
}

static HWND mk(const char *cls, const char *text, DWORD style, int x, int y, int w, int h, int id) {
    HWND c = CreateWindowExA(0, cls, text, WS_CHILD | WS_VISIBLE | style, x, y, w, h, wnd, (HMENU)(INT_PTR)id, GetModuleHandle(0), 0);
    SendMessage(c, WM_SETFONT, (WPARAM)font, TRUE);
    return c;
}
static HWND label(const char *t, int x, int y, int w) { return mk("STATIC", t, 0, x, y, w, 18, 0); }
static HWND group(const char *t, int x, int y, int w, int h) { return mk("BUTTON", t, BS_GROUPBOX, x, y, w, h, 0); }
static HWND slider(int x, int y, int w, int lo, int hi, int id) {
    HWND c = mk(TRACKBAR_CLASSA, "", TBS_HORZ | TBS_NOTICKS, x, y, w, 26, id);
    SendMessage(c, TBM_SETRANGE, TRUE, MAKELONG(lo, hi));
    return c;
}

static void play(void) {
    char exe[MAX_PATH];
    snprintf(exe, sizeof exe, "%sgame_win.exe", exe_dir);
    if ((INT_PTR)ShellExecuteA(wnd, "open", exe, 0, exe_dir, SW_SHOWNORMAL) <= 32)
        MessageBoxA(wnd, "game_win.exe was not found next to this program.", "Painter Momopie settings", MB_ICONERROR);
}

static int CALLBACK browse_cb(HWND h, UINT m, LPARAM l, LPARAM d) { (void)l; if (m == BFFM_INITIALIZED && d) SendMessage(h, BFFM_SETSELECTIONA, TRUE, d); return 0; }

static void browse(void) {
    char cur[MAX_PATH], out[MAX_PATH];
    GetWindowTextA(htex, cur, sizeof cur);
    BROWSEINFOA bi = {0};
    bi.hwndOwner = wnd; bi.pszDisplayName = out; bi.lpszTitle = "Choose the texture pack folder (PNG sheets named like textures/2_4000_SpriteTiles.png)";
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE; bi.lpfn = browse_cb; bi.lParam = (LPARAM)cur;
    LPITEMIDLIST id = SHBrowseForFolderA(&bi);
    if (id) { if (SHGetPathFromIDListA(id, out)) SetWindowTextA(htex, out); CoTaskMemFree(id); }
}

static void browse_pack(void) {
    char file[MAX_PATH] = "";
    OPENFILENAMEA o = {sizeof o};
    o.hwndOwner = wnd; o.lpstrFilter = "Level packs (*.pmpack)\0*.pmpack\0All files\0*.*\0"; o.lpstrFile = file; o.nMaxFile = MAX_PATH;
    o.lpstrTitle = "Choose a level pack"; o.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    if (GetOpenFileNameA(&o)) SetWindowTextA(hpack, file);
}

static void open_folder(void) {
    char dir[MAX_PATH];
    GetWindowTextA(htex, dir, sizeof dir);
    char full[MAX_PATH];
    if (dir[0] && dir[1] != ':' && dir[0] != '\\' && dir[0] != '/') snprintf(full, sizeof full, "%s%s", exe_dir, dir); else snprintf(full, sizeof full, "%s", dir);
    CreateDirectoryA(full, 0);
    ShellExecuteA(wnd, "open", full, 0, 0, SW_SHOWNORMAL);
}

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
    case WM_HSCROLL: {
        char b[32];
        snprintf(b, sizeof b, "%d px", (int)SendMessage(hwide, TBM_GETPOS, 0, 0)); SetWindowTextA(hwide_l, b);
        snprintf(b, sizeof b, "%d%%", (int)SendMessage(hvol, TBM_GETPOS, 0, 0)); SetWindowTextA(hvol_l, b);
        snprintf(b, sizeof b, "%d%%", (int)SendMessage(hspeed, TBM_GETPOS, 0, 0)); SetWindowTextA(hspeed_l, b);
        return 0;
    }
    case WM_COMMAND:
        switch (LOWORD(w)) {
        case ID_SAVE: from_controls(); if (save()) MessageBoxA(h, "Saved painter_momopie.ini.", "Painter Momopie settings", MB_ICONINFORMATION); break;
        case ID_PLAY: from_controls(); if (save()) { play(); PostQuitMessage(0); } break;
        case ID_RESET: cfg = defaults; to_controls(); break;
        case ID_BROWSE: browse(); break;
        case ID_PACKBR: browse_pack(); break;
        case ID_OPEN: open_folder(); break;
        case ID_EDITOR: {                                   /* the level editor program next to this one */
            char exe[MAX_PATH];
            snprintf(exe, sizeof exe, "%s\\level_editor.exe", exe_dir);
            if (GetFileAttributesA(exe) == INVALID_FILE_ATTRIBUTES) MessageBoxA(wnd, "level_editor.exe was not found next to this program.", "Painter Momopie", MB_OK);
            else ShellExecuteA(wnd, "open", exe, 0, exe_dir, SW_SHOWNORMAL);
            break;
        }
        case ID_CLOSE: PostQuitMessage(0); break;
        }
        return 0;
    case WM_CLOSE: PostQuitMessage(0); return 0;
    case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProc(h, m, w, l);
}

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show) {
    (void)prev; (void)cmd;
    GetModuleFileNameA(0, exe_dir, MAX_PATH);
    char *slash = strrchr(exe_dir, 92);
    if (slash) slash[1] = 0; else exe_dir[0] = 0;
    snprintf(ini_path, sizeof ini_path, "%spainter_momopie.ini", exe_dir);
    INITCOMMONCONTROLSEX ic = {sizeof ic, ICC_BAR_CLASSES};
    InitCommonControlsEx(&ic);
    CoInitialize(0);
    font = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = proc; wc.hInstance = inst; wc.lpszClassName = "pmcfg"; wc.hCursor = LoadCursor(0, IDC_ARROW); wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    RegisterClassA(&wc);
    RECT rc = {0, 0, 540, 592};
    AdjustWindowRect(&rc, WS_CAPTION | WS_SYSMENU, 0);
    wnd = CreateWindowA("pmcfg", "Painter Momopie settings", WS_CAPTION | WS_SYSMENU | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, rc.right - rc.left, rc.bottom - rc.top, 0, 0, inst, 0);

    group("Display", 10, 6, 520, 150);
    label("Window size", 24, 28, 90);
    hscale = mk("COMBOBOX", "", CBS_DROPDOWNLIST | WS_VSCROLL, 120, 24, 80, 200, ID_SCALE);
    for (int i = 1; i <= 8; i++) { char b[16]; snprintf(b, sizeof b, "%dx", i); SendMessageA(hscale, CB_ADDSTRING, 0, (LPARAM)b); }
    label("Colours", 230, 28, 50);
    hpal = mk("COMBOBOX", "", CBS_DROPDOWNLIST | WS_VSCROLL, 285, 24, 230, 200, ID_PAL);
    SendMessageA(hpal, CB_ADDSTRING, 0, (LPARAM)"Game Boy green"); SendMessageA(hpal, CB_ADDSTRING, 0, (LPARAM)"Grey"); SendMessageA(hpal, CB_ADDSTRING, 0, (LPARAM)"Sepia"); SendMessageA(hpal, CB_ADDSTRING, 0, (LPARAM)"Blue and yellow"); SendMessageA(hpal, CB_ADDSTRING, 0, (LPARAM)"Custom (palette_colors in the ini)");
    hfull = mk("BUTTON", "Start in full screen", BS_AUTOCHECKBOX, 24, 54, 170, 20, ID_FULL);
    hint = mk("BUTTON", "Sharp pixels (whole-number scaling)", BS_AUTOCHECKBOX, 230, 54, 285, 20, ID_INT);
    label("Widescreen", 24, 84, 90);
    hwide = slider(116, 80, 330, 0, 40, ID_WIDE);
    hwide_l = label("0 px", 454, 84, 60);
    label("extra room shown on each side of the play screen (0 = original)", 116, 106, 400);
    hspr = mk("BUTTON", "No sprite limit (no flicker with many objects)", BS_AUTOCHECKBOX, 24, 128, 470, 20, ID_SPR);

    group("Sound", 10, 162, 520, 74);
    label("Volume", 24, 186, 90);
    hvol = slider(116, 182, 330, 0, 100, ID_VOL);
    hvol_l = label("100%", 454, 186, 60);
    hmute = mk("BUTTON", "Mute", BS_AUTOCHECKBOX, 24, 210, 120, 20, ID_MUTE);

    group("Game", 10, 242, 520, 234);
    label("Speed", 24, 266, 90);
    hspeed = slider(116, 262, 330, 50, 400, ID_SPEED);
    hspeed_l = label("100%", 454, 266, 60);
    label("(other than 100% plays without sound)", 116, 288, 400);
    hinf = mk("BUTTON", "Infinite lives", BS_AUTOCHECKBOX, 24, 312, 170, 20, ID_INF);
    label("Starting lives", 260, 314, 90);
    hlives = mk("EDIT", "3", WS_BORDER | ES_NUMBER, 360, 310, 50, 22, ID_LIVES);
    label("Start in round", 24, 346, 90);
    hround = mk("COMBOBOX", "", CBS_DROPDOWNLIST | WS_VSCROLL, 120, 342, 160, 300, ID_ROUND);
    SendMessageA(hround, CB_ADDSTRING, 0, (LPARAM)"Round 1 (normal)");
    for (int i = 1; i <= 33; i++) { char b[24]; snprintf(b, sizeof b, "Round %d", i); SendMessageA(hround, CB_ADDSTRING, 0, (LPARAM)b); }

    hcards = mk("BUTTON", "All magic cards", BS_AUTOCHECKBOX, 24, 374, 150, 20, ID_CARDS);
    hmagic = mk("BUTTON", "Infinite magic", BS_AUTOCHECKBOX, 180, 374, 150, 20, ID_MAGIC);
    htime = mk("BUTTON", "No time limit", BS_AUTOCHECKBOX, 340, 374, 160, 20, ID_TIME);
    hquick = mk("BUTTON", "Quick magic: Q / E (gamepad L1 / R1) cycle the card during play, no magic screen", BS_AUTOCHECKBOX, 24, 392, 490, 18, ID_QUICK);
    hbest = mk("BUTTON", "Best score on the title", BS_AUTOCHECKBOX, 24, 410, 210, 18, ID_BEST);
    hresume = mk("BUTTON", "Resume (hold B for new)", BS_AUTOCHECKBOX, 250, 410, 260, 18, ID_RESUME);
    label("Level pack", 24, 432, 70);
    hpack = mk("EDIT", "", WS_BORDER | ES_AUTOHSCROLL, 100, 428, 342, 22, ID_PACK);
    mk("BUTTON", "Browse...", BS_PUSHBUTTON, 448, 427, 66, 24, ID_PACKBR);
    label("(empty = the game's own 33 rounds)", 100, 454, 230);
    mk("BUTTON", "Level editor...", BS_PUSHBUTTON, 394, 449, 120, 24, ID_EDITOR);

    group("Textures (full-colour sprite replacements)", 10, 482, 520, 56);
    label("Folder", 24, 508, 50);
    htex = mk("EDIT", "textures", WS_BORDER | ES_AUTOHSCROLL, 74, 504, 310, 22, ID_TEX);
    hbrowse = mk("BUTTON", "Browse...", BS_PUSHBUTTON, 390, 503, 66, 24, ID_BROWSE);
    hopen = mk("BUTTON", "Open", BS_PUSHBUTTON, 460, 503, 54, 24, ID_OPEN);

    mk("BUTTON", "Save", BS_PUSHBUTTON, 160, 552, 100, 26, ID_SAVE);
    mk("BUTTON", "Save and play", BS_DEFPUSHBUTTON, 266, 552, 120, 26, ID_PLAY);
    mk("BUTTON", "Defaults", BS_PUSHBUTTON, 24, 552, 80, 26, ID_RESET);
    mk("BUTTON", "Close", BS_PUSHBUTTON, 414, 552, 100, 26, ID_CLOSE);
    load();
    to_controls();
    MSG msg;
    while (GetMessage(&msg, 0, 0, 0) > 0) {
        if (!IsDialogMessage(wnd, &msg)) { TranslateMessage(&msg); DispatchMessage(&msg); }
    }
    return 0;
}

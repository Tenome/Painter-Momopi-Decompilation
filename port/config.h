/* Options of the native player, read from painter_momopie.ini (next to the program or in the current folder). See docs/CONFIG.md. */
#ifndef GB_CONFIG_H
#include <stdint.h>
#define GB_CONFIG_H
typedef struct {
    int scale;              /* window size in multiples of the picture; 0 = 4 */
    int fullscreen;         /* start in full screen */
    int palette;            /* 0 green, 1 grey, 2 sepia, 3 blue and yellow (easy to tell apart for colour blind players), 4 the palette_colors of the ini */
    int widescreen;         /* extra pixels of the room shown on each side of the play screen (0-40; 0 = the original 160 pixel view) */
    int no_sprite_limit;    /* draw every sprite: no 40 sprite OAM limit, so no flicker when many things are on screen */
    int volume;             /* 0-100 */
    int mute;
    int integer_scale;      /* 1 = only whole number scales (sharp pixels), 0 = fill the window keeping the aspect ratio */
    int speed;              /* percent of the original speed (50-400); above 100 the sound is skipped */
    int infinite_lives;     /* cheat option: lives never decrease */
    char level_pack[260];   /* a .pmpack level pack (empty = the game's own 33 rounds; see docs/LEVELS.md) */
    char texture_pack[260]; /* folder of full-colour PNG sheets (empty = none; see docs/TEXTURES.md) */
    int start_lives;        /* 0 = 3 */
    int all_cards;          /* all nine magic cards from the first round */
    int infinite_magic;     /* casting costs no magic points */
    int no_time_limit;      /* the round clock stops (no time-up enemy) */
    int quick_magic;        /* Q / E (gamepad shoulder buttons) cycle the selected magic card during play: no trip to the magic screen */
    char keys[10][48];      /* key names for right, left, up, down, A, B, Select, Start, previous card, next card (comma separated lists) */
    unsigned pad[6];        /* gamepad button masks (bit n-1 = button n) for A, B, Select, Start, previous card, next card */
    int filter;             /* 0 = none, 1 = scanlines, 2 = LCD grid (the Windows player) */
    int pause_on_focus_loss; /* the game pauses when its window loses the focus (P resumes) */
    int high_score;         /* the best score is kept in painter_momopie.sav and shown on the title screen */
    int resume;             /* the title screen's 1 PLAYER continues at the last round reached (hold SELECT for a new game) */
    int start_round;        /* 0 = the title screen's choice; 1-33 starts at that round */
    char palette_colors[40]; /* four RRGGBB values, lightest first, separated by commas or spaces (palette 4) */
    char music_folder[600]; /* folder with song_81.mml ... song_8b.mml: music texts that replace the game's own songs (docs/MUSIC.md); empty = the original music */
} GbConfig;
extern GbConfig gb_config;
extern uint32_t gb_palettes[5][4];     /* 0x00RRGGBB of the four Game Boy shades (lightest first) of every palette; slot 4 comes from palette_colors */
extern int gb_palette_count;           /* 4, or 5 when palette_colors is set: F2 cycles through them */
void gb_config_load(const char *path);     /* missing file or key: the default; applies the options that live in the runtime */
#endif

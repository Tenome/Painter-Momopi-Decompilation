/* Optional progress file (painter_momopie.sav next to the ini): the best score ("high_score" option) and the state at the start of the last round ("resume" option).
 * The original game has neither; both options are off by default. */
#ifndef GB_SAVE_H
#define GB_SAVE_H
#include <stdint.h>
#define GB_RESUME_BYTES 20
typedef struct {
    unsigned best_score, best_round;
    int has_resume;
    uint8_t resume[GB_RESUME_BYTES];        /* wRound, wRoundBackup, wRoomIndex, $c47b, $c1a8, wLives, score x3, wExtraLifeIdx, wMagicCards x9, wContinues */
} GbSave;
extern GbSave gb_save;
void gb_save_init(const char *ini_path);    /* the progress file is the ini's path with .sav; reads it when it exists */
void gb_save_write(void);                   /* does nothing without gb_save_init */
#endif

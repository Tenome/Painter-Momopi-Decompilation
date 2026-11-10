/* Recording and playback of inputs (.pmrec text files). The game is deterministic, so the buttons of every frame (and the quick magic presses) plus the
 * gameplay options and the level pack are all a replay needs. */
#ifndef GB_REPLAY_H
#define GB_REPLAY_H
int gb_replay_play(const char *path);       /* before the game starts: reads the file, applies its options and loads its level pack; 1 on success */
int gb_replay_record(const char *path);     /* after the options and the pack are set: starts writing the file; 1 on success */
void gb_replay_tick(unsigned frame);        /* every frame, after the front end has read its keys: records them or replaces them with the replayed ones */
extern int gb_replay_active;                /* 1 while playing a replay */
extern int gb_replay_finished;              /* 1 once the last recorded frame has passed */
#endif

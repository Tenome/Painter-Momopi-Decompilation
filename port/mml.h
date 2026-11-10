#ifndef GB_MML_H
#define GB_MML_H
#include <stdint.h>
/* Compiles a music text file (docs/MUSIC.md) to a song region for the base address $a000. Returns the size, or -1 with a message in err. */
int gb_mml_compile(const char *path, uint8_t *out, int cap, char *err, int errn);
#endif

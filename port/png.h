#ifndef GB_PNG_H
#define GB_PNG_H
#include <stdint.h>
typedef struct { int w, h; uint8_t *rgba; } PngImage;     /* rgba: w * h * 4 bytes (R, G, B, A) */
int png_load(const char *path, PngImage *img);            /* 0 on success */
void png_free(PngImage *img);
#endif

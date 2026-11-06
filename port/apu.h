#ifndef APU_H
#define APU_H
#include <stdint.h>
#define APU_RATE 44100
void apu_reset(void);
void apu_write(uint16_t addr, uint8_t v);   /* NR10-NR52 and wave RAM $ff30-$ff3f */
uint8_t apu_read(uint16_t addr, uint8_t stored);
void apu_mix(int16_t *stereo, int frames);  /* write `frames` stereo samples */
#endif

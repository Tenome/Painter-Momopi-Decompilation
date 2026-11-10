#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <direct.h>
#define MKDIR(p) _mkdir(p)
#else
#define MKDIR(p) mkdir(p, 0755)
#endif
#include "zip.h"
#include "png.h"

static unsigned u16(const uint8_t *p) { return p[0] | p[1] << 8; }
static unsigned long u32(const uint8_t *p) { return (unsigned long)p[0] | (unsigned long)p[1] << 8 | (unsigned long)p[2] << 16 | (unsigned long)p[3] << 24; }

static void make_dirs(char *path) {                      /* every folder of the path (the file name is cut at the last slash) */
    for (char *p = path + 1; *p; p++) {
        if (*p == '/') { *p = 0; MKDIR(path); *p = '/'; }
    }
}

int gb_zip_unpack(const char *zip_path, char *pack_out, size_t cap) {
    FILE *f = fopen(zip_path, "rb");
    if (!f) { fprintf(stderr, "level pack: cannot open %s\n", zip_path); return 0; }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *z = malloc((size_t)size + 1);
    if (!z || size < 22 || fread(z, 1, (size_t)size, f) != (size_t)size) { fclose(f); free(z); fprintf(stderr, "level pack: cannot read %s\n", zip_path); return 0; }
    fclose(f);
    long eocd = -1;
    for (long i = size - 22; i >= 0 && i > size - 22 - 65536; i--) if (u32(z + i) == 0x06054b50UL) { eocd = i; break; }
    if (eocd < 0) { free(z); fprintf(stderr, "level pack: %s is not a zip file\n", zip_path); return 0; }
    unsigned entries = u16(z + eocd + 10);
    unsigned long cd = u32(z + eocd + 16);
    char dir[1024], marker[1100];
    snprintf(dir, sizeof dir, "%s.unpacked", zip_path);
    for (char *p = dir; *p; p++) if (*p == 92) *p = '/';
    snprintf(marker, sizeof marker, "%s/.unpacked", dir);
    struct stat zs, ms;
    int fresh = stat(zip_path, &zs) == 0 && stat(marker, &ms) == 0 && ms.st_mtime >= zs.st_mtime;
    MKDIR(dir);
    pack_out[0] = 0;
    for (unsigned e = 0; e < entries && cd + 46 <= (unsigned long)size; e++) {
        const uint8_t *c = z + cd;
        if (u32(c) != 0x02014b50UL) break;
        unsigned method = u16(c + 10), nlen = u16(c + 28), xlen = u16(c + 30), clen = u16(c + 32);
        unsigned long csize = u32(c + 20), usize = u32(c + 24), loff = u32(c + 42);
        char name[512];
        if (nlen < sizeof name) { memcpy(name, c + 46, nlen); name[nlen] = 0; } else name[0] = 0;
        cd += 46 + nlen + xlen + clen;
        for (char *p = name; *p; p++) if (*p == 92) *p = '/';
        if (!name[0] || name[nlen - 1] == '/' || name[0] == '/' || strstr(name, "..") || strchr(name, ':')) continue;     /* folders and unsafe names */
        char *ext = strrchr(name, '.');
        if (ext && !strcmp(ext, ".pmpack") && !pack_out[0]) snprintf(pack_out, cap, "%s/%s", dir, name);
        if (fresh) continue;
        if (loff + 30 > (unsigned long)size) continue;
        const uint8_t *l = z + loff;
        unsigned long start = loff + 30 + u16(l + 26) + u16(l + 28);
        if (u32(l) != 0x04034b50UL || start + csize > (unsigned long)size) continue;
        uint8_t *data = 0;
        size_t dlen = 0;
        if (method == 0) { data = malloc(csize + 1); memcpy(data, z + start, csize); dlen = csize; }
        else if (method == 8) { data = gb_inflate(z + start, csize, &dlen); if (!data || dlen != usize) { free(data); fprintf(stderr, "level pack: cannot unpack %s\n", name); continue; } }
        else continue;
        char out[1700];
        snprintf(out, sizeof out, "%s/%s", dir, name);
        make_dirs(out);
        FILE *o = fopen(out, "wb");
        if (o) { fwrite(data, 1, dlen, o); fclose(o); }
        free(data);
    }
    free(z);
    if (!fresh) { FILE *m = fopen(marker, "w"); if (m) { fputs("unpacked", m); fclose(m); } }
    if (!pack_out[0]) { fprintf(stderr, "level pack: no .pmpack file inside %s\n", zip_path); return 0; }
    return 1;
}

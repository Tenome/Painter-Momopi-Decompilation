/* Reading level packs from a .zip file: the archive is unpacked into a folder next to it (<name>.unpacked) and the pack file inside is used from there. */
#ifndef GB_ZIP_H
#define GB_ZIP_H
#include <stddef.h>
/* Unpacks zip_path into <zip_path>.unpacked/ (skipped when that folder is newer than the zip). The path of the first .pmpack file inside is written to
 * pack_out. Returns 1 on success, 0 on error (a message goes to stderr). */
int gb_zip_unpack(const char *zip_path, char *pack_out, size_t cap);
#endif

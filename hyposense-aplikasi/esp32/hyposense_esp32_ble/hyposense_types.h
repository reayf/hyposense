#ifndef HYPOSENSE_TYPES_H
#define HYPOSENSE_TYPES_H

// Data satu pembacaan untuk penyangga lokal (ring buffer) saat HP
// terputus. Didefinisikan DI HEADER dengan sengaja: kalau ditulis
// inline di .ino, Arduino menyisipkan prototipe fungsi otomatis
// (mis. `Buffered snapshot();`) SEBELUM definisi struct -> muncul
// error "'Buffered' does not name a type". Lewat header, tipe ini
// sudah dikenal sebelum prototipe disisipkan.
struct Buffered {
  int   hr;
  float prv;
  int   voc;
  float t;
  float h;
  long  ts;
};

#endif

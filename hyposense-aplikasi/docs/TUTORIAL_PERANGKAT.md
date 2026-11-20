# Tutorial: Menyambungkan Gelang HypoSense ke Aplikasi

Panduan langkah demi langkah dari perangkat mati total sampai data sensor
muncul realtime di aplikasi web — untuk anggota tim yang baru pertama kali
memegang perangkatnya.

**Arsitektur singkat** (supaya paham apa yang sedang disambungkan):

```
Gelang (ESP32 + sensor)  --WiFi/HTTPS-->  Supabase (database cloud)
                                              |
                                              v  (realtime)
                                 Aplikasi web hyposense-app.vercel.app
```

Gelang TIDAK terhubung langsung ke HP (tidak ada Bluetooth/pairing).
Gelang mengirim data ke cloud; aplikasi membaca dari cloud. "Menautkan
perangkat" artinya memberi tahu cloud bahwa `device_id` tertentu milik
akun pasien tertentu.

---

## Bagian A — Persiapan Software di Laptop (sekali saja)

1. **Install Arduino IDE** (versi 2.x): https://www.arduino.cc/en/software
2. **Tambahkan board ESP32**: File → Preferences → *Additional boards
   manager URLs* → isi:
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   Lalu Tools → Board → Boards Manager → cari **esp32** (by Espressif) → Install.
3. **Install 3 library** (Tools → Manage Libraries):
   - **SparkFun MAX3010x Pulse and Proximity Sensor Library**
   - **Adafruit SHT31 Library** (setujui dependensi Adafruit BusIO)
   - **Adafruit SSD1306** (setujui dependensi Adafruit GFX)

## Bagian B — Pin PCB (perangkat sudah dirakit di PCB tim)

Board: **Seeed XIAO ESP32C3**, terpasang di PCB custom. Pin yang
dipakai firmware (sudah sesuai PCB — jangan diubah tanpa cek jalur):

| Fungsi | Pin ESP32C3 |
|---|---|
| I2C SDA (MAX30105 + SHT31 + OLED, paralel) | **GPIO8** |
| I2C SCL (MAX30105 + SHT31 + OLED, paralel) | **GPIO9** |
| Gate MOSFET — pemanas MQ-138 (nyala hanya saat verifikasi) | **GPIO4** |
| Output analog MQ-138 (ADC) | **GPIO3** |
| Voltage divider baterai (ADC, kalibrasi map 1900–2600) | **GPIO1** |

Alamat I2C: MAX30105 = 0x57, SHT31 = 0x44, OLED = 0x3C.

> Catatan desain: heater MQ-138 dikendalikan MOSFET dan **hanya
> dinyalakan 60 detik sebelum verifikasi napas** — hemat baterai,
> konsekuensinya perlu waktu pemanasan setiap kali verifikasi.

## Bagian C — Konfigurasi & Upload Firmware

1. Buka `esp32/hyposense_esp32/hyposense_esp32.ino` di Arduino IDE.
2. Edit blok **KONFIGURASI** di bagian atas file:
   ```cpp
   #define WIFI_SSID  "NamaWiFiKamu"      // WAJIB diisi
   #define WIFI_PASS  "PasswordWiFiKamu"  // WAJIB diisi
   #define DEVICE_ID  "gelang_001"        // unik per gelang!
   ```
   `SUPABASE_URL` dan `SUPABASE_KEY` sudah benar — jangan diubah.
   Jika membuat gelang kedua, ganti `DEVICE_ID` (mis. `gelang_002`).
3. Colok ESP32 ke laptop via USB.
4. Tools → Board → **ESP32 Dev Module** (atau "WEMOS D1 MINI ESP32"
   sesuai modul). Tools → Port → pilih COM yang muncul.
5. Klik **Upload** (→). Tunggu "Done uploading".
6. Buka **Serial Monitor** (Tools → Serial Monitor), set **115200 baud** —
   semua log perangkat terlihat di sini.

## Bagian D — Perilaku Perangkat Saat Menyala

Urutan yang NORMAL terjadi (baca di OLED + Serial Monitor):

1. Boot → OLED **"Konek WiFi..."** (maks ±8 detik; gagal pun lanjut
   mode offline, data diantre).
2. **Layar jam standby** — jam besar (sinkron NTP), indikator baterai
   kanan-atas, status WiFi kiri-atas, dan **BPM** di bawah saat gelang
   menyentuh kulit (`BPM: Memantau...` jika tidak ada kontak).
3. **Setiap 60 detik** perangkat mengirim telemetri ke cloud — lihat
   `[HTTP] POST 201 ...` di Serial Monitor (**201 = sukses**). Inilah
   yang membuat aplikasi menampilkan "Gelang: Terhubung".
4. **Deteksi anomali** (dua jalur): BPM ≥ 100 (takikardia — langsung),
   ATAU menyimpang dari baseline personal dua arah (aktif setelah
   baseline belajar ±10 menit; tersimpan antar-nyala).
5. Saat anomali: **pemanasan sensor gas 60 detik** (MOSFET heater ON)
   → **"BUKA KATUP GESER"** → hembuskan napas ke kabin sensor →
   hasil analisis tampil + terkirim ke cloud dengan `risk_status`.
6. Jika keputusan **positif**: layar alarm berkedip di gelang +
   aplikasi/HP membunyikan alarmnya sendiri (dari data realtime).

## Bagian E — Setup Database (sekali saja, oleh admin)

Di Supabase Dashboard → SQL Editor, pastikan file-file ini sudah pernah
dijalankan (urut, semuanya aman diulang):

1. `supabase/base_schema_setup.sql`
2. `supabase/readings_setup.sql`
3. `supabase/roles_setup.sql`
4. `supabase/account_setup.sql`
5. `supabase/device_setup.sql` ← yang mengaktifkan penautan perangkat

## Bagian F — Menautkan Gelang ke Akun Pasien

1. Login di **https://hyposense-app.vercel.app** dengan akun pasien.
2. Buka tab **Pengaturan** → kartu **Perangkat Gelang**.
3. Masukkan `DEVICE_ID` yang tertulis di firmware (mis. `gelang_001`)
   → tekan **Tautkan perangkat**.
4. Sejak saat itu: semua data dari gelang tersebut (termasuk data yang
   sudah terlanjur terkirim sebelumnya) menjadi milik akun ini, dan
   hanya bisa dilihat oleh pasien sendiri, admin, dan perawat yang
   terhubung (jika pasien mengizinkan berbagi data).

## Bagian G — Verifikasi End-to-End

1. Gelang menyala & tersambung WiFi (OLED `WiFi:OK`).
2. Buka aplikasi sebagai pasien → tab Beranda:
   - **"Gelang: Terhubung"** muncul jika ada data < 2 menit terakhir.
   - Kartu **Data Sensor Langsung** menampilkan HR/VOC/suhu/RH dan
     ter-update sendiri tiap ±60 detik tanpa refresh.
3. Login sebagai perawat yang terhubung → buka pasien tsb → kartu data
   live menampilkan angka yang sama.
4. **Uji alur alarm penuh** (HR anomali → minta napas → keputusan):
   - *Cara perangkat (mudah untuk demo)*: pakai gelang, lakukan
     aktivitas ringan (naik-turun tangga / lompat) sampai **BPM ≥ 100**
     → perangkat masuk pemanasan 60 dtk → buka katup → hembuskan
     napas → amati keputusan di OLED & Serial. Catatan: verifikasi
     NAPAS PERTAMA selalu "negatif" (dipakai sebagai baseline napas
     personal); pengulangan berikutnya baru bisa positif.
   - *Cara data* (uji sisi aplikasi saja): insert baris `positif` via
     SQL Editor → alarm merah muncul di aplikasi < 1 detik.
5. Kejadian alarm tercatat otomatis di **Riwayat Risiko** pasien
   (dilihat perawat, dikelompokkan per hari).

## Bagian H — Troubleshooting

| Gejala | Kemungkinan penyebab & solusi |
|---|---|
| OLED blank / Serial "OLED Gagal Terhubung!" | Jalur I2C (GPIO8/9) bermasalah atau alamat bukan 0x3C |
| Serial "SHT31 Belum terdeteksi" | Solderan/jalur SHT31 — suhu & kelembapan akan 0 sampai dibereskan |
| BPM selalu 0 padahal dipakai | Kontak sensor kurang rapat; IR harus > 3000 (cek dgn print) |
| OLED `----` di kiri atas (WiFi) terus | SSID/password salah; WiFi harus **2.4GHz** (C3 tidak bisa 5GHz); perangkat tetap jalan offline dan mengantre data |
| Serial `[HTTP] POST -1` | WiFi putus saat kirim — perangkat otomatis antre & kirim ulang (buffer 8 data) |
| Serial `[HTTP] POST 401/403` | SUPABASE_KEY salah/terhapus di firmware |
| Serial `[HTTP] POST 404` | Tabel `readings` belum dibuat — jalankan `readings_setup.sql` |
| Data terkirim (201) tapi tidak muncul di app | Perangkat sudah ditautkan ke AKUN LAIN (RLS menyembunyikannya). Lepas tautan dari akun lama dulu |
| "Perangkat ini sudah tertaut ke akun lain" saat menautkan | `device_id` diklaim akun lain — lepaskan dari akun itu, atau admin hapus barisnya di tabel `devices` |
| BPM 0 / kacau | Gelang kurang rapat ke kulit; pastikan diam ±10 detik; LED sensor harus menempel kulit |
| Nilai VOC aneh/loncat | MQ-138 belum cukup panas (tunggu warmup), atau kelembapan berubah drastis (napas baru saja mengenai sensor) |
| Suara alarm tidak bunyi di HP | Browser memblokir audio sebelum interaksi — tap layar sekali dulu; pastikan bukan silent mode |

## Batasan yang Perlu Diketahui (jujur, untuk laporan)

- Keputusan risiko di firmware masih **aturan-ambang sederhana**
  (placeholder TinyML — lihat `decideRisk()` di .ino).
- Kompensasi suhu/kelembapan MQ-138 memakai koefisien kasar; perlu
  kalibrasi dengan data primer.
- TLS memakai `setInsecure()` (tanpa verifikasi sertifikat) — cukup
  untuk prototipe, perlu root CA untuk produksi.
- Tanpa buzzer/getar di gelang, peringatan saat tidur bergantung pada
  alarm HP — batasan desain yang sudah diakui di dokumen proyek.

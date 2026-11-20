# HypoSense

Sistem wearable non-invasif dan aplikasi pendamping uji klinik untuk deteksi dini risiko hipoglikemia menggunakan fusi sinyal fisiologis **PPG (Heart Rate & Pulse Rate Variability / PRV)** dan **VOC aseton napas + suhu/kelembapan (MQ-138 & SHT31)** (*PKM-KC, Institut Teknologi Sepuluh Nopember*).

> **Catatan Data & Keamanan:** Seluruh dataset sekunder (HUPA-UCM, PhysioCGM, BIG IDEAs), data rekaman uji klinik RSUA (`.csv`), dokumen laporan (`.pdf`/`.docx`/`.pptx`), serta kredensial lokal (`.env`/WiFi/key) sengaja tidak disertakan di repositori ini.

## Arsitektur Sistem

```text
[Gelang ESP32-C3 (HypoSense-001)]
  ├── MAX30102 / MAX30105  ──► HR, IBI mentah, PRV (RMSSD)  ──► Lapisan 1: Logistic Regression
  └── MQ-138 + SHT31       ──► VOC napas + suhu/kelembapan  ──► Lapisan 2: Pruned Random Forest
        │
        ▼ (BLE GATT / Telemetri)
[Aplikasi Mobile Flutter (`hyposense-aplikasi/`)]
  ├── Pemantauan real-time & kalibrasi patokan personal (`CALNAPAS`, `RESETBASE`)
  └── Mode Uji Klinik (perekaman terstruktur + glukosa referensi -> Supabase)
```

## Struktur Repositori

- `hyposense-aplikasi/` — Aplikasi mobile **Flutter** + firmware **ESP32-C3** (`esp32/hyposense_esp32_ble/` untuk BLE GATT + TinyML on-device, dan `esp32/hyposense_esp32/` untuk mode WiFi/REST).
- `ml_fix_pipeline/` — Pipeline *TinyML* dari EDA hingga ekspor parameter C++ ESP32 (`00_Master_Pipeline_Lengkap_HypoSense.ipynb` s.d. `04_Modeling_Optimasi_dan_Evaluasi_TinyML.ipynb`).
- `analysis/` — Skrip & notebook validasi pipeline PRV dan fitur fisiologis (`validate_hupa.py`, `compute_prv_bigideas.py`, `EDA_*.ipynb`).
- `clinical_trial_setup.sql` — Skema SQL tabel uji klinik pada Supabase.
- `METODOLOGI_ML.md`, `LapKem Software.md`, `LapKem Hasil Model.md`, `GLOSARIUM.md` — Dokumentasi metodologi, arsitektur software, dan evaluasi model.

## Konfigurasi Kredensial

Sebelum menjalankan aplikasi Flutter atau meng-upload firmware ESP32:

1. **Flutter (`hyposense-aplikasi/`):** Jalankan dengan `--dart-define` atau isi konfigurasi Supabase di `lib/config/supabase_config.dart`:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key
   ```
2. **Firmware ESP32:** Isi kredensial WiFi / BLE device ID milikmu di file `.ino` sebelum flash (jangan commit kredensial ke Git).
3. **Database:** Jalankan `clinical_trial_setup.sql` di Supabase SQL Editor untuk membuat skema tabel uji klinik.

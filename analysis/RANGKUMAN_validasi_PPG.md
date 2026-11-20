# Rangkuman — Validasi Metode Deteksi (Brief PPG/HR-PRV)

*Dokumen ringkas hasil kerja terakhir. Bisa dipakai sebagai bahan laporan PKM.*

---



## 1. Konteks

Brief terakhir ("Rencana Pengembangan PPG & Deteksi") fokus pada **algoritma deteksi hipoglikemia di firmware** (bukan aplikasi). Tujuannya: pastikan metode deteksi (HR/PRV + baseline personal + persistensi) benar-benar berfungsi, dan **divalidasi pada data berlabel** sebelum dipercaya/di-flash.

Karena hardware sedang tidak ada, dipilih pekerjaan yang **bisa diverifikasi tanpa alat**: validasi metode di Python (Tahap 4 dari brief).

## 2. Keputusan yang diambil


| Hal                             | Keputusan                                                                                                   | Alasan                                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Pemicu alarm                    | **HR-persistensi cukup; VOC opsional**                                                                      | Pengguna tidur kecil kemungkinan meniup sensor; aseton turun (lemah) saat hipo insulin; HR/PRV dasar ilmiah lebih kuat |
| Konflik dengan kerja sebelumnya | **Tidak ada** untuk aplikasi (T0-T5 aman). Hanya blok deteksi firmware yang di-upgrade (memang placeholder) | —                                                                                                                      |
| Machine learning                | **Ditunda** sampai ada data primer                                                                          | Tak ada dataset yang cocok dengan sensor MAX30105                                                                      |




## 3. Nilai numerik yang diusulkan (tentatif, perlu kalibrasi)


| Parameter         | Usulan                           | Catatan                                                                     |
| ----------------- | -------------------------------- | --------------------------------------------------------------------------- |
| Sampling MAX30105 | 100 → **200-400 Hz**             | 100Hz = IBI kuantisasi 10ms, kasar untuk PRV; atau pakai interpolasi puncak |
| Ambang skor-z     | **~2,5-3**                       | tebakan, wajib dikalibrasi dengan hipo nyata                                |
| Persistensi       | **~3 menit**                     | firmware sekarang cuma 15 detik (terlalu pendek)                            |
| Masa belajar      | kriteria konvergensi (~2-3 hari) | pisah baseline siang & malam                                                |
| Jendela PRV       | **2-3 menit**                    | PRV optik rentan galat → condong lebih panjang                              |




## 4. Yang dikerjakan: validasi HUPA-UCM

- **Dataset:** HUPA-UCM (Mendeley) — 25 pasien T1D, data 5-menit: glukosa (CGM) + detak jantung (Fitbit) + langkah/kalori/tidur, ≥14 hari.
- **Pipeline:** `analysis/validate_hupa.py` — meniru logika firmware secara **online/kausal**:
  1. Labeli hipoglikemia = glukosa < 70 mg/dL (ADA 2023)
  2. Baseline HR personal (EMA) **terpisah siang/malam**
  3. Anomali skor-z **dua arah** (naik ATAU turun) + **persistensi**
  4. Evaluasi per-pasien (302.192 sampel, 6,4% hipo)



## 5. HASIL — temuan utama

**Metode berbasis HR-rata-rata saja LEMAH untuk deteksi hipoglikemia:**


| Kondisi | Sensitivitas | Spesifisitas | Presisi |
| ------- | ------------ | ------------ | ------- |
| Semua   | 27,5%        | 69,2%        | 5,8%    |
| Siang   | 29,1%        | 71,5%        | 6,0%    |
| Malam   | 24,9%        | 64,5%        | 5,4%    |


Sweep ambang Z (malam): Z=2,0 → sens 37%/spes 47%; Z=3,0 → sens 16%/spes 74%. **Tradeoff buruk di semua titik.** Target brief ≥80% sensitivitas — jauh.

**Presisi ~6% ≈ prevalensi hipo (6,4%)** → anomali HR **tidak lebih sering** muncul saat hipo dibanding acak. Artinya masalahnya di **sinyalnya**, bukan pemilihan ambang.

### 5b. Activity-gating (langkah lanjutan yang diuji)

Ditambahkan penekanan alarm saat aktif (langkah ≥ 20 per 5-mnt):


| Skema                        | Sensitivitas | Spesifisitas | Presisi |
| ---------------------------- | ------------ | ------------ | ------- |
| Tanpa gating                 | 27,5%        | 69,2%        | 5,8%    |
| Gated (alarm saat istirahat) | 20,8%        | **77,8%**    | 6,1%    |
| Malam + istirahat            | 22,8%        | 67,2%        | 5,5%    |


**Activity-gating menaikkan spesifisitas (69% → 78%)** tapi **presisi tetap ~6% ≈ prevalensi** di semua skema. Kesimpulan: kelemahannya **bukan noise aktivitas, melainkan sinyal HR rata-rata itu sendiri** yang tidak informatif untuk hipoglikemia — bahkan saat istirahat/malam.

### 5c. Ekstraksi PRV (BIG IDEAs Lab, langkah positif)

Meski BIG IDEAs tak bisa untuk *deteksi* (hipo cuma 0,66%), file `IBI.csv`-nya dipakai memvalidasi **ekstraksi PRV**. RMSSD per jendela 2-menit, 11 subjek (`compute_prv_bigideas.py`):

- **RMSSD median 51,4 ms, rentang 27,9-67,7 ms** — **wajar** (rujukan RMSSD istirahat dewasa sehat ~20-60 ms).
- HR median 59-81 bpm (masuk akal).

**Kesimpulan:** pipeline pengolahan sinyal PRV **sehat** — menghasilkan angka fisiologis benar dari PPG pergelangan. Yang belum teruji: apakah PRV *membedakan* hipoglikemia (butuh data primer).

## 6. Interpretasi (kenapa lemah — bukan bug)

- HR rata-rata adalah **sinyal lemah** untuk hipoglikemia.
- Studi kuat (Porumb 2020, sensitivitas 87,5%) memakai **ECG + fitur HRV + deep learning**, bukan HR rata-rata.
- Hipoglikemia sering "sunyi" di HR, terutama malam (hypo unawareness umum di T1D; respons otonom tumpul saat tidur).



## 7. Implikasi

**Untuk laporan (kejujuran = nilai plus):**

> Validasi metode baseline-HR pada 25 pasien T1D menghasilkan sensitivitas ~25-37% — menegaskan HR rata-rata saja tidak memadai untuk deteksi hipoglikemia; diperlukan PRV, konteks aktivitas, dan model pembelajaran + data primer.

**Untuk produk:**

- HypoSense = **proof-of-concept**, bukan alat akurat klinis (harus diakui).
- Arsitektur (HR-persistensi + VOC opsional) **tetap benar** — yang terbatas adalah *akurasi deteksinya*.



## 8. Status & langkah berikutnya (belum dipilih)

- **(a)** Perbaiki HR-only: activity-gating (pakai `steps`) + laju-perubahan HR — cepat, lihat "batas atas" metode HR.
- **(b)** Validasi jalur **PRV** pakai BIG IDEAs Lab (PPG mentah + glukosa) — perlu akun PhysioNet.
- **(c)** Terima sebagai temuan PoC jujur, kembali ke firmware/app.



## Referensi kunci

- Porumb dkk. 2020, *Sci Rep* — ECG+deep learning, sens 87,5% — [https://www.nature.com/articles/s41598-019-56927-5](https://www.nature.com/articles/s41598-019-56927-5)
- HUPA-UCM Dataset — [https://data.mendeley.com/datasets/3hbcscwz44/1](https://data.mendeley.com/datasets/3hbcscwz44/1)
- ADA 2023 — hipoglikemia < 70 mg/dL


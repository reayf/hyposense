# Metodologi Pembelajaran Mesin — HypoSense

*Dokumen ini memetakan tiap tahap baku alur kerja pembelajaran mesin ke berkas
tempat tahap itu dikerjakan, beserta kelebihan dan kekurangannya. Seluruh angka
berasal dari pengujian yang benar-benar dijalankan dan dapat ditelusuri ke
berkasnya.*

---

## Ringkasan pemetaan

| Tahap | Dikerjakan di | Status |
|---|---|---|
| 1. Definisi masalah | dokumen ini, §1 | ✅ |
| 2. Pengumpulan data | `analysis/lihat_physiocgm.py`, `check_bigideas.py` | ✅ |
| 3. Telaah data (EDA) | `EDA_dataset.ipynb`, `EDA_voc.ipynb`, `EDA_physiocgm.ipynb` | ✅ |
| 4. Pembersihan data | `features.py`, `ekstrak_physiocgm.py`, `train_hupa.py` | ✅ |
| 5. Rekayasa ciri | `train_hupa.py`, `pipeline_voc.py`, `features.py` | ✅ |
| 6. Pemodelan & validasi | `train_hupa.py`, `uji_prv_physiocgm.py`, `uji_patokan_terpisah.py` | ✅ |
| 7. Representasi model dasar PPG | rencana lanjutan, §7 | ⏳ belum dikerjakan |

---

# 1. Definisi masalah

| Aspek | Ketetapan |
|---|---|
| **Jenis tugas** | **Klasifikasi biner** — bukan regresi, bukan pengelompokan |
| **Keluaran** | Berisiko hipoglikemia / tidak |
| **Label kebenaran** | Glukosa < 70 mg/dL (American Diabetes Association, 2023) |
| **Satuan pengamatan** | Satu jendela pengukuran (5 menit) |
| **Sifat kelas** | **Sangat timpang** — hipoglikemia 2,8–7,2% tergantung dataset |

### Mengapa klasifikasi, bukan regresi

Regresi menuntut model menebak **kadar glukosa** dalam mg/dL. Itu di luar
jangkauan sinyal yang tersedia: sinyal jantung mencerminkan **respons tubuh
terhadap** perubahan glukosa, bukan kadarnya. Yang dibutuhkan pengguna pun
bukan angka, melainkan **keputusan**: perlu memeriksa gula darah atau tidak.

### Metrik keberhasilan — dan mengapa bukan akurasi

| Metrik | Menjawab |
|---|---|
| **Sensitivitas** | Dari semua kejadian hipoglikemia, berapa yang tertangkap? |
| **Spesifisitas** | Dari semua keadaan normal, berapa yang benar dibiarkan? |
| **Presisi** | Dari semua peringatan yang dibunyikan, berapa yang benar? |
| **Lift** | Presisi ÷ prevalensi. Nilai 1,0 berarti setara menebak acak |

**Akurasi sengaja tidak dipakai sebagai metrik utama**, dan alasannya terbukti
pada hasil kami sendiri: model Random Forest memperoleh **akurasi 91,6%**
tetapi **sensitivitas hanya 1,4%** — praktis tidak pernah memberi peringatan.
Model yang senantiasa menjawab "aman" bahkan memperoleh akurasi 92,8%.

Praktik ini sejalan dengan literatur evaluasi model pada data timpang, yang
menyimpulkan bahwa kurva presisi–recall lebih informatif daripada ROC pada
kondisi kelas yang sangat tidak seimbang (Saito & Rehmsmeier, PLOS ONE 2015).

**Kelemahan yang diakui:** ambang keputusan masih memakai nilai bawaan 0,5.
Pada alat kesehatan, ambang seharusnya ditetapkan dari kebutuhan nyata
(misalnya batas jumlah peringatan palsu per malam) melalui kurva
presisi–recall. Ini belum dikerjakan.

---

# 2. Pengumpulan data

| Sumber | Isi | Peran dalam penelitian |
|---|---|---|
| **HUPA-UCM** (Mendeley Data) | 25 pasien tipe 1, 309.392 sampel, CGM + detak Fitbit | Menguji kecukupan detak jantung agregat |
| **BIG IDEAs Lab** (PhysioNet) | 11 subjek, ±2,9 juta jarak antar-detak (Empatica E4) | Memvalidasi kebenaran algoritma PRV kami |
| **PhysioCGM** (figshare, CC0) | 3 pasien tipe 1, PPG pergelangan 64 Hz + CGM | Menguji apakah PRV menandai hipoglikemia |
| **Turner dkk.** (makalah) | Persamaan regresi 7 pasien, studi *insulin clamp* | Parameter pemodelan jalur VOC |
| **Data primer** | Uji klinik bersama mitra tenaga kesehatan | Validasi pada sensor sendiri — **belum terkumpul** |

**Berkas:** `analysis/lihat_physiocgm.py` (pembaca & pemindai PhysioCGM),
`analysis/check_bigideas.py`, `analysis/model/ekstrak_physiocgm.py`

**Kelebihan:** tiap sumber dipilih untuk menjawab pertanyaan yang berbeda,
bukan sekadar mengumpulkan sebanyak mungkin.

**Kekurangan:** tidak satu pun berasal dari sensor yang kami kembangkan.
Seluruh kesimpulan karena itu bersifat **tentang metode**, bukan tentang
akurasi perangkat.

---

# 3. Telaah data (EDA)

**Berkas:** `analysis/EDA_dataset.ipynb` · `EDA_voc.ipynb` · `EDA_physiocgm.ipynb`

Temuan yang menentukan arah pemodelan:

| Temuan | Angka | Akibatnya pada rancangan |
|---|---|---|
| Sebaran detak saat hipoglikemia vs normal **bertumpuk** | selisih **3,2 bpm**, seperlima simpangan bakunya | Detak agregat saja tak memadai |
| Detak normal **berbeda jauh antarpasien** | **62,7–89,8 bpm** (rentang 27,1) | Ambang tunggal mustahil → patokan personal |
| Hipoglikemia lebih sering **malam hari** | 7,70% vs 6,03% | Memperkuat sasaran nokturnal |
| Detak malam berbeda dari siang | 68,7 vs 81,1 bpm | Patokan perlu dipisah siang/malam |
| Kadar aseton **berbeda 21 kali lipat antarorang** | r = 0,134 antar-individu | Patokan personal juga wajib di jalur VOC |
| Sebagian besar jendela PPG **berderau** | hanya 14% lolos saringan ketat | Perlu gerbang mutu sinyal |

**Kelebihan:** telaah tidak berhenti pada statistik deskriptif — tiap temuan
diterjemahkan menjadi keputusan rancangan.

**Kekurangan:** telaah pada PhysioCGM hanya mencakup 3 subjek, dan satu di
antaranya tidak memiliki kejadian hipoglikemia sama sekali.

---

# 4. Pembersihan data

Dikerjakan berlapis, sesuai jenis galat yang ditangani:

| Lapis | Aturan | Berkas |
|---|---|---|
| Rentang fisiologis | Jarak antar-detak di luar **300–2000 ms** (30–200 bpm) dibuang | `features.py:22`, `ekstrak_physiocgm.py:35` |
| Artefak denyut | Jarak menyimpang **>30%** dari median lokal dibuang | `features.py:44` |
| **Gerbang mutu jendela** | Jendela dengan **>10% selisih antar-denyut melebihi 100 ms** dikecualikan | `ekstrak_physiocgm.py:77` |
| Nilai hilang | Baris tanpa glukosa pembanding atau tanpa ciri dibuang | `train_hupa.py`, `pipeline_voc.py` |
| Korelasi antarsampel | Pencuplikan tiap **30 menit** agar sampel berdekatan tidak saling menyalin | `train_hupa.py:33` |

### Catatan penting tentang gerbang mutu

Nilai mutu **disimpan, bukan dipakai menyaring saat ekstraksi**. Dengan begitu
ambangnya dapat diubah pada tahap analisis tanpa memproses ulang 26 GB. Ini
memperlihatkan pertukaran yang harus dipilih:

| Ambang | Jendela | Hipoglikemia | RMSSD median |
|---|---|---|---|
| tanpa saring | 8.859 | 255 | 239 ms ❌ |
| < 20% | 2.687 | 76 | 74 ms |
| **< 10%** | **1.841** | **52** | **55,4 ms** ✅ |
| < 5% | 1.135 | 29 | 40,9 ms ✅ |

Makin ketat penyaringan, makin sahih nilai PRV-nya, tetapi makin sedikit
kejadian hipoglikemia yang tersisa.

**Kelebihan:** pembersihan berlapis dengan alasan fisiologis untuk tiap
ambang, bukan angka yang dipilih sembarangan.

**Kekurangan:** ambang 30% dan 10% ditetapkan dari pengamatan empiris pada
dataset ini, belum dari kajian pustaka. Nilai yang optimal untuk sensor kami
sendiri belum diketahui.

---

# 5. Rekayasa ciri

**Inilah tahap yang menghasilkan seluruh temuan utama penelitian ini.**

### Ciri yang diturunkan dari sinyal mentah

| Ciri | Makna | Berkas |
|---|---|---|
| `hr` | Detak per menit | `features.py` |
| `rmssd` | Rata-rata selisih jarak antar-detak berurutan | `features.py:60` |
| `sdnn` | Sebaran seluruh jarak antar-detak | `features.py:61` |
| `pnn50` | Proporsi selisih antar-detak melebihi 50 ms | `features.py:62` |

Ketiganya dihitung dari gelombang PPG mentah melalui: saring pita 0,8–2,5 Hz →
cari puncak → **haluskan waktu puncak dengan interpolasi parabolik** →
jarak antar-detak.

> **Interpolasi parabolik** diperlukan karena pada 64 Hz jarak antar-cuplikan
> 15,6 ms, terlalu kasar untuk mengukur variasi puluhan milidetik. Teknik ini
> memperkirakan letak puncak sesungguhnya di antara dua cuplikan.

### Ciri kontekstual

| Ciri | Guna |
|---|---|
| `hr_delta` | Perubahan detak dalam 30 menit terakhir |
| `hr_std` | Kelabilan detak selama 24 jam terakhir |
| `steps` | Menyaring anomali yang bersumber dari aktivitas fisik |
| `is_night` | Membedakan konteks siang dan malam |

### ⭐ Transformasi patokan personal — temuan utama

```
ciri_relatif = (nilai sekarang − patokan orang itu) ÷ patokan orang itu
```

Diterapkan pada `hr_rel` (`train_hupa.py:73`) dan `acetone_rel`
(`pipeline_voc.py:98`).

**Hasil terukur** *(masa kalibrasi dipisahkan menurut waktu)*:

| Pengujian | Nilai mentah | Relatif personal |
|---|---|---|
| Daya pisah HR *(PhysioCGM)* | 0,64 | **0,85** |
| Daya pisah RMSSD | 0,35 | **0,63** |
| Daya pisah pNN50 | 0,49 | **0,69** |
| Sensitivitas jalur VOC | 43,7% | **57,1%** |
| Lift *(Regresi Logistik, PhysioCGM)* | 1,20× | **1,82×** |

Peningkatan konsisten pada **seluruh ciri dan kedua jalur sinyal**.

### ⚠️ Pencegahan kebocoran patokan

Versi awal analisis ini menghitung patokan dari **seluruh** data tiap subjek —
termasuk bagian yang dipakai menguji. Menurut *Frontiers in Digital Health*
(2026), praktik itu menggelembungkan hasil sebesar 3–13 poin persen, disebut
**normalization leakage**.

Setelah diperbaiki dengan **memisahkan masa kalibrasi (30% awal) dari masa
evaluasi (70% sisa)**, hasilnya berubah:

| Hasil | Patokan bocor | Patokan terpisah |
|---|---|---|
| Lift SVM *(PhysioCGM)* | 2,14× | **1,66×** |
| Lift Regresi Logistik | 2,02× | **1,82×** |
| Sensitivitas VOC | 76,6% | **57,1%** |
| Peningkatan daya pisah RMSSD | 3,2× | **1,8×** |

**Berkas:** `uji_patokan_terpisah.py`

**Kelebihan:** kesimpulan bertahan setelah bias dihilangkan, dan besar
penggelembungannya terukur — sesuatu yang jarang dilaporkan bahkan dalam
makalah terbitan.

**Kekurangan:** porsi kalibrasi 30% dipilih tanpa dasar khusus. Belum diuji
seberapa panjang masa kalibrasi yang sebenarnya diperlukan.

---

# 6. Pemodelan & validasi

### Skema validasi

**Leave-One-Subject-Out** — model dilatih pada seluruh subjek kecuali satu,
lalu diuji pada subjek yang belum pernah dilihat, kemudian diputar.

Alasannya: data fisiologis adalah deret waktu per individu. Pembagian acak
biasa akan menempatkan potongan data orang yang sama pada himpunan latih dan
uji sekaligus, sehingga model mengenali **individunya** alih-alih kondisi
hipoglikemianya.

Seluruh ciri disusun **kausal** — hanya memakai data masa lalu. Patokan pada
`train_hupa.py` digeser satu langkah agar nilai yang sedang dinilai tidak turut
menyusun patokannya sendiri.

### Model yang diuji

**14 model dari 9 keluarga algoritma:** pohon keputusan, ensembel, *boosting*,
linear, kernel, berbasis jarak, probabilistik, diskriminan, dan jaringan saraf.

Hasil pada HUPA-UCM: **tidak satu pun melampaui tebakan acak** (lift 1,00–1,17).
Enam model memperoleh sensitivitas 0% — mempelajari bahwa jawaban teraman
adalah tidak pernah memberi peringatan.

**Karena keterbatasan itu konsisten di seluruh keluarga algoritma, penyebabnya
dapat dipastikan berada pada cirinya, bukan pada pemilihan model.**

**Berkas:** `train_hupa.py`, `hasil_model.csv`, `hasil_model.png`

### Kelebihan pendekatan ini

- Menguji banyak keluarga model memungkinkan penarikan kesimpulan tentang
  **sumber keterbatasan**, yang mustahil bila hanya satu model diuji
- Validasi antar-subjek mencegah akurasi semu
- Metrik medis, bukan akurasi
- Bias normalisasi dikenali dan dikoreksi

### Kekurangan yang diakui

| Kekurangan | Akibatnya |
|---|---|
| Hanya **2 subjek** PhysioCGM memiliki kejadian hipoglikemia | Validasi antar-subjek sangat lemah; hasil bersifat pendahuluan |
| Perbandingan 14 model **belum sepenuhnya setara** | Sebagian model diberi penyeimbang kelas, sebagian lain tidak mendukungnya |
| Ambang keputusan masih **0,5** | Belum disetel menurut kebutuhan klinis |
| **Belum ada data dari sensor sendiri** | Seluruh kesimpulan tentang metode, bukan tentang perangkat |
| Model **belum ditanam** di perangkat | Deteksi di gelang masih memakai anomali statistik |

---

# 7. Rencana lanjutan: representasi dari model dasar PPG

## Persoalan yang hendak dipisahkan

Sampai tahap ini masih tersisa satu pertanyaan yang belum terjawab:

> Apakah keterbatasan bersumber pada **sinyalnya** yang memang lemah, atau
> pada **ciri buatan** yang kami rancang yang terlalu kasar?

Keduanya menghasilkan gejala yang sama — model tak mampu memisahkan — sehingga
tidak dapat dibedakan hanya dengan menambah model atau menyetel ambang.

## Mengapa pendekatan ini dapat memisahkannya

Seluruh ciri variabilitas denyut yang kami pakai (RMSSD, SDNN, pNN50)
menuntut **penentuan waktu tiap denyut secara tepat** — dan justru di situlah
letak kegagalan yang terukur pada perangkat kami (jarak antar-denyut meleset
ratusan milidetik, sementara variasi yang hendak diukur hanya puluhan).

**Model dasar PPG bekerja langsung pada gelombang mentah** dan menghasilkan
representasinya sendiri, tanpa pernah mencari puncak denyut. Dengan demikian
pendekatan ini **melewati sepenuhnya hambatan tersebut**, sehingga hasilnya
dapat dipakai memisahkan kedua kemungkinan di atas:

| Hasil pengujian | Kesimpulan yang dapat ditarik |
|---|---|
| Representasi model dasar **berhasil** memisahkan | Sinyalnya ada; **ciri buatan kami** yang menjadi penghambat |
| Representasi model dasar **juga gagal** | Sinyalnya memang lemah pada PPG pergelangan |

Kedua kemungkinan sama-sama merupakan jawaban yang berguna.

## Model yang tersedia

| Model | Asal | Keterangan |
|---|---|---|
| **PaPaGei** | Nokia Bell Labs, ICLR 2025 | Model dasar PPG terbuka pertama; dilatih pada 57.000 jam (20 juta potongan) PPG dari dataset publik; menghasilkan representasi 512 dimensi |
| **Pulse-PPG** | terbuka | Dilatih pada data **lapangan**, bukan hanya klinis — berpotensi lebih sesuai untuk PPG pergelangan pada kegiatan sehari-hari |

## Cara penerapan yang sesuai dengan keterbatasan data

Model dasar **dibekukan**, dan hanya sebuah pengklasifikasi sederhana yang
dilatih di atas representasinya. Pendekatan ini dianjurkan untuk keadaan
berdata sedikit dan tidak menuntut penyetelan ulang seluruh model — sesuai
dengan jumlah kejadian hipoglikemia yang tersedia pada penelitian ini.

## Batas yang harus disampaikan

1. **Tidak dapat ditanam pada mikrokontroler.** Pendekatan ini merupakan alat
   analisis, bukan bagian dari perangkat. Keputusan peringatan di gelang tetap
   harus bertumpu pada model ringan yang dapat dikonversi menjadi kode C.
2. **Tidak menambah jumlah kejadian.** Keterbatasan utama tetap 29 kejadian
   hipoglikemia pada masa evaluasi; representasi yang lebih baik tidak
   mengubah hal itu.
3. **Kesesuaian ranah belum dipastikan.** PaPaGei dilatih pada PPG klinis
   (MIMIC-III, MESA), sehingga perpindahannya ke PPG pergelangan perangkat
   konsumen belum tentu mulus. Pulse-PPG lebih menjanjikan pada aspek ini.

## Status

**Belum dikerjakan.** Ditempatkan setelah pengumpulan data primer, karena
kegunaannya baru nyata bila jumlah kejadian mencukupi.

---

# 8. Rujukan pendukung

| Rujukan | Menopang |
|---|---|
| **Turner C, Walton C, Hoashi S, Evans M.** *Breath acetone concentration decreases with blood glucose concentration in type I diabetes mellitus patients during hypoglycaemic clamps* | Parameter regresi jalur VOC; bukti korelasi antar-individu praktis nihil (r = 0,134) |
| **PLOS ONE (2025).** *Personalized machine learning models for noninvasive hypoglycemia detection in people with type 1 diabetes using a smartwatch* | **Memvalidasi pendekatan personal**: 11 pasien T1D, model per-individu, AUROC 0,74 · sens 0,71 · spes 0,76; ciri jantung paling menentukan pada malam hari (42,2%) |
| **Frontiers in Digital Health (2026).** *Baseline normalization choices inflate classification performance in wearable health monitoring* | Dasar koreksi kebocoran patokan; penggelembungan 3–13 poin persen |
| **Saito T, Rehmsmeier M.** *The Precision-Recall Plot Is More Informative than the ROC Plot When Evaluating Binary Classifiers on Imbalanced Datasets* (PLOS ONE 2015) | Dasar pemilihan metrik pada kelas timpang |
| **Retrospective cohort 92.457 dewasa** (PMC7001906) | Ketidakseragaman detak istirahat antar- dan intra-individu |
| **American Diabetes Association (2023)** | Ambang hipoglikemia < 70 mg/dL |
| **PaPaGei: Open Foundation Models for Optical Physiological Signals** (ICLR 2025, Nokia Bell Labs) | Model dasar PPG untuk rencana lanjutan §7 |
| **Pulse-PPG: An Open-Source Field-Trained PPG Foundation Model** | Alternatif model dasar yang dilatih pada data lapangan |
| **HUPA-UCM Dataset** — Mendeley Data | Sumber data pasien tipe 1 |
| **BIG IDEAs Lab Dataset** — PhysioNet | Pembanding validasi PRV |
| **PhysioCGM** — figshare, Texas A&M, CC0 | PPG pergelangan + CGM pasien tipe 1 |

---

# 9. Yang boleh dan tidak boleh diklaim

| ✅ Boleh | ❌ Tidak boleh |
|---|---|
| Detak jantung agregat tidak memadai — diuji pada 14 model, 25 pasien | Menyebut angka akurasi perangkat |
| Patokan personal meningkatkan daya pisah pada seluruh ciri | Menyebut peningkatan 3–5× *(itu angka sebelum koreksi kebocoran)* |
| Algoritma PRV kami benar — diverifikasi terhadap data pembanding | Menyatakan PRV terbukti mendeteksi hipoglikemia |
| Akurasi pengukuran detak alat sesuai pembanding manual (58–68 vs 68 bpm) | Menyatakan sensor VOC mengukur kadar aseton |
| Kebocoran patokan dikenali dan dikoreksi | Mengutip hasil sebelum koreksi |

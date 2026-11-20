# Glosarium istilah — HypoSense

*Penjelasan setiap istilah teknis yang muncul di laporan, dalam bahasa yang
dapat disampaikan langsung kepada penilai. Tiap istilah disertai angka
sesungguhnya dari hasil kami, supaya penjelasannya tidak menggantung.*

Disusun 12 September 2026.

---

## ⭐ Tiga yang paling mungkin ditanya

Kalau waktu belajar terbatas, kuasai tiga ini lebih dulu.

| Istilah | Jawaban satu kalimat |
|---|---|
| **Sensitivitas vs presisi** | Sensitivitas melihat dari sisi **kejadian** (berapa yang tertangkap), presisi dari sisi **alarm** (berapa yang benar). Keduanya bisa berlawanan. |
| **Kenapa akurasi tidak dipakai** | Karena hipoglikemia hanya 7,2%; model yang **tidak pernah** memberi peringatan tetap meraih akurasi 92,8%. |
| **LOSO** | Model selalu diuji pada **pasien yang belum pernah dilihatnya**, sehingga hasilnya menggambarkan kemampuan pada orang baru. |

---

# A. Ukuran kinerja model

Seluruh angka di bawah berasal dari satu tabel yang sama — **matriks
kekeliruan** Regresi Logistik pada HUPA-UCM:

|  | Ditebak NORMAL | Ditebak HIPO |
|---|---|---|
| **Sebenarnya NORMAL** | 7.520 *(benar-negatif)* | 5.462 *(palsu-positif)* |
| **Sebenarnya HIPO** | 524 *(palsu-negatif)* | 490 *(benar-positif)* |

### Matriks kekeliruan *(confusion matrix)*
Tabel yang memecah hasil model menjadi empat kemungkinan: benar menebak hipo,
benar menebak normal, salah membunyikan alarm, dan gagal memberi alarm.
**Semua ukuran lain dihitung dari empat angka ini.**

### Benar-positif, palsu-positif, benar-negatif, palsu-negatif

| Istilah | Artinya | Jumlah |
|---|---|---|
| **Benar-positif** (TP) | Hipoglikemia terjadi, alarm berbunyi — **benar** | 490 |
| **Palsu-positif** (FP) | Keadaan normal, alarm tetap berbunyi — **alarm palsu** | 5.462 |
| **Benar-negatif** (TN) | Keadaan normal, alarm diam — **benar** | 7.520 |
| **Palsu-negatif** (FN) | Hipoglikemia terjadi, alarm **diam** — paling berbahaya | 524 |

### Sensitivitas
> *"Dari seluruh hipoglikemia yang **benar-benar terjadi**, berapa persen yang
> berhasil ditangkap?"*

490 dari 1.014 kejadian = **48,3%**. Artinya lebih dari separuh kejadian
terlewat.

### Spesifisitas
> *"Dari seluruh keadaan yang **benar-benar normal**, berapa persen yang benar
> dibiarkan tenang?"*

7.520 dari 12.982 = **57,9%**. Artinya alat sering ribut padahal tidak ada apa-apa.

### Presisi
> *"Dari seluruh alarm yang **berbunyi**, berapa persen yang ternyata benar?"*

490 dari 5.952 alarm = **8,2%**. Artinya **92 dari 100 alarm adalah palsu.**

> 💡 **Bedanya sensitivitas dan presisi** — inilah yang paling sering
> tertukar. Sensitivitas menghitung dari **kejadian nyata**; presisi
> menghitung dari **alarm yang dikeluarkan**. Alat yang membunyikan alarm
> terus-menerus akan punya sensitivitas tinggi tetapi presisi sangat rendah.

### Akurasi — dan mengapa TIDAK dipakai sebagai ukuran utama
Persentase seluruh tebakan yang benar. **Menyesatkan pada kejadian langka.**

Contoh dari data kami: hipoglikemia hanya 7,2%. Model yang **selalu** menebak
"normal" dan tidak pernah memberi peringatan sama sekali tetap memperoleh
**akurasi 92,8%** — lebih tinggi daripada Regresi Logistik yang benar-benar
mendeteksi. Karena itu akurasi ditinggalkan dan diganti sensitivitas +
spesifisitas.

### Prevalensi
Seberapa sering kejadian itu muncul dalam data. Pada HUPA-UCM: **7,2%**
(1.014 dari 13.996 sampel). Angka ini menjadi tolok ukur "menebak acak".

### Kali lipat dari tebakan acak
Seberapa jauh presisi model melampaui prevalensi.

Presisi 8,2% dibagi prevalensi 7,2% = **1,14 kali lipat**. Artinya alarm model
hanya **sedikit** lebih terpercaya daripada menebak sembarangan. Angka 1,0
berarti setara dengan menebak acak.

### Alarm palsu per malam
Terjemahan palsu-positif ke dalam pengalaman pemakai. **±40 kali semalam** —
angka yang menentukan apakah alat akan tetap dipakai malam kedua.

---

# B. Cara pengujian

### LOSO *(Leave-One-Subject-Out)*
Model dilatih memakai data **24 pasien**, lalu diuji pada **1 pasien yang
belum pernah dilihatnya**. Diulang 25 kali sehingga tiap pasien pernah menjadi
penguji.

**Kenapa tidak pembagian acak 70/15/15?** Karena pada data fisiologis,
pembagian acak menaruh potongan pasien yang sama di data latih dan data uji.
Model lalu mengenali **individunya**, bukan **kondisinya** — hasilnya tampak
bagus padahal tidak akan bekerja pada orang baru.

### Kebocoran data *(data leakage)*
Keadaan ketika keterangan dari data uji ikut terbawa ke proses pelatihan,
sehingga hasil terlihat lebih baik daripada kenyataannya.

**Kami pernah mengalaminya, dan mengoreksinya sendiri:** patokan personal
semula dihitung dari seluruh data — termasuk bagian yang dipakai menguji.
Setelah masa kalibrasi dipisahkan (hanya 30% sampel awal), angkanya turun,
dan angka yang lebih rendah itulah yang dilaporkan.

### Kelas timpang *(imbalanced class)*
Keadaan ketika satu kelompok jauh lebih banyak daripada yang lain. Di sini:
92,8% normal berbanding 7,2% hipoglikemia.

### Penyeimbangan kelas *(class balancing)*
Upaya menyamakan jumlah kedua kelompok saat melatih, agar model tidak
mengabaikan kelompok yang langka.

⚠️ **Yang boleh diseimbangkan hanya data LATIH.** Bila data **uji** ikut
diseimbangkan, presisinya melonjak — bukan karena model membaik, melainkan
karena kejadiannya dibuat seolah jauh lebih sering daripada kenyataan.

### SMOTE
Salah satu cara penyeimbangan: membuat sampel buatan bagi kelompok yang langka
dengan menyisipkan titik baru di antara sampel-sampel yang sudah ada.
Hasil pada data kami: **tidak berbeda berarti** dari cara lain.

### Penyetelan parameter *(hyperparameter tuning)*
Mencoba berbagai pengaturan model untuk mencari yang terbaik. Hasil pada data
kami: perbaikan hanya sampai **1,13–1,15 kali** tebakan acak — menegaskan
bahwa hambatannya ada pada **ciri**, bukan pada pengaturan model.

---

# C. Asumsi statistik dan pemeriksaannya

### Multikolinearitas
Keadaan ketika ciri-ciri yang dimasukkan ke model **saling berkorelasi kuat**,
sehingga model sulit memisahkan pengaruh masing-masing.

**Akibatnya** koefisien menjadi tidak stabil dan tandanya bisa berbalik —
artinya yang dirusak adalah **penafsiran**, bukan kemampuan memprediksi.

### VIF *(Variance Inflation Factor)*
Ukuran seberapa parah multikolinearitas itu. Menghitung seberapa jauh satu
ciri dapat ditebak dari **seluruh ciri lain sekaligus**.

| Nilai VIF | Artinya |
|---|---|
| < 5 | aman, koefisien masih dapat ditafsirkan |
| 5–10 | perlu diwaspadai |
| > 10 | bermasalah |

**Hasil pemeriksaan kami: VIF tertinggi 4,10** — di bawah kedua ambang.
Diperiksa lewat `analysis/model/uji_kolinearitas.py`.

> 💡 Korelasi kuat antar-dua-ciri belum tentu menghasilkan VIF tinggi. Pada
> data kami, detak dan detak-relatif berkorelasi 0,862 — cukup kuat — tetapi
> VIF-nya tetap di bawah 5, sebab yang dihitung VIF adalah hubungan terhadap
> **seluruh** ciri, bukan sepasang saja.

### Regularisasi L2
Penahan yang mencegah koefisien model membesar tak terkendali. Merupakan
**penanganan baku untuk multikolinearitas**, dan sudah aktif secara bawaan
pada model yang kami pakai.

### Korelasi Pearson (*r*)
Ukuran kekuatan hubungan lurus antara dua besaran, bernilai −1 sampai +1.
0 berarti tidak ada hubungan.

Contoh dari kami: kadar aseton antar-orang berkorelasi hanya **r = 0,134** —
praktis nihil. Inilah alasan patokan personal wajib dipakai, sebab satu ambang
yang berlaku untuk semua orang mustahil.

### Koefisien determinasi (*R²*)
Berapa bagian keragaman data yang dapat dijelaskan model, bernilai 0 sampai 1.

Contoh: persamaan Turner dkk. per pasien memiliki **R² 0,598–0,940** — artinya
hubungan aseton-glukosa **kuat di dalam satu orang**, meskipun antar-orang
praktis nihil.

---

# D. Sensor dan fisiologi

### PPG / fotopletismografi
Cara mengukur denyut dengan **cahaya**: LED menyinari kulit, sensor menangkap
pantulannya, dan perubahan pantulan mengikuti aliran darah tiap denyut.
Berbeda dari EKG yang mengukur **kelistrikan** jantung.

### IBI *(inter-beat interval)*
Selang waktu antara dua denyut berurutan, dalam milidetik. **Seluruh ukuran
variabilitas dihitung dari deret angka ini.**

### PRV *(Pulse Rate Variability)*
Variasi selang waktu antar-denyut, diukur dari **PPG**.

> ⚠️ **Bukan HRV.** HRV diukur dari EKG (kelistrikan jantung), PRV dari PPG
> (pantulan cahaya). Keduanya berasal dari proses yang sama, tetapi penelitian
> 2025 pada 931 orang menyimpulkan **PRV bukan pengganti sah untuk HRV**.
> Perangkat kami hanya mampu mengukur PRV, dan itu harus disebut apa adanya.

### RMSSD, SDNN, pNN50
Tiga cara berbeda mengukur variabilitas dari deret IBI yang sama:

| Ukuran | Menghitung apa |
|---|---|
| **RMSSD** | Rata-rata selisih antara dua denyut **berurutan** |
| **SDNN** | Sebaran seluruh selang denyut secara keseluruhan |
| **pNN50** | Persentase selisih antar-denyut yang melebihi 50 milidetik |

### PI *(Perfusion Index)*
Ukuran kekuatan sinyal denyut — seberapa jelas riak denyut dibanding
latar cahayanya.

Pengukuran kami: **1,11% di ujung jari** berbanding **0,15% di pergelangan**
— selisih 7,4 kali. Inilah sebab utama ketelitian waktu denyut kami masih
rendah.

### Patokan personal *(baseline)*
Nilai rujukan milik tiap orang sendiri, bukan angka yang sama untuk semua.

**Kenapa wajib:** detak istirahat antar-pasien berbeda hingga **27,1 bpm**
(62,7–89,8 bpm), dan kadar aseton antar-orang berbeda hingga 21 kali lipat.
Satu ambang tunggal karena itu mustahil.

### Respons sympathoadrenal
Reaksi tubuh saat gula darah turun: adrenalin dilepaskan, dan itu mengubah
kerja jantung. **Inilah dasar fisiologis jalur kardiovaskular kami** —
hubungannya bukan kebetulan statistik, melainkan mekanisme yang sudah
terdokumentasi.

---

# E. Jalur VOC

### VOC *(Volatile Organic Compounds)*
Senyawa organik yang menguap dan terbawa dalam napas.

### Aseton dan isoprena

| Senyawa | Hubungan dengan hipoglikemia |
|---|---|
| **Aseton** | Naik seiring gula **tinggi**; **tidak** berasosiasi bermakna khusus saat hipoglikemia |
| **Isoprena** | Naik saat hipoglikemia *(Diabetes Care 2016)* — tetapi MQ-138 tidak tercatat peka terhadapnya |

**Karena itu peran VOC pada alat kami adalah menyingkirkan kemungkinan gula
tinggi**, bukan memastikan hipoglikemia.

### Sensor MOS *(Metal Oxide Semiconductor)*
Jenis sensor gas yang resistansinya berubah bila terkena gas pereduksi.
**Tidak punya daya pilih** — ia memberi satu angka untuk seluruh gas
sekaligus, tanpa keterangan gas apa penyebabnya.

### ppm *(parts per million)*
Satuan kadar gas: satu bagian per sejuta bagian udara.

⚠️ Kadar aseton napas **0,3–3 ppm**, sedangkan rentang deteksi MQ-138
**10–300 ppm**. Sasaran berada sekitar tiga puluh kali **di bawah** lantai
deteksinya — karena itu angka ppm tidak kami klaim sebagai hasil pengukuran
yang sahih.

### Rs/R0
Perbandingan resistansi sensor saat ini terhadap resistansinya di udara
bersih. Tidak bersatuan, dan **tidak bergantung pada nilai resistor beban**.
Inilah besaran yang kami laporkan, menggantikan ppm.

---

# F. Model yang dipakai

### Regresi Logistik
Model yang menimbang tiap ciri dengan satu koefisien, lalu menjumlahkannya
menjadi peluang. **Ringan** dan **dapat ditelusuri** — bobot tiap ciri terbaca
langsung. Itulah alasan pemilihannya, bukan karena kinerjanya memadai.

### Gradient Boosting
Model yang menyusun banyak pohon keputusan bertahap, tiap pohon memperbaiki
kesalahan pohon sebelumnya. Lebih kuat menangkap hubungan rumit, tetapi
lebih berat dan lebih sulit ditelusuri.

**Perbandingan pada data kami:**

| | Sensitivitas | Spesifisitas | Alarm palsu/malam |
|---|---|---|---|
| Regresi Logistik | 48,3% | 57,9% | ±40 |
| Gradient Boosting | 28,0% | 75,4% | ±24 |

Keunggulannya **terbagi**, bukan menyeluruh — satu menangkap lebih banyak
kejadian, satu lagi lebih sedikit mengganggu. Tidak ada yang mencapai wilayah
layak pakai.

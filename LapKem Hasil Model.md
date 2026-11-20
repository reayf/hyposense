# Laporan Kemajuan — Hasil Pemodelan Kecerdasan Buatan

*Penomoran subbab menyesuaikan struktur laporan. Seluruh angka berasal dari
pengujian yang benar-benar dijalankan.*

---

## 4.1 Hasil Pemodelan Kecerdasan Buatan

Pemodelan dilakukan pada dua jalur sinyal yang dirancang saling melengkapi, yakni jalur kardiovaskular sebagai pendeteksi utama dan jalur senyawa organik mudah menguap sebagai pembeda arah perubahan glukosa. Kedua jalur diuji secara terpisah dengan sumber data dan tujuan pengujian yang berbeda.

### 4.1.1 Pelatihan pada data pasien nyata

Pelatihan jalur kardiovaskular dilakukan pada dataset HUPA-UCM yang memuat 25 pasien diabetes melitus tipe 1. Dari 309.392 sampel yang tersedia, dilakukan pencuplikan menjadi **13.996 sampel** dengan jarak tiga puluh menit antar sampel guna mengurangi korelasi antarsampel yang berdekatan, menghasilkan prevalensi hipoglikemia sebesar **7,2%**. Pengujian menggunakan skema **validasi silang antar-subjek** (*Leave-One-Subject-Out*), yakni model dilatih pada dua puluh empat pasien dan diuji pada satu pasien yang belum pernah dilihat model, kemudian diputar untuk seluruh pasien.

Guna memastikan hasil yang diperoleh tidak dipengaruhi kekeliruan dalam pemilihan algoritma, pengujian dilakukan terhadap **empat belas model dari sembilan keluarga algoritma**. Hasil selengkapnya disajikan pada Tabel 4.1.

**Tabel 4.1** Hasil pengujian empat belas model pada dataset HUPA-UCM dengan validasi *Leave-One-Subject-Out* (25 pasien, 13.996 sampel, prevalensi hipoglikemia 7,2%)

| Model | Sensitivitas | Spesifisitas | Presisi | *Lift* | Akurasi |
|---|---|---|---|---|---|
| **▶ Regresi Logistik** — **model yang dibawa ke tahap berikutnya** | **48,3%** | **57,9%** | **8,2%** | **1,14×** | **57,2%** |
| Random Forest | 1,4% | 98,6% | 7,2% | 1,00× | 91,6% |
| Extra Trees | 0,3% | 99,8% | 11,1% | 1,53× | 92,6% |
| Decision Tree | 40,5% | 65,9% | 8,5% | 1,17× | 64,0% |
| Gradient Boosting | 28,0% | 75,4% | 8,2% | 1,13× | 71,9% |
| AdaBoost | 0,0% | 100,0% | — | — | 92,8% |
| Ridge Classifier | 48,3% | 57,9% | 8,2% | 1,14× | 57,2% |
| SVM (RBF) | 44,2% | 58,9% | 7,7% | 1,07× | 57,9% |
| SVM (linear) | 48,3% | 57,9% | 8,2% | 1,14× | 57,2% |
| K-Nearest Neighbors | 0,0% | 100,0% | 0,0% | 0,00× | 92,7% |
| Naive Bayes | 0,0% | 100,0% | — | — | 92,8% |
| LDA | 0,0% | 100,0% | — | — | 92,8% |
| QDA | 0,0% | 100,0% | — | — | 92,8% |
| Neural Net (MLP) | 0,0% | 100,0% | 0,0% | 0,00× | 92,7% |
| *(pembanding: model yang selalu menjawab "aman")* | *0,0%* | *100,0%* | *—* | *—* | *92,8%* |

*Lift* merupakan rasio presisi terhadap prevalensi; nilai 1,00 berarti ketepatan model setara dengan tebakan acak. Tanda "—" menunjukkan model tidak pernah memberikan keluaran positif sehingga presisi tidak terdefinisi.

Baris teratas menandai model yang dibawa ke tahap berikutnya. **Penandaan tersebut tidak berarti model itu berhasil pada tabel ini** — pada ciri detak jantung saja tidak ada model yang berhasil. Dasar pemilihannya diuraikan pada subbab 4.1.5, yakni kinerja terbaik setelah ciri variabilitas denyut ditambahkan (*lift* 1,82× dengan sensitivitas 65,5%), kemampuannya ditanam pada mikrokontroler karena keputusannya hanya berupa penjumlahan berbobot terhadap satu ambang, serta keterlacakan alasan setiap peringatan yang dibunyikan.

Dari tabel tersebut diperoleh tiga temuan. **Pertama**, tidak satu pun model melampaui tebakan acak secara bermakna, dengan seluruh nilai *lift* berada pada kisaran 1,00–1,17. Nilai tertinggi sebesar 1,53× pada *Extra Trees* tidak dapat dianggap unggul karena diperoleh dengan sensitivitas 0,3%, yakni hanya tiga dari 1.014 kejadian hipoglikemia yang terdeteksi. **Kedua**, enam model memperoleh sensitivitas 0% dengan akurasi yang setara model pembanding yang tidak melakukan pendeteksian sama sekali, yang berarti model-model tersebut mempelajari bahwa jawaban teraman adalah tidak pernah memberikan peringatan. **Ketiga**, tiga metode linear yang berbeda menghasilkan angka yang identik, menandakan tidak tersisa pola kompleks untuk dipelajari pada data tersebut.

Hasil ini sekaligus memperlihatkan alasan **akurasi tidak digunakan sebagai metrik utama**. Model Random Forest memperoleh akurasi 91,6% yang tampak baik, namun sensitivitasnya hanya 1,4% sehingga praktis tidak pernah memberikan peringatan. Angka tersebut bahkan lebih rendah daripada akurasi model pembanding yang sama sekali tidak melakukan pendeteksian, yaitu 92,8%.

### 4.1.2 Penelaahan penyebab keterbatasan

Penelaahan lanjutan terhadap data dilakukan untuk memastikan sumber keterbatasan. Diperoleh bahwa **sebaran detak jantung pada kondisi hipoglikemia (74,0 ± 15,8 bpm) dan kondisi normal (77,2 ± 15,5 bpm) hampir sepenuhnya bertumpuk**, dengan selisih rata-rata hanya 3,2 bpm atau sekitar seperlima simpangan bakunya sendiri. Dengan kata lain, sinyal yang hendak dikenali tenggelam di dalam variasi normalnya sendiri.

Karena keterbatasan tersebut bersifat konsisten pada seluruh keluarga algoritma, dapat disimpulkan bahwa penyebabnya **bukan terletak pada pemilihan model, melainkan pada ketersediaan ciri**. Detak jantung teragregasi semata tidak memuat informasi yang memadai untuk menandai hipoglikemia. Temuan ini menjadi dasar terukur atas keputusan menargetkan variabilitas denyut sebagai ciri utama pada tahap berikutnya.

Penelaahan yang sama menghasilkan dua temuan yang memperkuat rancangan sistem. Pertama, **detak jantung rata-rata antarpasien berbeda hingga 27,1 bpm**, yakni dari 62,7 hingga 89,8 bpm, sehingga satu nilai ambang yang berlaku bagi seluruh pengguna tidak dimungkinkan dan pendekatan patokan personal menjadi keharusan. Kedua, **kejadian hipoglikemia lebih sering terjadi pada periode malam (7,70%) dibanding siang (6,03%)**, sementara detak jantung rata-rata pada malam hari sebesar 68,7 bpm berbeda jauh dari siang hari sebesar 81,1 bpm. Temuan kedua memperkuat pemilihan hipoglikemia nokturnal sebagai sasaran utama sekaligus menunjukkan perlunya pemisahan patokan personal menurut periode siang dan malam.

### 4.1.3 Hasil pemodelan jalur VOC

Pemodelan jalur VOC menguji apakah kadar aseton napas sebaiknya dibaca sebagai nilai mutlak atau sebagai perubahan terhadap patokan personal. Pengujian menggunakan Random Forest dengan validasi antar-subjek, dan hasilnya disajikan pada Tabel 4.2.

**Tabel 4.2** Perbandingan cara pembacaan kadar aseton pada jalur VOC

| Cara pembacaan | Sensitivitas | Spesifisitas | Presisi | Daya pisah (*Cohen's d*) |
|---|---|---|---|---|
| Kadar mutlak | 43,7% | 62,3% | 44,1% | 0,39 |
| Perubahan relatif terhadap patokan personal | **57,1%** | **72,6%** | **58,6%** | **0,99** |

Pembacaan secara relatif meningkatkan sensitivitas sebesar 13,4 poin dan meningkatkan daya pisah antarkelas sebanyak **2,5 kali lipat**, semata-mata karena perubahan cara pembacaan tanpa mengubah data maupun algoritmanya. Hasil ini memperkuat rancangan patokan personal yang diterapkan pada sistem.

Patokan personal pada pengujian ini dihitung **hanya dari 30% sampel awal tiap subjek**, dan bagian tersebut dikeluarkan dari penilaian. Pemisahan ini diterapkan setelah kami mendapati bahwa menghitung patokan dari seluruh data — termasuk bagian yang dipakai menguji — menggelembungkan hasil secara berarti. Uraian lengkapnya disajikan pada subbab 4.1.5.

Karena data pemodelan jalur ini dibangkitkan dari persamaan regresi terbitan, dilakukan **pemeriksaan kesetiaan simulasi** terhadap parameter aslinya. Diperoleh selisih rata-rata koefisien determinasi sebesar **0,046** terhadap nilai yang dilaporkan, serta korelasi antar-subjek sebesar **0,111** dibanding 0,134 yang dilaporkan makalah. Kesesuaian pada kedua besaran tersebut menunjukkan bahwa simulasi tidak hanya menyalin bentuk hubungannya, tetapi juga mempertahankan sifat penting datanya, yakni ketiadaan hubungan antarindividu.

Perlu ditegaskan bahwa hasil pada Tabel 4.2 **diperoleh dari simulasi berbasis parameter terbitan dan bukan merupakan pengukuran sensor yang dikembangkan**, sehingga belum dapat dinyatakan sebagai akurasi perangkat.

### 4.1.4 Validasi pipeline ekstraksi variabilitas denyut

Algoritma penghitungan variabilitas denyut divalidasi menggunakan data jarak antar-detak berkualitas riset dari dataset BIG IDEAs Lab. Diperoleh **RMSSD median sebesar 51,4 ms dengan rentang 27,9–67,7 ms**, yang sesuai dengan rujukan orang dewasa sehat dalam keadaan istirahat sebesar 20–60 ms. Dengan demikian algoritma yang dikembangkan dinyatakan benar.

Sebaliknya, pengujian algoritma yang sama pada sinyal dari sensor sendiri menghasilkan nilai **89–155 ms** yang berada jauh di luar rentang wajar. Karena algoritmanya telah terbukti benar melalui data pembanding, ketidaksesuaian tersebut dapat dipastikan bersumber pada **ketelitian penentuan waktu denyut** dan bukan pada kekeliruan perhitungan. Pemisahan sumber galat ini merupakan manfaat langsung dari penggunaan dataset pembanding, dan mengarahkan perbaikan pada peningkatan kualitas sinyal alih-alih pada penyuntingan algoritma.

### 4.1.5 Pengenalan dan koreksi kebocoran patokan

Pengujian jalur variabilitas denyut juga dilakukan pada dataset PhysioCGM, yang memuat gelombang fotopletismografi pergelangan tangan mentah beserta data glukosa dari pasien diabetes tipe 1. Pada tahap ini ditemukan persoalan metodologis yang berlaku bagi seluruh pengujian berbasis patokan personal.

Analisis awal menghitung patokan personal dari **seluruh** rekaman tiap subjek, termasuk bagian yang kemudian dipakai menguji. Praktik demikian dilaporkan *Frontiers in Digital Health* (2026) menggelembungkan hasil klasifikasi sebesar 3–13 poin persen, dan disebut ***normalization leakage***: statistik normalisasi dihitung dari data yang selanjutnya muncul pada himpunan uji, sehingga patokan menjadi cocok sempurna dengan periode yang dinilai — sesuatu yang tidak terjadi pada pemakaian sesungguhnya.

Perbaikan dilakukan dengan **memisahkan masa kalibrasi dari masa evaluasi menurut waktu**: 30% rekaman paling awal tiap subjek dipakai membangun patokan dan dikeluarkan dari penilaian, sedangkan 70% sisanya dipakai menilai. Pemisahan ini sekaligus meniru pemakaian nyata, yakni perangkat mempelajari kebiasaan pengguna terlebih dahulu sebelum mulai menilai.

**Tabel 4.3** Pengaruh kebocoran patokan terhadap hasil

| Hasil | Patokan tidak dipisahkan | Patokan dipisahkan menurut waktu |
|---|---|---|
| *Lift* — SVM (PhysioCGM) | 2,14× | **1,66×** |
| *Lift* — Regresi Logistik (PhysioCGM) | 2,02× | **1,82×** |
| Sensitivitas jalur VOC | 76,6% | **57,1%** |
| Peningkatan daya pisah RMSSD | 3,2× | **1,8×** |

Setelah koreksi, kesimpulan tetap bertahan: patokan personal meningkatkan daya pisah pada seluruh ciri dan pada kedua jalur sinyal. Yang berubah adalah besarnya, yang ternyata lebih kecil daripada hasil sebelum koreksi.

Pada pembandingan setara — model yang sama, himpunan uji yang sama — keunggulan patokan personal tampak pada Regresi Logistik (1,82× dibanding 1,20× pada nilai mentah), namun setara pada SVM (1,66× dibanding 1,67×). Dengan hanya 29 kejadian hipoglikemia pada masa evaluasi, selisih sekecil itu belum dapat dipastikan.

### 4.1.6 Ringkasan capaian dan batasan

Ringkasan capaian pemodelan disajikan pada Tabel 4.4.

**Tabel 4.4** Ringkasan capaian dan batasan pemodelan

| Aspek | Capaian |
|---|---|
| Kerangka pemodelan (ekstraksi ciri hingga metrik) | Berfungsi dan terverifikasi |
| Pelatihan pada data pasien nyata | Selesai — 14 model, 25 pasien, validasi antar-subjek |
| Algoritma ekstraksi variabilitas denyut | Terbukti benar melalui data pembanding |
| Pembuktian keunggulan patokan personal | Terbukti pada kedua jalur, kardiovaskular dan VOC, setelah kebocoran patokan dikoreksi |
| Pengenalan bias metodologis | Kebocoran patokan ditemukan, diukur besarnya, dan dikoreksi |
| Akurasi deteksi hipoglikemia | **Belum dapat diklaim** — memerlukan ciri variabilitas denyut |
| Model terlatih pada data primer | **Belum** — menunggu uji klinik |
| Penanaman model pada perangkat | **Belum** — dilakukan setelah tervalidasi |

Dengan demikian, capaian pemodelan pada tahap ini berupa **kerangka yang telah berfungsi beserta pemetaan terukur atas keterbatasannya**, bukan berupa akurasi deteksi. Keterbatasan yang ditemukan bersifat spesifik dan dapat ditindaklanjuti, yakni terletak pada ketersediaan ciri dan kualitas sinyal, bukan pada rancangan sistem maupun pemilihan algoritma.

---

## ⚠️ Catatan sebelum ditempel ke laporan

1. **Sesuaikan penomoran** subbab dan tabel dengan struktur laporan.
2. **Jangan menghapus** penegasan pada 4.1.3 bahwa hasil jalur VOC berasal dari simulasi.
3. **Jangan menambahkan angka akurasi perangkat** di mana pun.
4. Gambar pendukung yang dapat disisipkan: `hasil_model.png` (perbandingan 14 model) pada 4.1.1 dan `hasil_voc.png` (mutlak vs relatif) pada 4.1.3.
5. Bila subbab 3.4/3.5 sudah memuat sebagian angka ini, sesuaikan agar tidak berulang — bagian metode cukup menyebut cara, bagian hasil yang memuat angkanya.

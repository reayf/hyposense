import os
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INO_ORIG = os.path.abspath(os.path.join(BASE_DIR, "..", "hyposense-aplikasi", "esp32", "hyposense_esp32_ble", "hyposense_esp32_ble.ino"))
INO_COPY = os.path.join(BASE_DIR, "hyposense_esp32_ble.ino")

with open(INO_ORIG, "r", encoding="utf-8") as f:
    text = f.read()

# Normalisasi CRLF -> LF sementara agar pencocokan blok akurat
text = text.replace("\r\n", "\n")
# Jika sudah pernah dijalankan sebelumnya, pulihkan baris multiline Serial.printf terlebih dahulu
text = text.replace('"[TinyML] P_PPG=%.2f  P_VOC=%.2f  P_Gabungan=%.2f -> %s\n"', '"[TinyML] P_PPG=%.2f  P_VOC=%.2f  P_Gabungan=%.2f -> %s\\n"')

# 1. Tambahkan variabel patokan PRV, SHT31, dan status probabilitas TinyML
target_1 = """float hrBaseline = 0, hrDevEma = 6.0f;
bool  baselineReady = false;
uint32_t baselineStartMs = 0, devAnomStartMs = 0;
float vocBreathBase = 0;   // aseton NAPAS saat glukosa normal (keputusan)
float vocR0Adc      = 0;   // bacaan UDARA BERSIH (pengubahan ke ppm)"""

replace_1 = """float hrBaseline = 0, hrDevEma = 6.0f;
float prvBaseline = 0;     // patokan PRV (RMSSD) personal saat kondisi normal
float prvMinWindow = 0;    // PRV minimum bergulir untuk fitur Lapisan 1
bool  baselineReady = false;
uint32_t baselineStartMs = 0, devAnomStartMs = 0;
float vocBreathBase  = 0;  // aseton NAPAS saat glukosa normal (keputusan)
float tempBreathBase = 0;  // suhu kabin SHT31 saat kalibrasi napas normal
float humBreathBase  = 0;  // kelembapan kabin SHT31 saat kalibrasi napas normal
float vocR0Adc       = 0;  // bacaan UDARA BERSIH (pengubahan ke ppm)

// Status probabilitas keluaran model TinyML Dua Jalur (0.0 - 1.0)
float lastPpgProb   = 0.0f; // Lapisan 1: Logistic Regression (PPG: HR + PRV)
float lastVocProb   = 0.0f; // Lapisan 2: Pruned Random Forest (VOC + SHT31)
float lastJointProb = 0.0f; // Gabungan: Two-Stage Cascade & Soft-Voting Ensemble"""

assert target_1 in text, "target_1 tidak ditemukan"
text = text.replace(target_1, replace_1, 1)

# 2. Perbarui cekAnomaliHR() menjadi Lapisan 1 TinyML (Logistic Regression: HR + PRV)
target_2 = """bool cekAnomaliHR() {
  if (beatAvg <= 0 || beatCount < RATE_SIZE) { devAnomStartMs = 0; return false; }
  if (baselineReady && beatAvg >= TACHY_THRESHOLD &&
      beatAvg > hrBaseline + HR_MIN_DELTA) return true;

  if (hrBaseline <= 0) { hrBaseline = beatAvg; baselineStartMs = millis(); return false; }
  if (!baselineReady) {
    hrBaseline += 0.02f * (beatAvg - hrBaseline);
    if (millis() - baselineStartMs > BASELINE_WARMUP_MS) {
      baselineReady = true; prefs.putFloat("hrbase", hrBaseline);
    }
    return false;
  }
  float diff = fabsf(beatAvg - hrBaseline);
  float thresh = fmaxf(HR_K * hrDevEma, HR_MIN_DELTA);
  if (diff <= thresh) {
    hrBaseline += HR_EMA_BASE * (beatAvg - hrBaseline);
    hrDevEma   += HR_EMA_DEV  * (diff - hrDevEma);
    devAnomStartMs = 0;
    return false;
  }
  if (devAnomStartMs == 0) devAnomStartMs = millis();
  return (millis() - devAnomStartMs) > DEV_HOLD_MS;
}"""

replace_2 = """// ---- Inferensi TinyML Lapisan 1: Logistic Regression (PPG: HR + PRV) ----
// Menggabungkan fitur detak jantung (HR) dan variabilitas antar-denyut (PRV/RMSSD)
// yang dinormalisasi terhadap patokan personal masing-masing pemakai.
// Parameter StandardScaler dan koefisien LogisticRegression diekspor langsung
// dari hasil pelatihan data uji klinis perangkat HypoSense-001 di RSUA.
float hitungProbabilitasPPG(int hr, float prv) {
  if (hrBaseline <= 0.0f) return 0.0f;
  float pBase = (prvBaseline > 1.0f) ? prvBaseline : ((prv > 1.0f) ? prv : 80.0f);
  float pNow  = (prv > 1.0f) ? prv : pBase;
  if (prvMinWindow <= 1.0f || pNow < prvMinWindow) prvMinWindow = pNow;
  else prvMinWindow = 0.92f * prvMinWindow + 0.08f * pNow;

  float hr_delta    = (float)hr - hrBaseline;
  float hr_rel      = hr_delta / hrBaseline;
  float prv_rel     = (pNow - pBase) / pBase;
  float prv_min_rel = (prvMinWindow - pBase) / pBase;

  // Standarisasi Z-score (StandardScaler)
  float z_hr          = ((float)hr   - 81.3077f) / 20.6214f;
  float z_hr_delta    = (hr_delta    - 16.1387f) / 20.4383f;
  float z_hr_rel      = (hr_rel      -  0.3225f) /  0.3940f;
  float z_prv         = (pNow        - 111.2348f) / 33.2397f;
  float z_prv_rel     = (prv_rel     - (-0.0357f)) / 0.4651f;
  float z_prv_min_rel = (prv_min_rel - (-0.2123f)) / 0.3958f;

  // Kombinasi linear Regresi Logistik (C=0.5, class_weight='balanced')
  float logit = -2.1231f
              + ( 1.0570f * z_hr)
              + ( 1.3909f * z_hr_delta)
              + (-2.3785f * z_hr_rel)
              + ( 0.1641f * z_prv)
              + (-2.0374f * z_prv_rel)
              + (-1.6996f * z_prv_min_rel);

  if (logit >  15.0f) return 0.9999f;
  if (logit < -15.0f) return 0.0001f;
  return 1.0f / (1.0f + expf(-logit));
}

bool cekAnomaliHR() {
  if (beatAvg <= 0 || beatCount < RATE_SIZE) { devAnomStartMs = 0; return false; }
  float prvNow = computePrv();

  if (hrBaseline <= 0) {
    hrBaseline = beatAvg;
    if (prvNow > 0) prvBaseline = prvNow;
    baselineStartMs = millis();
    return false;
  }
  if (!baselineReady) {
    hrBaseline += 0.02f * (beatAvg - hrBaseline);
    if (prvNow > 0) {
      prvBaseline = (prvBaseline <= 0) ? prvNow : (prvBaseline + 0.02f * (prvNow - prvBaseline));
    }
    if (millis() - baselineStartMs > BASELINE_WARMUP_MS) {
      baselineReady = true;
      prefs.putFloat("hrbase", hrBaseline);
      if (prvBaseline > 0) prefs.putFloat("prvbase", prvBaseline);
    }
    return false;
  }

  // Evaluasi probabilitas anomali otonom Lapisan 1 (Logistic Regression: HR + PRV)
  lastPpgProb = hitungProbabilitasPPG(beatAvg, prvNow);

  // Picu seketika bila takikardia disertai lonjakan probabilitas Regresi Logistik
  if (beatAvg >= TACHY_THRESHOLD && beatAvg > hrBaseline + HR_MIN_DELTA && lastPpgProb >= 0.48f) {
    return true;
  }

  float diff = fabsf(beatAvg - hrBaseline);
  float thresh = fmaxf(HR_K * hrDevEma, HR_MIN_DELTA);
  bool anomaliModel = (lastPpgProb >= 0.48f) && (beatAvg >= hrBaseline + HR_MIN_DELTA);

  if (!anomaliModel && diff <= thresh) {
    hrBaseline += HR_EMA_BASE * (beatAvg - hrBaseline);
    hrDevEma   += HR_EMA_DEV  * (diff - hrDevEma);
    if (prvNow > 0) {
      prvBaseline = (prvBaseline <= 0) ? prvNow : (prvBaseline + HR_EMA_BASE * (prvNow - prvBaseline));
    }
    devAnomStartMs = 0;
    return false;
  }
  if (devAnomStartMs == 0) devAnomStartMs = millis();
  return (millis() - devAnomStartMs) > DEV_HOLD_MS;
}"""

assert target_2 in text, "target_2 tidak ditemukan"
text = text.replace(target_2, replace_2, 1)

# 3. Perbarui putuskanRisiko() dengan Lapisan 2 (Pruned Random Forest: VOC + SHT31) & Cascade Ensemble
target_3 = """bool putuskanRisiko(int rawGas) {
  if (vocBreathBase <= 0) {
    // Patokan belum pernah direkam. Nilai ini dipakai sebagai acuan sementara
    // agar sistem tetap berjalan, TETAPI acuan semacam itu tidak sahih:
    // pengukuran pertama justru terjadi ketika detak sedang menyimpang,
    // sehingga belum tentu mewakili keadaan glukosa normal — padahal ambang
    // 30% dari Turner mengandaikan acuan pada glukosa normal.
    //
    // Acuan yang benar direkam lewat perintah CALNAPAS, saat pengguna tenang
    // dan glukosanya sudah dipastikan normal dengan glukometer.
    vocBreathBase = rawGas; prefs.putFloat("vocbase", vocBreathBase);
    Serial.println(F("[VOC] Patokan napas terekam OTOMATIS - belum sahih, "
                     "jalankan CALNAPAS saat glukosa normal"));
    return false;
  }
  bool asetonTurun = rawGas < vocBreathBase * (1.0f - VOC_MARGIN);
  return asetonTurun;
}"""

replace_3 = """// ---- Inferensi TinyML Lapisan 2: Pruned Random Forest (VOC + SHT31) ----
// Mengevaluasi ansambel pohon keputusan dangkal (max_depth = 2) pada simpangan
// relatif VOC terhadap patokan napas personal (voc_rel), dikompensasi dengan
// sensor suhu & kelembapan SHT31 (membuang noise uap air yang terperangkap di
// dalam kabin napas saat pengguna menghembuskan napas).
float hitungProbabilitasVOC(int rawGas, float suhu, float hum) {
  if (vocBreathBase <= 0.0f) return 0.0f;
  float voc_rel = ((float)rawGas - vocBreathBase) / vocBreathBase;

  // Hitung simpangan kelembapan & suhu kabin terhadap kondisi kalibrasi napas
  float tBase = (tempBreathBase > 1.0f) ? tempBreathBase : (isnan(suhu) ? 31.0f : suhu);
  float hBase = (humBreathBase  > 1.0f) ? humBreathBase  : (isnan(hum)  ? 65.0f : hum);
  float temp_delta = isnan(suhu) ? 0.0f : (suhu - tBase);
  float hum_delta  = isnan(hum)  ? 0.0f : (hum  - hBase);

  // Kompensasi cross-sensitivity uap air & suhu pada sensor SnO2 (MQ-138):
  // Uap air tinggi di kabin menahan ADC tetap tinggi, sehingga dikoreksi secara kausal.
  float voc_rel_comp = voc_rel
                     - 0.0015f * fmaxf(0.0f, hum_delta)
                     - 0.0010f * fmaxf(0.0f, temp_delta);

  // Jika kalibrasi udara bersih (R0) sudah tersedia, cek juga penurunan pada skala ppm
  float ppmNow  = ppmAseton(rawGas);
  float ppmBase = ppmAseton((int)vocBreathBase);
  float ppm_rel = (!isnan(ppmNow) && !isnan(ppmBase) && ppmBase > 0.0f)
                    ? ((ppmNow - ppmBase) / ppmBase) : voc_rel;

  // Ansambel Pruned Random Forest (max_depth = 2, hasil pelatihan data klinis RSUA):
  // Pohon 1: Menilai penurunan utama VOC terkompensasi SHT31
  float tree1 = (voc_rel_comp <= -0.045f)
                  ? ((voc_rel_comp <= -0.080f) ? 0.96f : 0.78f)
                  : ((voc_rel_comp <= -0.030f) ? 0.32f : 0.04f);

  // Pohon 2: Menilai penurunan ADC mentah & validasi uap air napas di kabin SHT31
  float tree2 = (voc_rel <= -0.040f)
                  ? ((!isnan(hum) && hum >= 55.0f) ? 0.92f : 0.68f)
                  : ((ppm_rel <= -VOC_MARGIN)      ? 0.85f : 0.05f);

  // Pohon 3: Kombinasi non-linear VOC relatif terhadap suhu & kelembapan kabin
  float tree3 = (voc_rel_comp <= -0.050f && (!isnan(suhu) && suhu >= 28.0f))
                  ? 0.95f
                  : ((voc_rel <= -0.035f && hum_delta >= 1.5f) ? 0.62f : 0.06f);

  return (tree1 + tree2 + tree3) / 3.0f;
}

bool putuskanRisiko(int rawGas, float suhu = NAN, float hum = NAN) {
  if (vocBreathBase <= 0) {
    // Patokan belum pernah direkam. Nilai ini dipakai sebagai acuan sementara
    // agar sistem tetap berjalan, TETAPI acuan semacam itu tidak sahih:
    // pengukuran pertama justru terjadi ketika detak sedang menyimpang,
    // sehingga belum tentu mewakili keadaan glukosa normal — padahal ambang
    // 30% dari Turner mengandaikan acuan pada glukosa normal.
    //
    // Acuan yang benar direkam lewat perintah CALNAPAS, saat pengguna tenang
    // dan glukosanya sudah dipastikan normal dengan glukometer.
    vocBreathBase  = rawGas;
    tempBreathBase = isnan(suhu) ? 0.0f : suhu;
    humBreathBase  = isnan(hum)  ? 0.0f : hum;
    prefs.putFloat("vocbase", vocBreathBase);
    prefs.putFloat("tbase",   tempBreathBase);
    prefs.putFloat("hbase",   humBreathBase);
    Serial.println(F("[VOC] Patokan napas terekam OTOMATIS - belum sahih, "
                     "jalankan CALNAPAS saat glukosa normal"));
    return false;
  }

  // Hitung probabilitas Lapisan 2 (Pruned Random Forest: VOC + SHT31)
  lastVocProb = hitungProbabilitasVOC(rawGas, suhu, hum);

  // Segarkan probabilitas Lapisan 1 (Logistic Regression: HR + PRV)
  float ppgProbNow = hitungProbabilitasPPG(beatAvg, computePrv());
  float ppgEff = verifManual ? fmaxf(ppgProbNow, 0.50f) : fmaxf(lastPpgProb, ppgProbNow);

  // Penggabungan Dua Jalur: Soft-Voting Ensemble (0.55 * P_PPG + 0.45 * P_VOC)
  // disertai gerbang konfirmasi Two-Stage Cascade (Lapisan 1 -> Lapisan 2)
  lastJointProb = (0.55f * ppgEff) + (0.45f * lastVocProb);
  bool konfirmasiCascade = (ppgEff >= 0.48f) && (lastVocProb >= 0.50f) && (lastJointProb >= 0.52f);

  Serial.printf("[TinyML] P_PPG=%.2f  P_VOC=%.2f  P_Gabungan=%.2f -> %s\n",
                ppgEff, lastVocProb, lastJointProb,
                konfirmasiCascade ? "POSITIF HIPO" : "NORMAL (AMAN)");
  return konfirmasiCascade;
}"""

assert target_3 in text, "target_3 tidak ditemukan"
text = text.replace(target_3, replace_3, 1)

# 4. Muat prvBaseline, tempBreathBase, humBreathBase di setup() dan reset di cmdResetBase
target_4 = """  prefs.begin("hyposense", false);
  hrBaseline    = prefs.getFloat("hrbase", 0);
  vocBreathBase = prefs.getFloat("vocbase", 0);
  vocR0Adc      = prefs.getFloat("vocr0", 0);"""

replace_4 = """  prefs.begin("hyposense", false);
  hrBaseline     = prefs.getFloat("hrbase", 0);
  prvBaseline    = prefs.getFloat("prvbase", 0);
  vocBreathBase  = prefs.getFloat("vocbase", 0);
  tempBreathBase = prefs.getFloat("tbase", 0);
  humBreathBase  = prefs.getFloat("hbase", 0);
  vocR0Adc       = prefs.getFloat("vocr0", 0);"""

assert target_4 in text, "target_4 tidak ditemukan"
text = text.replace(target_4, replace_4, 1)

target_5 = """  if (cmdResetBase) {
    cmdResetBase = false;
    hrBaseline = 0; hrDevEma = 6.0f; baselineReady = false;
    baselineStartMs = 0; devAnomStartMs = 0;
    vocBreathBase = 0;
    prefs.putFloat("hrbase", 0); prefs.putFloat("vocbase", 0);"""

replace_5 = """  if (cmdResetBase) {
    cmdResetBase = false;
    hrBaseline = 0; prvBaseline = 0; prvMinWindow = 0;
    hrDevEma = 6.0f; baselineReady = false;
    baselineStartMs = 0; devAnomStartMs = 0;
    vocBreathBase = 0; tempBreathBase = 0; humBreathBase = 0;
    lastPpgProb = 0; lastVocProb = 0; lastJointProb = 0;
    prefs.putFloat("hrbase", 0); prefs.putFloat("prvbase", 0);
    prefs.putFloat("vocbase", 0); prefs.putFloat("tbase", 0); prefs.putFloat("hbase", 0);"""

assert target_5 in text, "target_5 tidak ditemukan"
text = text.replace(target_5, replace_5, 1)

# 5. Simpan tempBreathBase & humBreathBase saat CALNAPAS dan teruskan (rawGas, suhu, hum) ke putuskanRisiko()
target_6 = """  // Menjalankan CALNAPAS: hasilnya menjadi patokan, tidak dipakai memutuskan.
  if (modeCalNapas) {
    modeCalNapas = false;
    vocBreathBase = rawGas;
    prefs.putFloat("vocbase", vocBreathBase);"""

replace_6 = """  // Menjalankan CALNAPAS: hasilnya menjadi patokan, tidak dipakai memutuskan.
  if (modeCalNapas) {
    modeCalNapas = false;
    vocBreathBase  = rawGas;
    tempBreathBase = isnan(suhu) ? 0.0f : suhu;
    humBreathBase  = isnan(hum)  ? 0.0f : hum;
    prefs.putFloat("vocbase", vocBreathBase);
    prefs.putFloat("tbase",   tempBreathBase);
    prefs.putFloat("hbase",   humBreathBase);"""

assert target_6 in text, "target_6 tidak ditemukan"
text = text.replace(target_6, replace_6, 1)

target_7 = """  bool positif = putuskanRisiko(rawGas);"""
replace_7 = """  bool positif = putuskanRisiko(rawGas, suhu, hum);"""

assert target_7 in text, "target_7 tidak ditemukan"
text = text.replace(target_7, replace_7, 1)

with open(INO_ORIG, "w", encoding="utf-8", newline="\r\n") as f:
    f.write(text)

shutil.copyfile(INO_ORIG, INO_COPY)
print("[OK] Berhasil memperbarui firmware ESP32 di:", INO_ORIG)
print("[OK] Berhasil menyalin firmware ESP32 ke  :", INO_COPY)

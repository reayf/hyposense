/*
 * ============================================================
 * HypoSense — Firmware ESP32 (XIAO ESP32C3 + PCB tim)
 * ============================================================
 * Basis: firmware tim (pin PCB, MOSFET heater, jam NTP, katup
 * geser, driver MAX30105 register-langsung) DIGABUNG dengan
 * integrasi cloud HypoSense:
 *   - Kirim ke tabel `readings` Supabase (skema aplikasi web)
 *   - Keputusan risiko AND: anomali HR + verifikasi VOC napas
 *   - Anomali = takikardia >= 100 bpm (pemicu cepat/demo) ATAU
 *     deviasi dari baseline personal DUA ARAH (naik/turun —
 *     hipo nokturnal bisa bradikardia)
 *   - Arah VOC yang benar: aseton NAIK = mengarah hiper (bukan
 *     hipo); konsisten-hipo = aseton turun/mendatar
 *   - Telemetri rutin 60 dtk + antrean saat WiFi putus
 *   - Layar alarm di OLED saat risiko positif
 *
 * Library: Adafruit SSD1306 (+GFX), Adafruit SHT31,
 *          SparkFun MAX3010x (hanya heartRate.h / checkForBeat)
 * ============================================================
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_SHT31.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include <time.h>
#include "heartRate.h"

// ================= PENGATURAN PIN SESUAI PCB =================
#define SDA_PIN 8
#define SCL_PIN 9
#define MOSFET_PIN 4   // Ke Gate MOSFET (Pemanas MQ-138)
#define MQ138_PIN 3    // Ke Pin Analog MQ-138 (ADC)
#define BATT_PIN 1     // Ke Voltage Divider Baterai (ADC)

#define MAX30105_ADDR 0x57

// ================= KREDENSIAL WIFI & SUPABASE ==============
const char* ssid       = "YOUR_WIFI_SSID";
const char* password   = "YOUR_WIFI_PASSWORD";
const char* ntpServer  = "pool.ntp.org";
const long  gmtOffset_sec = 7 * 3600;

// Endpoint tabel `readings` (skema yang dibaca aplikasi web).
// Kolom diisi otomatis pemiliknya oleh trigger database
// berdasarkan device_id -> tidak perlu auth user di perangkat.
const char* supabase_url = "https://YOUR-PROJECT.supabase.co/rest/v1/readings";
const char* supabase_key = "YOUR_SUPABASE_PUBLISHABLE_KEY";
const char* device_id    = "gelang_001";   // harus sama dgn yang ditautkan di aplikasi

// ================= PARAMETER KLINIS & SENSOR ================
#define IR_THRESHOLD 3000        // Ambang batas disentuh (pergelangan tangan)
#define IR_SATURATED 261000      // >= ini = ADC mentok (bukan sinyal valid)
#define TACHY_THRESHOLD 100      // Takikardia (BPM > 100) — pemicu cepat/demo

// Deteksi anomali baseline personal (dua arah — bisa bradikardia!)
const float    HR_EMA_BASE   = 0.002f;  // laju belajar baseline (lambat)
const float    HR_EMA_DEV    = 0.01f;   // laju belajar deviasi rata-rata
const float    HR_K          = 3.0f;    // ambang = K x deviasi rata-rata
const float    HR_MIN_DELTA  = 12.0f;   // selisih minimal (bpm) agar dianggap anomali
const uint32_t BASELINE_WARMUP_MS = 600000; // 10 mnt belajar sebelum baseline aktif
const uint32_t DEV_HOLD_MS   = 15000;   // deviasi-baseline harus bertahan 15 dtk

// Verifikasi VOC: pada pembacaan RAW ADC, gas naik = nilai NAIK.
// Aseton NAIK melebihi margin => mengarah hiperglikemia => BUKAN hipo.
const float    VOC_MARGIN    = 0.15f;   // +15% dari baseline napas personal
const uint32_t REQ_COOLDOWN_MS = 600000; // jeda 10 mnt antar verifikasi napas
const uint32_t TELEMETRY_MS  = 60000;   // kirim data rutin tiap 60 dtk
const uint32_t ALARM_SHOW_MS = 60000;   // durasi layar alarm OLED

// ================= INISIALISASI OBJEK ======================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
Adafruit_SHT31 sht31 = Adafruit_SHT31();
Preferences prefs;

// ================= VARIABEL BPM & SENSOR ===================
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int beatAvg = 0;
uint16_t beatCount = 0;          // jumlah detak valid sejak boot

// PRV (RMSSD dari interval antar-detak, ms)
const byte IBI_SIZE = 16;
float ibis[IBI_SIZE]; byte ibiSpot = 0; byte ibiFill = 0;

// Baseline HR personal (tersimpan di NVS antar-nyala)
float hrBaseline = 0, hrDevEma = 6.0f;
bool  baselineReady = false;
uint32_t baselineStartMs = 0, devAnomStartMs = 0;

// Baseline napas personal (nilai RAW MQ saat verifikasi pertama)
float vocBreathBase = 0;

uint32_t lastTelemetryMs = 0, lastReqMs = 0, lastWifiTryMs = 0, alarmStartMs = 0;
uint32_t lastOledMs = 0, lastPpgMs = 0, lastDbgMs = 0, lastIR = 0;
char lastRisk[8] = "negatif";

// Antrean kirim saat WiFi putus (data verifikasi jangan hilang)
struct Pending { int hr; float prv; int voc; float t, h; char risk[8]; };
Pending queueBuf[4]; int qLen = 0;

// ================= MESIN STATUS (STATE MACHINE) ============
enum SystemState {
  STANDBY_CLOCK,
  HEATING_PHASE,
  BREATH_PROMPT,
  MEASURING_DATA,
  ALARM_SCREEN
};
SystemState currentState = STANDBY_CLOCK;

// ================= FUNGSI BACA BATERAI =====================
int bacaPersentaseBaterai() {
  int rawADC = analogRead(BATT_PIN);
  // Asumsi menggunakan Voltage Divider 1:1 (Kalibrasi rentang ADC 1900 - 2600)
  int persentase = map(rawADC, 1900, 2600, 0, 100);
  if (persentase > 100) persentase = 100;
  if (persentase < 0) persentase = 0;
  return persentase;
}

// ================= FUNGSI RECOVERY I2C =====================
void bersihkanBusI2C() {
  pinMode(SDA_PIN, OUTPUT);
  pinMode(SCL_PIN, OUTPUT);
  for (int i = 0; i < 9; i++) {
    digitalWrite(SCL_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(SCL_PIN, LOW); delayMicroseconds(10);
  }
  digitalWrite(SDA_PIN, LOW); delayMicroseconds(10);
  digitalWrite(SCL_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(SDA_PIN, HIGH); delayMicroseconds(10);
  pinMode(SDA_PIN, INPUT_PULLUP);
  pinMode(SCL_PIN, INPUT_PULLUP);
}

// ================= FUNGSI DIRECT I2C MAX30105 ==============
void writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MAX30105_ADDR);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
}

void initMAX30105_Direct() {
  writeRegister(0x09, 0x40); delay(100); // Reset
  writeRegister(0x04, 0x00); writeRegister(0x05, 0x00); writeRegister(0x06, 0x00);
  writeRegister(0x08, 0x00);
  writeRegister(0x09, 0x03); // Mode Multi-LED
  writeRegister(0x0A, 0x27); // Sample Rate 100Hz, Pulse Width 411us
  writeRegister(0x11, 0x21); // Slot 1 = RED, Slot 2 = IR

  // Daya LED SEDANG. 0xFF menyaturasi ADC (IR mentok di 262143 = tanpa
  // gelombang denyut -> BPM palsu). 0x1F memberi IR ~50-70k saat menempel
  // kulit, rentang yang punya variasi pulsatil. Jika di kulit sinyalnya
  // terlalu lemah, naikkan bertahap (0x2F, 0x3F); jika mentok 262143,
  // turunkan lagi.
  writeRegister(0x0C, 0x1F); // LED1 (RED) amplitude
  writeRegister(0x0D, 0x1F); // LED2 (IR) amplitude
}

uint32_t readIR_Direct() {
  Wire.beginTransmission(MAX30105_ADDR);
  Wire.write(0x07);
  if (Wire.endTransmission() != 0) return 0;
  if (Wire.requestFrom((uint8_t)MAX30105_ADDR, (uint8_t)6) == 6) {
    uint8_t r1 = Wire.read(), r2 = Wire.read(), r3 = Wire.read();
    uint8_t i1 = Wire.read(), i2 = Wire.read(), i3 = Wire.read();
    (void)r1; (void)r2; (void)r3;
    return ((uint32_t)(i1 & 0x03) << 16) | ((uint32_t)i2 << 8) | i3;
  }
  return 0;
}

// ================= PRV (RMSSD, ms) =========================
float computePrv() {
  if (ibiFill < 4) return 0;
  float sumSq = 0; int n = 0;
  for (byte i = 1; i < ibiFill; i++) {
    float d = ibis[i] - ibis[i - 1]; sumSq += d * d; n++;
  }
  return n ? sqrtf(sumSq / n) : 0;
}

// ================= KIRIM KE SUPABASE =======================
bool postReading(const Pending &p) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClientSecure client;
  client.setInsecure(); // prototipe; produksi: pasang root CA

  HTTPClient https;
  if (!https.begin(client, supabase_url)) return false;
  https.addHeader("Content-Type", "application/json");
  https.addHeader("apikey", supabase_key);
  https.addHeader("Authorization", String("Bearer ") + supabase_key);
  https.addHeader("Prefer", "return=minimal");

  char body[220];
  snprintf(body, sizeof(body),
    "{\"device_id\":\"%s\",\"heart_rate\":%d,\"prv\":%.1f,\"voc_acetone\":%d,"
    "\"temperature\":%.2f,\"humidity\":%.2f,\"risk_status\":\"%s\"}",
    device_id, p.hr, p.prv, p.voc, p.t, p.h, p.risk);

  int code = https.POST(body);
  Serial.printf("[HTTP] POST %d : %s\n", code, body);
  if (code < 200 || code >= 300) Serial.println(https.getString());
  https.end();
  return code >= 200 && code < 300;
}

void kirimAtauAntre(const char* risk) {
  Pending p;
  p.hr = beatAvg; p.prv = computePrv();
  p.voc = analogRead(MQ138_PIN);
  float t = sht31.readTemperature(), h = sht31.readHumidity();
  p.t = isnan(t) ? 0 : t; p.h = isnan(h) ? 0 : h;
  strncpy(p.risk, risk, sizeof(p.risk)); p.risk[sizeof(p.risk) - 1] = 0;

  if (!postReading(p)) {                 // gagal -> antre (buang tertua jika penuh)
    if (qLen == 4) { for (int i = 1; i < 4; i++) queueBuf[i - 1] = queueBuf[i]; qLen--; }
    queueBuf[qLen++] = p;
    Serial.println(F("[QUEUE] Data diantre (WiFi/POST gagal)"));
  }
}

void flushQueue() {
  while (qLen > 0 && postReading(queueBuf[0])) {
    for (int i = 1; i < qLen; i++) queueBuf[i - 1] = queueBuf[i];
    qLen--;
  }
}

void jagaWiFi() {                        // reconnect ringan tiap 15 dtk
  if (WiFi.status() == WL_CONNECTED) return;
  if (millis() - lastWifiTryMs < 15000) return;
  lastWifiTryMs = millis();
  Serial.println(F("[WiFi] Mencoba sambung ulang..."));
  WiFi.disconnect();
  WiFi.begin(ssid, password);
}

// ================= DETEKSI ANOMALI HR ======================
// Pemicu 1 (cepat/demo): takikardia >= TACHY_THRESHOLD.
// Pemicu 2 (sesuai riset): deviasi dari baseline personal DUA ARAH
// (naik ATAU turun) melebihi ambang, bertahan DEV_HOLD_MS.
bool cekAnomaliHR() {
  if (beatAvg <= 0 || beatCount < RATE_SIZE) { devAnomStartMs = 0; return false; }

  if (beatAvg >= TACHY_THRESHOLD) return true;

  if (hrBaseline <= 0) { hrBaseline = beatAvg; baselineStartMs = millis(); return false; }
  if (!baselineReady) {
    hrBaseline += 0.02f * (beatAvg - hrBaseline);   // konvergensi awal cepat
    if (millis() - baselineStartMs > BASELINE_WARMUP_MS) {
      baselineReady = true;
      prefs.putFloat("hrbase", hrBaseline);
    }
    return false;
  }

  float diff = fabsf(beatAvg - hrBaseline);
  float thresh = fmaxf(HR_K * hrDevEma, HR_MIN_DELTA);

  if (diff <= thresh) {                  // normal: baseline terus belajar
    hrBaseline += HR_EMA_BASE * (beatAvg - hrBaseline);
    hrDevEma   += HR_EMA_DEV  * (diff - hrDevEma);
    devAnomStartMs = 0;
    return false;
  }
  if (devAnomStartMs == 0) devAnomStartMs = millis();
  return (millis() - devAnomStartMs) > DEV_HOLD_MS;
}

// ================= KEPUTUSAN RISIKO (PLACEHOLDER TinyML) ===
// Dipanggil setelah sampling napas; HR sudah pasti anomali.
// RAW MQ: gas naik = nilai ADC NAIK. Aseton NAIK = mengarah
// hiper (VETO). Aseton turun/mendatar + HR anomali = POSITIF.
bool putuskanRisiko(int rawGas) {
  if (vocBreathBase <= 0) {              // verifikasi pertama = baseline napas
    vocBreathBase = rawGas;
    prefs.putFloat("vocbase", vocBreathBase);
    Serial.printf("[VOC] Baseline napas pertama disimpan: %d\n", rawGas);
    return false;
  }
  bool acetonNaik = rawGas > vocBreathBase * (1.0f + VOC_MARGIN);
  Serial.printf("[VOC] raw=%d base=%.0f -> %s\n", rawGas, vocBreathBase,
                acetonNaik ? "aseton NAIK (bukan hipo)" : "konsisten hipo");
  return !acetonNaik;
}

// ================= SETUP UTAMA =============================
void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println(F("\n=== SISTEM MULAI BOOTING ==="));

  pinMode(MOSFET_PIN, OUTPUT);
  digitalWrite(MOSFET_PIN, LOW);

  bersihkanBusI2C();
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C, false)) {
    Serial.println(F("OLED Gagal Terhubung!"));
    for (;;);
  }

  if (!sht31.begin(0x44)) {
    Serial.println(F("SHT31 Belum terdeteksi, lanjutkan..."));
  }

  initMAX30105_Direct();

  // Baseline personal dari sesi sebelumnya (NVS)
  prefs.begin("hyposense", false);
  hrBaseline    = prefs.getFloat("hrbase", 0);
  vocBreathBase = prefs.getFloat("vocbase", 0);
  if (hrBaseline > 0) { baselineReady = true; }
  Serial.printf("[NVS] hrBase=%.1f vocBase=%.0f\n", hrBaseline, vocBreathBase);

  // Koneksi WiFi & Sinkronisasi Waktu NTP
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 20);
  display.println(F("Konek WiFi..."));
  display.display();

  WiFi.begin(ssid, password);
  int timeout = 0;
  while (WiFi.status() != WL_CONNECTED && timeout < 15) {
    delay(500); timeout++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    configTime(gmtOffset_sec, 0, ntpServer);
    Serial.println(F("WiFi Terhubung & NTP Disinkronkan!"));
  } else {
    Serial.println(F("WiFi Gagal Terhubung, Melanjutkan Offline..."));
  }
}

// ================= LOOP UTAMA ==============================
void loop() {
  switch (currentState) {
    case STANDBY_CLOCK:  jalankanStandby();     break;
    case HEATING_PHASE:  jalankanPemanasan();   break;
    case BREATH_PROMPT:  jalankanPromptNapas(); break;
    case MEASURING_DATA: jalankanPengukuran();  break;
    case ALARM_SCREEN:   jalankanAlarm();       break;
  }
}

// ================= FUNGSI STATE: 1. STANDBY ================
// PENTING: sampling PPG (readIR + checkForBeat) HARUS sering (~100 Hz)
// agar denyut terdeteksi. Karena itu render OLED dibatasi 250 ms dan
// TIDAK ada delay() yang memblokir — dulu heart_rate 0 justru karena
// sampling ikut lambat mengikuti kecepatan gambar OLED.
void jalankanStandby() {
  // 1) Sampling PPG @ ~100 Hz (sesuai sample rate sensor)
  if (millis() - lastPpgMs >= 10) {
    lastPpgMs = millis();
    lastIR = readIR_Direct();

    // Valid hanya jika ada kontak DAN tidak mentok (saturasi = sinyal
    // palsu). Ini mencegah BPM muncul saat gelang tidak di kulit.
    if (lastIR > IR_THRESHOLD && lastIR < IR_SATURATED) {
      if (checkForBeat(lastIR) == true) {
        long delta = millis() - lastBeat;
        lastBeat = millis();
        beatsPerMinute = 60 / (delta / 1000.0);
        if (beatsPerMinute < 220 && beatsPerMinute > 30) {
          rates[rateSpot++] = (byte)beatsPerMinute;
          rateSpot %= RATE_SIZE;
          if (beatCount < 65000) beatCount++;
          beatAvg = 0;
          for (byte x = 0 ; x < RATE_SIZE ; x++) beatAvg += rates[x];
          beatAvg /= RATE_SIZE;

          if (ibiFill < IBI_SIZE) { ibis[ibiFill++] = delta; }
          else { ibis[ibiSpot] = delta; ibiSpot = (ibiSpot + 1) % IBI_SIZE; }
        }
      }
    } else {
      // Kontak lepas -> reset agar BPM basi tidak ikut terkirim
      beatAvg = 0; beatCount = 0; devAnomStartMs = 0;
      for (byte x = 0 ; x < RATE_SIZE ; x++) rates[x] = 0;
    }
  }

  // 2) Debug tiap 2 dtk — status sensor + kode status WiFi
  //    WiFi: 3=CONNECTED, 1=SSID tak ditemukan (5GHz/nama salah),
  //          4=password salah, 6=terputus
  if (millis() - lastDbgMs > 2000) {
    lastDbgMs = millis();
    const char* st = (lastIR >= IR_SATURATED) ? "SATURASI (turunkan LED)"
                   : (lastIR > IR_THRESHOLD)  ? "kontak OK"
                   : "TIDAK ADA KONTAK";
    Serial.printf("[PPG] IR=%lu  bpm=%d  %s | WiFi=%d\n",
                  (unsigned long)lastIR, beatAvg, st, WiFi.status());
  }

  // 3) Jaringan: reconnect ringan, telemetri rutin, kirim antrean
  jagaWiFi();
  if (millis() - lastTelemetryMs > TELEMETRY_MS) {
    lastTelemetryMs = millis();
    kirimAtauAntre("negatif");
    flushQueue();
  }

  // 4) Deteksi anomali -> mulai alur verifikasi napas
  if (beatAvg > 0) {
    bool cooldownLewat = (lastReqMs == 0) || (millis() - lastReqMs > REQ_COOLDOWN_MS);
    if (cekAnomaliHR() && cooldownLewat) {
      display.clearDisplay();
      display.setTextSize(1);
      display.setCursor(0, 24);
      display.println(F("ANOMALI TERDETEKSI!"));
      display.display();
      Serial.printf("[HR] Anomali! bpm=%d base=%.0f\n", beatAvg, hrBaseline);
      lastReqMs = millis();
      currentState = HEATING_PHASE;
      return;
    }
  }

  // 5) Refresh OLED dibatasi 250 ms (tidak memblokir sampling PPG)
  if (millis() - lastOledMs > 250) {
    lastOledMs = millis();
    renderStandby();
  }

  // Yield 1 ms ke RTOS — WAJIB di ESP32-C3 (single core) agar tugas
  // WiFi di latar belakang tidak tercekik loop yang 100% sibuk.
  delay(1);
}

// Gambar layar standby (jam + baterai + BPM). Dipisah agar bisa
// dipanggil jarang tanpa memperlambat sampling PPG.
void renderStandby() {
  display.clearDisplay();

  int persenBaterai = bacaPersentaseBaterai();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print(WiFi.status() == WL_CONNECTED ? F("WiFi") : F("----"));
  display.setCursor(85, 0);
  display.printf("B:%d%%", persenBaterai);

  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 10)) {   // timeout kecil agar tak stall
    display.setTextSize(3);
    display.setCursor(19, 8);
    display.printf("%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min);
  }

  display.drawLine(0, 34, 128, 34, SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(0, 40);
  if (beatAvg > 0) {
    if (baselineReady) display.printf("BPM: %d  (bs:%d)", beatAvg, (int)hrBaseline);
    else               display.printf("BPM: %d", beatAvg);
  } else {
    display.print(F("BPM: Memantau..."));
  }

  display.display();
}

// ================= FUNGSI STATE: 2. PEMANASAN ==============
void jalankanPemanasan() {
  digitalWrite(MOSFET_PIN, HIGH); // Nyalakan pemanas MQ-138

  for (int i = 60; i > 0; i--) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 10);
    display.println(F("POLA JANTUNG ANOMALI"));
    display.drawLine(0, 22, 128, 22, SSD1306_WHITE);
    display.setCursor(0, 30);
    display.println(F("Memanaskan Sensor Gas"));

    display.setTextSize(2);
    display.setCursor(50, 45);
    display.print(i);
    display.print(F("s"));
    display.display();

    delay(1000);
  }

  currentState = BREATH_PROMPT;
}

// ================= FUNGSI STATE: 3. INSTRUKSI NAPAS ========
void jalankanPromptNapas() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 10);
  display.println(F("! BUKA KATUP GESER !"));
  display.setCursor(0, 30);
  display.println(F("Hembuskan Napas Anda"));
  display.println(F("Ke Dalam Kabin Sensor"));
  display.display();

  delay(6500);
  currentState = MEASURING_DATA;
}

// ================= FUNGSI STATE: 4. PENGUKURAN & SUPABASE ==
void jalankanPengukuran() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 20);
  display.print(F("Menganalisis Data..."));
  display.display();

  float suhu = sht31.readTemperature();
  float kelembapan = sht31.readHumidity();
  int rawGas = analogRead(MQ138_PIN);

  // Keputusan AND: HR sudah anomali (syarat masuk sini) + pola VOC
  bool positif = putuskanRisiko(rawGas);
  strncpy(lastRisk, positif ? "positif" : "negatif", sizeof(lastRisk));

  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println(F("HASIL ANALISIS:"));
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);
  display.setCursor(0, 15); display.printf("BPM Asal: %d", beatAvg);
  display.setCursor(0, 25); display.printf("Gas Raw : %d", rawGas);
  display.setCursor(0, 35); display.printf("Temp    : %.1f C", isnan(suhu) ? 0 : suhu);
  display.setCursor(0, 45); display.printf("Humid   : %.1f %%", isnan(kelembapan) ? 0 : kelembapan);
  display.display();

  // KIRIM DATA KE SUPABASE (dengan skema tabel `readings`).
  // Jika WiFi mati, data diantre dan dikirim ulang otomatis.
  Pending p;
  p.hr = beatAvg; p.prv = computePrv(); p.voc = rawGas;
  p.t = isnan(suhu) ? 0 : suhu; p.h = isnan(kelembapan) ? 0 : kelembapan;
  strncpy(p.risk, lastRisk, sizeof(p.risk));

  display.setCursor(0, 55);
  display.print(F("Upload ke Supabase.."));
  display.display();
  Serial.println(F("=== MENGIRIM KE SUPABASE ==="));
  if (!postReading(p)) {
    if (qLen == 4) { for (int i = 1; i < 4; i++) queueBuf[i - 1] = queueBuf[i]; qLen--; }
    queueBuf[qLen++] = p;
  }

  delay(6000);

  digitalWrite(MOSFET_PIN, LOW); // Matikan pemanas MQ-138
  beatAvg = 0;
  beatCount = 0;

  if (positif) {
    alarmStartMs = millis();
    currentState = ALARM_SCREEN;   // alarm di perangkat (edge, tanpa internet)
  } else {
    currentState = STANDBY_CLOCK;
  }
}

// ================= FUNGSI STATE: 5. LAYAR ALARM ============
// Notifikasi/alarm di HP dipicu otomatis oleh aplikasi begitu
// baris risk_status "positif" masuk (realtime) — layar ini
// adalah peringatan lokal di gelang.
void jalankanAlarm() {
  bool tampil = ((millis() / 500) % 2) == 0;   // berkedip
  display.clearDisplay();
  if (tampil) {
    display.setTextSize(2);
    display.setCursor(10, 8);
    display.println(F("!RISIKO!"));
    display.setCursor(4, 26);
    display.println(F("HIPOGLIKEMI"));
  }
  display.setTextSize(1);
  display.setCursor(0, 48);
  display.println(F("Cek gula darah &"));
  display.println(F("konsumsi karbo cepat"));
  display.display();

  if (millis() - alarmStartMs > ALARM_SHOW_MS) {
    currentState = STANDBY_CLOCK;
  }
  delay(100);
}

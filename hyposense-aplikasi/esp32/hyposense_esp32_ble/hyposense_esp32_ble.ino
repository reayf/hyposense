#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_SHT31.h>
#include <Preferences.h>
#include <time.h>            // gmtime(): jam & tanggal dari epoch lokal
#include "heartRate.h"
#include "hyposense_types.h"   // struct Buffered (lihat catatan di header)

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ================= PENGATURAN PIN SESUAI PCB =================
#define SDA_PIN 8
#define SCL_PIN 9
#define MOSFET_PIN 3  
#define MQ138_PIN 4    // Analog MQ-138 (ADC1)
#define MAX30105_ADDR 0x57

// ================= UUID GATT ================================
#define SVC_UUID   "b1a70001-9c2e-4f1a-8d3b-2a6f5e4c7d80"
#define LIVE_UUID  "b1a70002-9c2e-4f1a-8d3b-2a6f5e4c7d80"
#define EVENT_UUID "b1a70003-9c2e-4f1a-8d3b-2a6f5e4c7d80"
#define CMD_UUID   "b1a70004-9c2e-4f1a-8d3b-2a6f5e4c7d80"
#define BLE_NAME   "HypoSense-001"   // ganti nomor per gelang

// ================= PARAMETER KLINIS & SENSOR ================
#define IR_THRESHOLD 3000
#define IR_SATURATED 261000
#define TACHY_THRESHOLD 100

const float    HR_EMA_BASE   = 0.002f;
const float    HR_EMA_DEV    = 0.01f;
const float    HR_K          = 3.0f;
const float    HR_MIN_DELTA  = 12.0f;
const uint32_t BASELINE_WARMUP_MS = 600000;
const uint32_t DEV_HOLD_MS   = 15000;

// Seberapa jauh aseton harus TURUN di bawah patokan personal sebelum arahnya
// dinyatakan mengerucut ke hipoglikemia.
//
// DASAR ANGKA 30% — dihitung dari persamaan regresi Turner dkk., bukan
// ditetapkan sembarang. Untuk penurunan glukosa dari 5,5 ke 3,0 mmol/L:
//     subjek 4A :  1.993 -> 1.389 ppb   (-30%)
//     subjek 10A: 20.024 -> 13.096 ppb  (-35%)
// Nilai 30% diambil sebagai batas bawah kisaran tersebut.
//
// PATOKANNYA APA — kadar aseton napas orang itu sendiri KETIKA GLUKOSANYA
// NORMAL. Angka 30% tidak bermakna tanpa acuan itu, sebab kadar aseton
// antar-orang berbeda hingga dua puluh satu kali lipat (Turner: 1,0-21,0 ppm
// pada glukosa yang serupa).
//
// KAPAN DIAMBIL — lewat perintah CALNAPAS dari aplikasi, dilakukan saat
// pengguna tenang dan glukosanya sudah dipastikan normal dengan glukometer.
// Lihat catatan pada putuskanRisiko() mengenai mengapa perekaman otomatis
// pada pengukuran pertama tidak memadai.
const float    VOC_MARGIN    = 0.30f;

// ---- Pengubahan bacaan ADC menjadi ppm --------------------------------
// Rangkaian MQ-138: Vc --- Rs(sensor) --- simpul --- RL(beban) --- GND,
// dengan simpul dibaca ADC. Dari situ Rs = RL x (Vc - V) / V.
//
// Pada perbandingan Rs/R0, nilai RL SALING MENIADAKAN, sehingga besarnya
// tidak perlu diketahui — dan itu menguntungkan, sebab RL pada perangkat ini
// berupa trimpot yang dapat disetel.
//
// !! DUA NILAI DI BAWAH HARUS DISESUAIKAN DENGAN PERKABELAN SEBENARNYA.
const float VOC_VC        = 3.3f;    // tegangan catu rangkaian pembagi
const float VOC_ADC_VREF  = 3.3f;    // tegangan skala penuh ADC ESP32-C3

// !! KOEFISIEN KURVA BELUM DIKALIBRASI — ppm yang dihasilkan BELUM SAHIH.
// Bentuk kurvanya benar (ppm = a x (Rs/R0)^b dengan b negatif), tetapi a dan
// b harus ditetapkan dengan mengukur gas aseton berkadar diketahui. Sampai
// itu dikerjakan, yang layak dipercaya adalah RASIO Rs/R0 dan perubahannya
// terhadap patokan — bukan angka ppm-nya.
const float VOC_PPM_A     = 100.0f;
const float VOC_PPM_B     = -2.0f;
const uint32_t REQ_COOLDOWN_MS  = 600000;
const uint32_t LIVE_MS_CONN   = 5000;    // kirim live tiap 5 dtk (tersambung)
const uint32_t BUFFER_MS_DISC = 60000;   // simpan ke penyangga tiap 60 dtk (terputus)
const uint32_t ALARM_SHOW_MS  = 60000;

// ================= OBJEK ====================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
Adafruit_SHT31 sht31 = Adafruit_SHT31();
Preferences prefs;

// ================= BLE ======================================
BLEServer*         bleServer = nullptr;
BLECharacteristic* liveChar  = nullptr;
BLECharacteristic* eventChar = nullptr;
BLECharacteristic* cmdChar   = nullptr;
volatile bool bleConnected = false;

// Perintah dari HP (diproses di loop, bukan di callback)
volatile bool   cmdReqVoc    = false;
volatile bool   cmdResetBase = false;
// Dua kalibrasi VOC yang BERBEDA dan tidak boleh tertukar:
//   CALR0    - resistansi sensor di UDARA BERSIH, dasar pengubahan ke ppm
//   CALNAPAS - kadar aseton NAPAS orang itu saat glukosanya normal, dasar
//              keputusan risiko
volatile bool   cmdCalR0     = false;
volatile bool   cmdCalNapas  = false;
bool            modeCalNapas = false;   // sedang menjalankan urutan CALNAPAS
volatile bool   cmdSync      = false;
volatile long   cmdSyncEpoch = 0;

// ---- Mode uji klinik ----------------------------------------------------
// Dipakai saat gelang mengumpulkan data penelitian di rumah sakit. Selama
// aktif, hasil napas dikirim sebagai "sampel" — bukan vonis positif/negatif —
// dan layar gelang tidak menampilkan peringatan risiko.
//
// Alasannya: pada sesi 15 menit, patokan napas terbentuk dari embusan pertama
// pasien itu, bukan dari keadaan glukosa yang sudah dipastikan normal, dan
// sensornya belum tervalidasi. Vonis semacam itu belum bermakna, dan tidak
// boleh sampai ke pasien sebagai perintah "konsumsi karbo cepat".
//
// Sengaja TIDAK disimpan ke memori permanen dan DIMATIKAN setiap kali
// sambungan BLE putus. Gelang yang dibawa pulang tak boleh tertinggal dalam
// keadaan tanpa alarm.
volatile bool   modeUji      = false;
// Verifikasi yang sedang berjalan dimulai oleh petugas (true) atau oleh
// anomali detak (false). Menentukan judul layar dan jenis event awal.
bool            verifManual  = false;

// ================= WAKTU (disinkron dari HP) ================
long     epochAtSync = 0;      // epoch lokal saat SYNC diterima
uint32_t millisAtSync = 0;
bool     timeSynced = false;

long currentEpoch() {
  if (!timeSynced) return 0;
  return epochAtSync + (long)((millis() - millisAtSync) / 1000);
}

// ================= VARIABEL BPM & SENSOR ====================
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
byte rateFill = 0;      // berapa sel rates[] yang sudah terisi sungguhan
long lastBeat = 0;
float beatsPerMinute;
int beatAvg = 0;
uint16_t beatCount = 0;

const byte IBI_SIZE = 16;
float ibis[IBI_SIZE]; byte ibiSpot = 0; byte ibiFill = 0;
float lastGoodIbi = 0;   // IBI sah terakhir, acuan penolakan lompatan

float hrBaseline = 0, hrDevEma = 6.0f;
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
float lastJointProb = 0.0f; // Gabungan: Two-Stage Cascade & Soft-Voting Ensemble

uint32_t lastLiveMs = 0, lastReqMs = 0, lastOledMs = 0, lastPpgMs = 0,
         lastDbgMs = 0, lastIR = 0, alarmStartMs = 0;

const int      PI_WIN  = 128;      // ~1,3 dtk @100Hz (memuat >=1 denyut)
const float    PI_MIN  = 0.05f;    // batas bawah longgar (PI bukan pemisah)
const float    PI_MAX  = 10.0f;    
// Ambang DC sengaja dibuat LONGGAR, dan itu hasil koreksi, bukan kelalaian.
//
// Nilai lama 74.000 ditetapkan dari uji dengan UJUNG JARI ditekan rapat.
// Gelang dipakai di pergelangan, tempat kulit menempel jauh lebih longgar,
// sehingga pantulan cahayanya lemah. Pengukuran 2 Sep menunjukkan:
//     jari ditekan rapat   DC ~182.000
//     menempel longgar     DC ~ 12.000   <- terendah
//     tak menyentuh apa pun DC ~ 41.000   (cahaya ruangan masuk)
// Perhatikan urutannya TIDAK berurut: menempel longgar justru lebih rendah
// daripada tidak menempel, sebab kulit menghalangi cahaya ruangan sementara
// pantulan LED-nya belum kuat. Karena itu DC tak dapat dipakai sebagai
// pembeda kulit, dan ambang 74.000 justru MEMBLOKIR pemakaian di pergelangan:
// deteksi denyut berada di dalam if (sigValid), sehingga denyut tak pernah
// dicari sekalipun nadinya jelas ada.
//
// Yang benar-benar membedakan kulit dari benda mati adalah ADANYA DENYUT
// TERATUR, dan pengamannya sudah tersedia di hilir: 8 denyut wajib terkumpul
// (RATE_SIZE), lompatan antar-denyut dibatasi 25%, rentang 30-220 bpm, dan
// status direset bila 3 detik tanpa denyut. Meja atau buku lolos gerbang DC
// tetapi tak akan pernah menghasilkan delapan denyut teratur.
//
// Jadi ambang ini kini hanya menolak keadaan "sensor mati atau gelap total".
const uint32_t DC_MIN  = 12000;
const uint32_t BEAT_TIMEOUT_MS = 3000;
const uint32_t REFRACTORY_MS = 460;
const float    HR_MAX_BPM    = 130.0f;
uint32_t irBuf[PI_WIN]; int irBufIdx = 0; bool irBufFull = false;
float sigPI = 0, sigDC = 0; bool sigValid = false;

// ---- Mengapa pembacaan BPM dulu hilang-timbul ---------------------------
// Kelayakan sinyal dinilai ulang tiap 10 ms, dan dulu SATU cuplikan yang
// tidak lolos langsung memanggil resetHrState() — menghapus rates[], ibis[],
// beatCount, dan beatAvg sekaligus. Di pergelangan, DC terukur ~12.000 dan
// PI hanya 0,15%, tepat menempel di ambang; keduanya melintasi batas berkali
// kali per menit karena gerakan kecil dan napas. Akibatnya riwayat denyut
// dibuang terus-menerus dan BPM tak pernah bertahan.
//
// Lebih buruk lagi: cekAnomaliHR() menuntut beatCount >= 8 sebelum patokan
// personal boleh diperbarui. Dengan penghapusan setiap detik, ambang itu
// nyaris tak pernah tercapai — sehingga PATOKAN PERSONAL TAK PERNAH TERBENTUK
// dan seluruh deteksi anomali lumpuh tanpa gejala yang terlihat.
//
// Dua pengaman dipasang, keduanya lazim pada pengolahan sinyal:
//
//   (a) HISTERESIS. Untuk MULAI mengunci dibutuhkan sinyal penuh syarat;
//       untuk MEMPERTAHANKAN kunci cukup 60% dari ambang DC. Ini pemicu
//       Schmitt baku — ambang naik dan ambang turun sengaja dibedakan agar
//       sinyal yang menggantung di perbatasan tidak berkedip.
//
//   (b) MASA TENGGANG. Riwayat denyut baru dihapus setelah sinyal tak layak
//       BERTURUT-TURUT selama SINYAL_HILANG_MS. Gangguan sekejap — yang
//       memang selalu ada pada gelang yang dipakai tidur — dilewati saja.
//
// Ambang DC_MIN sendiri TIDAK diubah, sebab nilainya sudah ditetapkan dari
// pengukuran nyata; yang diperbaiki adalah cara nilai itu diberlakukan.
const float    DC_TAHAN_RASIO = 0.60f;   // ambang mempertahankan kunci
const uint32_t SINYAL_HILANG_MS = 2500;  // sabar sebelum menghapus riwayat
uint32_t sigInvalidSejakMs = 0;          // 0 = sinyal sedang layak

// Penyangga lokal saat HP terputus (ring buffer).
// struct Buffered didefinisikan di hyposense_types.h
const int BUF_MAX = 16;
Buffered buf[BUF_MAX]; int bufLen = 0;

// ================= STATE MACHINE ============================
enum SystemState { STANDBY, HEATING, BREATH_PROMPT, MEASURING, ALARM };
SystemState currentState = STANDBY;

// ================= BLE CALLBACKS ============================
class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer* s) override { bleConnected = true; }
  void onDisconnect(BLEServer* s) override {
    bleConnected = false;
    modeUji = false;         // lihat catatan pada deklarasi modeUji
    s->startAdvertising();   // iklankan lagi agar HP bisa nyambung ulang
  }
};

class CmdCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String v = String(c->getValue().c_str());
    v.trim();
    if (v.startsWith("SYNC:")) {
      cmdSyncEpoch = v.substring(5).toInt();
      cmdSync = true;
    } else if (v == "VOC") {
      cmdReqVoc = true;
    } else if (v == "RESETBASE") {
      cmdResetBase = true;
    } else if (v == "CALR0") {
      cmdCalR0 = true;        // rekam udara bersih (tanpa embusan napas)
    } else if (v == "CALNAPAS") {
      cmdCalNapas = true;     // rekam napas saat glukosa normal
    } else if (v == "MODEUJI:1") {
      modeUji = true;
    } else if (v == "MODEUJI:0") {
      modeUji = false;
    }
  }
};

// Pembacaan baterai DIHAPUS: pembagi tegangannya belum terpasang, sehingga
// angka yang dikirim tidak pernah mencerminkan keadaan sebenarnya.

// ================= RECOVERY & MAX30105 (I2C langsung) =======
void bersihkanBusI2C() {
  pinMode(SDA_PIN, OUTPUT); pinMode(SCL_PIN, OUTPUT);
  for (int i = 0; i < 9; i++) {
    digitalWrite(SCL_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(SCL_PIN, LOW);  delayMicroseconds(10);
  }
  digitalWrite(SDA_PIN, LOW); delayMicroseconds(10);
  digitalWrite(SCL_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(SDA_PIN, HIGH); delayMicroseconds(10);
  pinMode(SDA_PIN, INPUT_PULLUP); pinMode(SCL_PIN, INPUT_PULLUP);
}

void writeReg(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MAX30105_ADDR);
  Wire.write(reg); Wire.write(val);
  Wire.endTransmission();
}

void initMAX30105() {
  writeReg(0x09, 0x40); delay(100);
  writeReg(0x04, 0x00); writeReg(0x05, 0x00); writeReg(0x06, 0x00);
  writeReg(0x08, 0x00);
  writeReg(0x09, 0x03);  // Multi-LED
  writeReg(0x0A, 0x27);  // 100Hz, 411us
  // Slot memakai MERAH + INFRAMERAH, dan bukan hijau, karena modul pada
  // perangkat ini ternyata MAX30102 (PART_ID 0x15, REV_ID 0x03) — bukan
  // MAX30105 seperti dugaan semula. Keduanya beralamat I2C sama sehingga
  // mudah tertukar, tetapi MAX30102 TIDAK memiliki LED hijau.
  //
  // Diuji 3 Sep: slot hijau dinyalakan pada arus 0x2F menghasilkan DC 570,
  // dinaikkan ke maksimum 0xFF hanya menjadi 650. Kenaikan arus lima kali
  // lipat nyaris tak mengubah pembacaan, yang berarti tidak ada LED yang
  // menyala di slot tersebut.
  //
  // Ini keterbatasan yang perlu diketahui: hijau (~530 nm) adalah panjang
  // gelombang baku untuk fotopletismografi di PERGELANGAN, sebab kuat
  // diserap hemoglobin dan tidak menembus terlalu dalam. Inframerah menembus
  // lebih jauh sehingga lebih cocok pada ujung jari, dan pada pergelangan
  // riak denyutnya tenggelam di jaringan yang tidak berdenyut.
  writeReg(0x11, 0x21);  // slot1 MERAH, slot2 INFRAMERAH
  // Arus LED dinaikkan 0x1F -> 0x2F (~1,5x). Alasan dari uji 14 Agu: PI di
  // kulit hanya 0,09-0,66% — sinyal denyut nyaris setipis derau, sehingga
  // waktu tiap denyut meleset ratusan milidetik (IBI tersebar 552-1093 ms)
  // dan RMSSD membengkak ke 89-155 ms. Sinyal lebih kuat = waktu denyut
  // lebih tajam. DC akan ikut naik ~1,5x (98k -> ~148k), masih jauh di bawah
  // IR_SATURATED (261k).
  writeReg(0x0C, 0x2F);  // LED1 (merah) amplitude
  writeReg(0x0D, 0x2F);  // LED2 (inframerah) amplitude
}

// ---- Layar tak wajib ada -----------------------------------------------
// Bila OLED rusak atau dicabut, alat HARUS tetap memantau. Sebelumnya
// kegagalan display.begin() menjatuhkan firmware ke for(;;) sehingga PPG,
// BLE, dan alarm ikut mati — tak dapat diterima untuk gelang yang dipakai
// semalaman. Penggambaran tetap berjalan ke penyangga RAM (tanpa biaya I2C);
// hanya pengirimannya ke layar yang dilewati.
bool oledAda = false;
inline void tampilkan() { if (oledAda) display.display(); }

// ---- Pemulihan otomatis jalur I2C -------------------------------------
// readIR() mengembalikan 0 bila sensor tak menjawab. Sebelumnya nilai 0 itu
// mengalir begitu saja ke penyangga PI dan TAK ADA yang memulihkan, sehingga
// sekali jalur tersendat alat berhenti memantau sampai dicabut-colok — tanpa
// tanda apa pun. Untuk alat yang ditinggal semalaman, itu tak dapat diterima.
//
// Pemindaian I2C 31 Agu membuktikan jalur ini memang labil: satu pemindaian
// melaporkan 126 alamat menjawab (ciri SDA tertahan rendah), pemindaian lain
// kehilangan OLED, lalu ketiganya muncul kembali. Sensornya sendiri sehat.
uint16_t i2cGagalBerturut = 0;
uint32_t i2cPulihTerakhirMs = 0;
uint32_t i2cJumlahPulih = 0;
const uint16_t I2C_GAGAL_MAKS   = 50;    // 50 x 10 ms = 0,5 dtk tanpa data
const uint32_t I2C_PULIH_JEDA   = 3000;  // jangan memulihkan lebih rapat dari ini

void pulihkanBusSensor() {
  i2cJumlahPulih++;
  Serial.printf("[I2C] Sensor diam %d bacaan - memulihkan bus (ke-%u)\n",
                i2cGagalBerturut, i2cJumlahPulih);
  Wire.end();
  bersihkanBusI2C();                       // 9 pulsa SCL + STOP: bebaskan SDA
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);
  initMAX30105();
  resetHrState();                          // detak lama tak lagi sinambung
  i2cGagalBerturut = 0;
  i2cPulihTerakhirMs = millis();
}

uint32_t readIR() {
  Wire.beginTransmission(MAX30105_ADDR);
  Wire.write(0x07);
  if (Wire.endTransmission() != 0) return 0;
  if (Wire.requestFrom((uint8_t)MAX30105_ADDR, (uint8_t)6) == 6) {
    Wire.read(); Wire.read(); Wire.read();
    uint8_t i1 = Wire.read(), i2 = Wire.read(), i3 = Wire.read();
    return ((uint32_t)(i1 & 0x03) << 16) | ((uint32_t)i2 << 8) | i3;
  }
  return 0;
}

void resetHrState() {
  beatAvg = 0; beatCount = 0; devAnomStartMs = 0;
  for (byte x = 0; x < RATE_SIZE; x++) rates[x] = 0;
  rateSpot = 0; rateFill = 0;
  ibiFill = 0; ibiSpot = 0; lastGoodIbi = 0;
}

float ibiAt(byte k) {
  return (ibiFill < IBI_SIZE) ? ibis[k] : ibis[(ibiSpot + k) % IBI_SIZE];
}

float computePrv() {
  if (ibiFill < 4) return 0;
  float sumSq = 0; int n = 0;
  for (byte i = 1; i < ibiFill; i++) {
    float d = ibiAt(i) - ibiAt(i - 1);
    sumSq += d * d; n++;
  }
  return n ? sqrtf(sumSq / n) : 0;
}

void buildIbiJson(char* out, size_t n) {
  size_t p = 0;
  out[p++] = '[';
  for (byte i = 0; i < ibiFill && p + 12 < n; i++) {
    p += snprintf(out + p, n - p, "%s%d", i ? "," : "", (int)ibiAt(i));
  }
  snprintf(out + p, n - p, "]");
}

// ================= KIRIM DATA VIA BLE ======================
void notifyLive(int hr, float prv, int voc, float t, float h, long ts, bool buffered) {
  if (!bleConnected || liveChar == nullptr) return;
  // Data tertunda (buffer offline) tak menyimpan IBI mentah — kirim array
  // kosong agar tak salah dikira milik pengukuran itu.
  char ibiJson[110];
  if (buffered) snprintf(ibiJson, sizeof(ibiJson), "[]");
  else          buildIbiJson(ibiJson, sizeof(ibiJson));
  // voc     : bacaan ADC mentah, selalu ada, dapat ditelusuri
  // voc_ppm : hasil pengubahan; -1 berarti R0 belum dikalibrasi (CALR0)
  // voc_rel : simpangan terhadap patokan napas personal, dalam persen —
  //           inilah yang dipakai memutuskan, dan satu-satunya yang tidak
  //           bergantung pada kurva yang belum terkalibrasi
  float ppm = ppmAseton(voc);
  float rel = vocBreathBase > 0
                ? (voc - vocBreathBase) / vocBreathBase * 100.0f : 0.0f;
  // n : penghitung denyut sah sejak riwayat denyut terakhir dikosongkan.
  //     Paket dikirim tiap 5 detik sedangkan "ibi" memuat 16 selang terakhir,
  //     sehingga dua paket berurutan saling tumpang-tindih. Selisih n antar-
  //     paket memberi tahu aplikasi berapa selang yang benar-benar BARU, agar
  //     rekaman panjang dapat disambung tanpa denyut yang tercatat dua kali.
  char json[400];
  snprintf(json, sizeof(json),
    "{\"t\":\"live\",\"hr\":%d,\"prv\":%.1f,\"voc\":%d,\"voc_ppm\":%.1f,"
    "\"voc_rel\":%.1f,\"temp\":%.1f,\"hum\":%.1f,\"n\":%u,"
    "\"ibi\":%s,\"ts\":%ld,\"buf\":%d}",
    hr, prv, voc, isnan(ppm) ? -1.0f : ppm, rel,
    t, h, buffered ? 0u : (unsigned)beatCount, ibiJson, ts, buffered ? 1 : 0);
  liveChar->setValue((uint8_t*)json, strlen(json));
  liveChar->notify();
}

void notifyEvent(const char* risk, int hr, int voc, long ts) {
  if (!bleConnected || eventChar == nullptr) return;
  char json[140];
  snprintf(json, sizeof(json),
    "{\"t\":\"event\",\"risk\":\"%s\",\"hr\":%d,\"voc\":%d,\"ts\":%ld}",
    risk, hr, voc, ts);
  eventChar->setValue((uint8_t*)json, strlen(json));
  eventChar->notify();
}

// Hasil satu pengukuran napas, lengkap dengan simpangan, suhu, dan
// kelembapannya. Sengaja dikirim lewat karakteristik EVENT: paket live
// berikutnya membaca sensor yang pemanasnya sudah dimatikan, sehingga nilai
// napas yang hanya ada di paket live tertimpa beberapa detik kemudian —
// sebelum petugas sempat menyimpannya.
void notifyHasil(const char* risk, int hr, int voc, float rel, float t, float h,
                 long ts) {
  if (!bleConnected || eventChar == nullptr) return;
  char json[160];
  snprintf(json, sizeof(json),
    "{\"t\":\"event\",\"risk\":\"%s\",\"hr\":%d,\"voc\":%d,\"rel\":%.1f,"
    "\"temp\":%.1f,\"hum\":%.1f,\"ts\":%ld}",
    risk, hr, voc, rel, t, h, ts);
  eventChar->setValue((uint8_t*)json, strlen(json));
  eventChar->notify();
}

// Ambil snapshot sensor sekarang -> Buffered
Buffered snapshot() {
  Buffered b;
  b.hr = beatAvg; b.prv = computePrv();
  b.voc = analogRead(MQ138_PIN);
  float t = sht31.readTemperature(), h = sht31.readHumidity();
  b.t = isnan(t) ? 0 : t; b.h = isnan(h) ? 0 : h;
  b.ts = currentEpoch();
  return b;
}

void pushBuffer(const Buffered& b) {
  if (bufLen == BUF_MAX) { for (int i = 1; i < BUF_MAX; i++) buf[i-1] = buf[i]; bufLen--; }
  buf[bufLen++] = b;
}

// Saat tersambung kembali: kirim isi penyangga (ditandai buf:1)
void flushBuffer() {
  while (bufLen > 0 && bleConnected) {
    Buffered b = buf[0];
    notifyLive(b.hr, b.prv, b.voc, b.t, b.h, b.ts, true);
    for (int i = 1; i < bufLen; i++) buf[i-1] = buf[i];
    bufLen--;
    delay(30);   // beri jeda antar-notifikasi
  }
}

// ================= DETAK JANTUNG & ANOMALI =================
void sampleHR() {
  if (millis() - lastPpgMs < 10) return;
  lastPpgMs = millis();
  lastIR = readIR();

  // Nol berarti sensor tak menjawab. Bila berlanjut, bebaskan jalur I2C dan
  // siapkan ulang sensornya, sehingga alat pulih sendiri tanpa dicabut.
  if (lastIR == 0) {
    if (++i2cGagalBerturut >= I2C_GAGAL_MAKS &&
        millis() - i2cPulihTerakhirMs > I2C_PULIH_JEDA) {
      pulihkanBusSensor();
      return;                      // jendela PI diisi ulang dari bacaan sehat
    }
  } else {
    i2cGagalBerturut = 0;
  }

  // --- Perfusion Index atas jendela ~1,3 dtk ---
  irBuf[irBufIdx] = lastIR;
  irBufIdx = (irBufIdx + 1) % PI_WIN;
  if (irBufIdx == 0) irBufFull = true;
  int cnt = irBufFull ? PI_WIN : irBufIdx;
  uint32_t mn = 0xFFFFFFFF, mx = 0; double sum = 0;
  for (int i = 0; i < cnt; i++) {
    uint32_t v = irBuf[i];
    if (v < mn) mn = v;
    if (v > mx) mx = v;
    sum += v;
  }
  sigDC = (float)(sum / cnt);
  sigPI = (sigDC > 0) ? (100.0f * (float)(mx - mn) / sigDC) : 0.0f;
  // Valid = ADA KONTAK (DC cukup, tak saturasi) DAN ADA DENYUT (PI cukup),
  // dengan jendela terisi memadai. Inilah pengganti "IR>3000".
  //
  // Ambang DC dibedakan menurut keadaan sekarang (histeresis): saat belum
  // mengunci dituntut DC_MIN penuh, saat sudah mengunci cukup 60% — sehingga
  // sinyal pergelangan yang menggantung di sekitar 12.000 tidak berkedip.
  uint32_t ambangDC = sigValid ? (uint32_t)(DC_MIN * DC_TAHAN_RASIO) : DC_MIN;
  sigValid = (cnt >= PI_WIN / 2) && (sigDC > ambangDC) &&
             (lastIR < IR_SATURATED) && (sigPI > PI_MIN) && (sigPI < PI_MAX);

  if (lastBeat > 0 && (millis() - lastBeat > BEAT_TIMEOUT_MS)) resetHrState();

  // Penapis di dalam checkForBeat() menyimpan keadaan sendiri (pembuang DC dan
  // rerata bergerak). Bila ia berhenti disuapi tiap kali sinyal goyah, keadaan
  // itu basi dan denyut pertama setelah pulih kerap terbaca meleset. Karena itu
  // penapis SELALU disuapi; yang dijaga gerbangnya adalah PENERIMAAN denyut,
  // bukan pemberian cuplikan.
  bool adaDenyut = checkForBeat(lastIR);

  if (sigValid) {
    sigInvalidSejakMs = 0;
    long sejakDenyut = millis() - lastBeat;
    // Pemicu yang datang < REFRACTORY_MS dianggap puncak susulan dari detak
    // yang SAMA, bukan detak baru. lastBeat sengaja TIDAK diperbarui agar
    // pemicu palsu tak menggeser acuan waktu.
    if (adaDenyut && sejakDenyut >= (long)REFRACTORY_MS) {
      long delta = sejakDenyut;
      lastBeat = millis();
      beatsPerMinute = 60 / (delta / 1000.0);
      // Saring dua lapis:
      //  (a) rentang fisiologis 30-220 bpm
      //  (b) LOMPATAN dari denyut sebelumnya. Variasi antar-denyut yang wajar
      //      hanya ~5-20%; lompatan besar praktis selalu denyut palsu atau
      //      denyut terlewat. Tanpa saringan ini RMSSD meledak (terbaca
      //      1166 ms). Ambang 40% masih meloloskan terlalu banyak (PRV tetap
      //      137-395 ms), maka diperketat ke 25% — tetap ~4x lebih longgar
      //      daripada variasi denyut wajar.
      bool lompatWajar = (lastGoodIbi <= 0) ||
                         (fabsf((float)delta - lastGoodIbi) < 0.25f * lastGoodIbi);
      if (beatsPerMinute < HR_MAX_BPM && beatsPerMinute > 30 && lompatWajar) {
        lastGoodIbi = (float)delta;
        rates[rateSpot++] = (byte)beatsPerMinute; rateSpot %= RATE_SIZE;
        if (rateFill < RATE_SIZE) rateFill++;
        if (beatCount < 65000) beatCount++;

        // Diturunkan dari 5 ke 3. Setiap kali riwayat terhapus, BPM baru
        // muncul kembali setelah sekian denyut sah terkumpul — pada 60 bpm,
        // lima denyut berarti layar kosong lima detik penuh. Median atas tiga
        // denyut sudah cukup meredam satu denyut menyimpang, dan yang menjaga
        // keandalannya tetap saringan di hulu: rentang 30-220 bpm, batas
        // lompatan 25%, serta masa refrakter.
        if (rateFill >= 3) {
          byte tmp[RATE_SIZE];
          for (byte x = 0; x < rateFill; x++) tmp[x] = rates[x];
          for (byte i = 1; i < rateFill; i++) {          // sisip-urut (n<=8)
            byte k = tmp[i]; int j = i - 1;
            while (j >= 0 && tmp[j] > k) { tmp[j + 1] = tmp[j]; j--; }
            tmp[j + 1] = k;
          }
          beatAvg = (rateFill & 1)
                    ? tmp[rateFill / 2]
                    : (tmp[rateFill / 2 - 1] + tmp[rateFill / 2]) / 2;
        } else {
          beatAvg = 0;                                   // belum cukup denyut
        }

        if (ibiFill < IBI_SIZE) ibis[ibiFill++] = delta;
        else { ibis[ibiSpot] = delta; ibiSpot = (ibiSpot + 1) % IBI_SIZE; }
      }
    }
  } else {
    // Sinyal sedang tak layak. Riwayat denyut TIDAK langsung dibuang: gelang
    // tidur pasti sesekali bergeser, dan menghapus seluruh riwayat karena
    // gangguan sepersekian detik membuat BPM tak pernah bertahan. Riwayat baru
    // dilepas bila keadaan ini benar-benar berlanjut.
    if (sigInvalidSejakMs == 0) sigInvalidSejakMs = millis();
    else if (millis() - sigInvalidSejakMs > SINYAL_HILANG_MS) {
      if (beatCount > 0) resetHrState();     // hanya sekali, bukan tiap 10 ms
      sigInvalidSejakMs = millis();
    }
  }
}

// ---- Inferensi TinyML Lapisan 1: Logistic Regression (PPG: HR + PRV) ----
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
}

// VOC: RAW naik = gas naik. Aseton naik >margin => mengarah hiper (bukan hipo).
// ---- ADC -> Rs/R0 -> ppm ----------------------------------------------
// Nilai ADC diubah menjadi perbandingan resistansi sensor terhadap
// resistansinya di udara bersih. Perbandingan inilah yang menjadi masukan
// kurva lembar data, dan ia tidak bergantung pada besarnya resistor beban.
//
// Arah pembacaan: MQ-138 memakai semikonduktor yang resistansinya MENURUN
// ketika gas pereduksi bertambah. Karena sensor berada di sisi atas pembagi
// tegangan, tegangan simpul — dan nilai ADC — NAIK seiring naiknya kadar.
// Jadi kadar naik berarti Rs turun, Rs/R0 turun, dan ppm naik.
float rasioRs(int adc) {
  if (vocR0Adc <= 0 || adc <= 0) return NAN;      // belum dikalibrasi
  float v  = adc      * (VOC_ADC_VREF / 4095.0f);
  float v0 = vocR0Adc * (VOC_ADC_VREF / 4095.0f);
  if (v <= 0 || v >= VOC_VC || v0 <= 0 || v0 >= VOC_VC) return NAN;
  return ((VOC_VC - v) / v) / ((VOC_VC - v0) / v0);
}

float ppmAseton(int adc) {
  float r = rasioRs(adc);
  if (isnan(r) || r <= 0) return NAN;
  return VOC_PPM_A * powf(r, VOC_PPM_B);
}

// Menentukan arah perubahan glukosa dari kadar aseton napas.
//
// ARAHNYA DIPERBAIKI 8 Sep. Aturan lama berbunyi "hipoglikemia bila aseton
// TIDAK naik 15%", yang berlawanan dengan fisiologi yang kami rujuk sendiri.
// Turner dkk. melaporkan aseton napas MENURUN seiring turunnya glukosa;
// dihitung dari persamaan regresi mereka, penurunan glukosa 5,5 -> 3,0 mmol/L
// menurunkan aseton sekitar 30% (subjek 4A: 1.993 -> 1.389 ppb; subjek 10A:
// 20.024 -> 13.096 ppb).
//
// Akibat aturan lama: keadaan normal yang asetonnya tidak berubah pun
// dinyatakan hipoglikemia, sebab ia memang tidak naik 15%. Padahal keadaan
// normal justru yang paling sering terjadi, sehingga gerbang ini nyaris tak
// menyaring apa pun — bertentangan dengan tugasnya menekan peringatan palsu
// dari jalur jantung.
//
// Arah pembacaan sensor: MQ-138 memakai semikonduktor yang resistansinya
// MENURUN ketika gas pereduksi bertambah, sehingga tegangan keluarannya —
// dan nilai ADC-nya — NAIK seiring naiknya kadar aseton. Nilai ADC karena itu
// searah dengan kadar, dan penurunan kadar terbaca sebagai penurunan ADC.
// ---- Inferensi TinyML Lapisan 2: Pruned Random Forest (VOC + SHT31) ----
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
}

// ================= SETUP ===================================
void setupBLE() {
  BLEDevice::init(BLE_NAME);
  // Dinaikkan dari 185. Batas muatan satu paket = MTU - 3, dan dengan 185
  // hanya 182 byte, padahal paket live berisi 16 selang antar-denyut mencapai
  // ±199 byte — ±215 byte saat detak di bawah 60 bpm. Paket yang melebihi
  // batas TERPOTONG, JSON-nya gagal dibaca, dan aplikasi membuangnya tanpa
  // pesan: data live berhenti diperbarui ±10 detik setelah denyut terkunci.
  // HP meminta 512; nilai yang disepakati adalah yang lebih kecil dari keduanya.
  BLEDevice::setMTU(517);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCB());

  BLEService* svc = bleServer->createService(SVC_UUID);
  liveChar = svc->createCharacteristic(LIVE_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  liveChar->addDescriptor(new BLE2902());
  eventChar = svc->createCharacteristic(EVENT_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  eventChar->addDescriptor(new BLE2902());
  cmdChar = svc->createCharacteristic(CMD_UUID, BLECharacteristic::PROPERTY_WRITE);
  cmdChar->setCallbacks(new CmdCB());
  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SVC_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println(F("[BLE] Advertising sebagai " BLE_NAME));
}

// ================= DIAGNOSTIK SEMENTARA ====================
// Menjawab satu pertanyaan: pin mana yang SEBENARNYA tersambung ke MQ-138?
// Semua pin ADC dibaca dua kali — saat pemanas mati dan menyala. Pin yang
// angkanya BERUBAH adalah pin sensor yang asli. Bila semua terbaca 4095,
// tegangan keluaran sensor melebihi batas ADC (3,3 V), bukan soal pin.
// Hapus pemanggilannya di setup() setelah pin ketahuan.
void scanADC() {
  const int pins[] = {0, 1, 2, 4, 5};   // GPIO3 dilewati: dipakai MOSFET
  Serial.println(F("\n--- PANTAU ADC 60 DETIK ---"));
  Serial.println(F("Membedakan dua hal yang gejalanya mirip:"));
  Serial.println(F("  (a) pin sensor gas  -> angka BERGERAK PERLAHAN saat memanas,"));
  Serial.println(F("      dan MELONJAK saat dihembusi napas"));
  Serial.println(F("  (b) tegangan anjlok -> semua angka TURUN SEREMPAK begitu"));
  Serial.println(F("      pemanas menyala, lalu DATAR (tak bereaksi pada napas)"));
  Serial.println(F(">> Detik 0-10 pemanas MATI. Detik 10 pemanas NYALA."));
  Serial.println(F(">> HEMBUSKAN NAPAS ke sensor pada detik 35-40.\n"));

  digitalWrite(MOSFET_PIN, LOW);
  for (int t = 0; t <= 60; t++) {
    if (t == 10) { digitalWrite(MOSFET_PIN, HIGH); Serial.println(F(">>> PEMANAS NYALA")); }
    if (t == 35) Serial.println(F(">>> HEMBUSKAN NAPAS SEKARANG"));
    Serial.printf("t=%2ds  ", t);
    for (int p : pins) Serial.printf("G%d=%4d  ", p, analogRead(p));
    Serial.println();
    delay(1000);
  }
  digitalWrite(MOSFET_PIN, LOW);
  Serial.println(F("--- selesai ---\n"));
}

// ================= UJI PEMBANDING KELEMBAPAN ================
// Menjawab: kenaikan VOC saat ditiup itu ASETON, atau cuma UAP AIR?
//
// Napas manusia hangat & sangat lembap, dan sensor oksida logam seperti
// MQ-138 terkenal peka terhadap uap air. Karena itu kenaikan angka VOC saat
// ditiup BELUM tentu berarti sensor membaca gas.
//
// Caranya: rekam VOC dan kelembapan BERSAMAAN, lalu bandingkan bentuk
// perubahannya (dalam persen terhadap patokan masing-masing, supaya setara).
//   - dVOC% mengikuti dRH% rapat   -> yang terbaca UAP AIR
//   - dVOC% berbeda pola / lebih lambat pulih -> ada komponen gas
//
// PEMBANDING TAMBAHAN (disarankan, jalankan dua kali):
//   ronde 1 = tiup langsung dari dekat  (uap air banyak)
//   ronde 2 = tiup lewat sedotan panjang / dari jarak ~20 cm (uap air jauh
//             berkurang, gas relatif tetap)
//   Bila respons ronde 2 ikut hilang, berarti ronde 1 memang uap air.
void ujiKelembapan() {
  const int WARM_S = 25, BASE_S = 30, TIUP_S = 32, TOTAL_S = 75;
  float sumVoc = 0, sumRh = 0; int nBase = 0;
  float baseVoc = 0, baseRh = 0;

  Serial.println(F("\n=== UJI PEMBANDING KELEMBAPAN ==="));
  Serial.println(F("0-25d pemanas memanas | 25-30d ambil patokan"));
  Serial.println(F("30d SIAP-SIAP | 32d TIUP | sisanya amati pemulihan\n"));
  Serial.println(F(" t     VOC    RH%   T_C  |  dVOC%   dRH%"));

  digitalWrite(MOSFET_PIN, HIGH);
  for (int t = 0; t <= TOTAL_S; t++) {
    int   voc = analogRead(MQ138_PIN);
    float rh  = sht31.readHumidity();
    float tc  = sht31.readTemperature();
    if (isnan(rh)) rh = 0;
    if (isnan(tc)) tc = 0;

    // Kumpulkan patokan pada jendela stabil SEBELUM ditiup
    if (t >= WARM_S && t < BASE_S) { sumVoc += voc; sumRh += rh; nBase++; }
    if (t == BASE_S && nBase > 0) {
      baseVoc = sumVoc / nBase; baseRh = sumRh / nBase;
      Serial.printf(">>> PATOKAN: VOC=%.0f  RH=%.1f%%\n", baseVoc, baseRh);
      Serial.println(F(">>> SIAP-SIAP..."));
    }
    if (t == TIUP_S) Serial.println(F(">>> TIUP SEKARANG!"));

    Serial.printf("%2ds  %5d  %5.1f  %4.1f", t, voc, rh, tc);
    if (baseVoc > 0) {                       // tampilkan selisih persen
      Serial.printf("  | %+6.1f  %+6.1f",
                    100.0f * (voc - baseVoc) / baseVoc,
                    baseRh > 0 ? 100.0f * (rh - baseRh) / baseRh : 0.0f);
    }
    Serial.println();
    delay(1000);
  }
  digitalWrite(MOSFET_PIN, LOW);
  Serial.println(F("=== selesai — bandingkan kolom dVOC% vs dRH% ===\n"));
}

void setup() {
  Serial.begin(115200);
  delay(1500);
  Serial.println(F("\n=== HypoSense BLE boot ==="));

  pinMode(MOSFET_PIN, OUTPUT);
  digitalWrite(MOSFET_PIN, LOW);

  // scanADC();       // diagnostik pencarian pin — selesai, hasilnya GPIO4.
                      // Aktifkan lagi bila wiring berubah.

  bersihkanBusI2C();
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);

  oledAda = display.begin(SSD1306_SWITCHCAPVCC, 0x3C, false);
  if (!oledAda)
    Serial.println(F("[OLED] tak terdeteksi - lanjut tanpa layar"));
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 24); display.println(F("HypoSense BLE...")); tampilkan();

  if (!sht31.begin(0x44)) Serial.println(F("SHT31 tak terdeteksi, lanjut..."));
  initMAX30105();
  {
    // MAX30102 dan MAX30105 sama-sama beralamat 0x57, tetapi hanya MAX30105
    // yang memiliki LED hijau. Nomor revisi membantu membedakan keduanya
    // ketika pembacaan pada slot hijau tidak menghasilkan cahaya sama sekali.
    Wire.beginTransmission(MAX30105_ADDR); Wire.write(0xFE);
    Wire.endTransmission();
    Wire.requestFrom((uint8_t)MAX30105_ADDR, (uint8_t)1);
    uint8_t rev = Wire.available() ? Wire.read() : 0xEE;
    Wire.beginTransmission(MAX30105_ADDR); Wire.write(0xFF);
    Wire.endTransmission();
    Wire.requestFrom((uint8_t)MAX30105_ADDR, (uint8_t)1);
    uint8_t part = Wire.available() ? Wire.read() : 0xEE;
    Serial.printf("[CIP] PART_ID=0x%02X  REV_ID=0x%02X\n", part, rev);
  }

  prefs.begin("hyposense", false);
  hrBaseline     = prefs.getFloat("hrbase", 0);
  prvBaseline    = prefs.getFloat("prvbase", 0);
  vocBreathBase  = prefs.getFloat("vocbase", 0);
  tempBreathBase = prefs.getFloat("tbase", 0);
  humBreathBase  = prefs.getFloat("hbase", 0);
  vocR0Adc       = prefs.getFloat("vocr0", 0);
  Serial.printf("[VOC] patokan napas=%.0f  udara bersih R0=%.0f%s\n",
                vocBreathBase, vocR0Adc,
                vocR0Adc <= 0 ? "  (ppm belum tersedia, jalankan CALR0)" : "");
  if (hrBaseline > 0) baselineReady = true;

  // ujiKelembapan();   // <<< HAPUS TANDA // untuk menjalankan uji pembanding
                        // kelembapan (75 detik). Harus di SINI, sesudah
                        // sht31.begin() — sebelum itu kelembapan belum terbaca.

  setupBLE();
}

// ================= PROSES PERINTAH DARI HP =================
void prosesPerintah() {
  if (cmdSync) {
    cmdSync = false;
    epochAtSync = cmdSyncEpoch; millisAtSync = millis(); timeSynced = true;
    Serial.printf("[CMD] SYNC epoch=%ld\n", cmdSyncEpoch);
  }
  // Perintah lewat SERIAL, sejajar dengan perintah lewat BLE.
  // Berguna untuk pengujian di meja kerja tanpa perlu membuka aplikasi, dan
  // untuk memastikan apakah suatu kegagalan berasal dari perangkat atau dari
  // jalur komunikasinya.
  if (Serial.available()) {
    String v = Serial.readStringUntil('\n');
    v.trim(); v.toUpperCase();
    if      (v == "VOC")       { cmdReqVoc = true;    Serial.println(F("[SER] VOC")); }
    else if (v == "CALR0")     { cmdCalR0 = true;     Serial.println(F("[SER] CALR0")); }
    else if (v == "CALNAPAS")  { cmdCalNapas = true;  Serial.println(F("[SER] CALNAPAS")); }
    else if (v == "RESETBASE") { cmdResetBase = true; Serial.println(F("[SER] RESETBASE")); }
    else if (v == "MODEUJI:1") { modeUji = true;  Serial.println(F("[SER] MODE UJI KLINIK aktif")); }
    else if (v == "MODEUJI:0") { modeUji = false; Serial.println(F("[SER] MODE UJI KLINIK mati")); }
    else if (v == "UJIPANAS") {
      // Memeriksa apakah pemanas MQ-138 benar-benar bekerja.
      // Pada sensor semikonduktor, menyalakan pemanas menurunkan resistansi
      // secara berarti sehingga bacaan bergerak jelas. Bila bacaan nyaris
      // tidak berubah selama satu setengah menit, pemanasnya patut dicurigai
      // tidak menyala — dan seluruh jalur VOC menjadi tak berarti.
      Serial.println(F("[PANAS] pemanas MATI, 10 detik pertama"));
      digitalWrite(MOSFET_PIN, LOW);
      for (int i = 0; i < 2; i++) {
        delay(5000);
        Serial.printf("[PANAS] t=%2ds  mati   gas=%d\n", (i+1)*5,
                      analogRead(MQ138_PIN));
      }
      Serial.println(F("[PANAS] pemanas DINYALAKAN"));
      digitalWrite(MOSFET_PIN, HIGH);
      for (int i = 0; i < 18; i++) {
        delay(5000);
        Serial.printf("[PANAS] t=%2ds  nyala  gas=%d\n", (i+1)*5,
                      analogRead(MQ138_PIN));
      }
      digitalWrite(MOSFET_PIN, LOW);
      Serial.println(F("[PANAS] selesai, pemanas dimatikan"));
    }
    else if (v == "STATUS") {
      Serial.printf("[SER] keadaan=%d  bpm=%d  denyut=%u  patokanSiap=%d\n",
                    (int)currentState, beatAvg, beatCount, (int)baselineReady);
      Serial.printf("[SER] gas=%d  patokanNapas=%.0f  R0=%.0f\n",
                    analogRead(MQ138_PIN), vocBreathBase, vocR0Adc);
      Serial.printf("[SER] modeUji=%d  BLE=%d\n", (int)modeUji, (int)bleConnected);
    }
    else if (v.length()) Serial.printf("[SER] tak dikenal: %s\n", v.c_str());
  }

  // Dipakai saat gelang BERPINDAH ORANG. Yang dihapus HANYA patokan yang
  // melekat pada orang; patokan yang melekat pada ALAT sengaja dipertahankan.
  //
  //   hrBaseline    milik ORANG  - denyut istirahat tiap orang berbeda
  //   vocBreathBase milik ORANG  - aseton napas antar-orang berbeda sampai
  //                                21 kali lipat (Turner dkk.)
  //   vocR0Adc      milik ALAT   - resistansi sensor di udara bersih; sifat
  //                                sensornya sendiri, tak ada hubungannya
  //                                dengan siapa yang memakai
  //
  // Sebelumnya R0 ikut dihapus, sehingga tiap ganti pemakai seluruh kalibrasi
  // udara bersih 60 detik harus diulang tanpa alasan — dan selama itu ppm
  // tidak dapat dihitung sama sekali. R0 hanya perlu diperbarui bila sensornya
  // diganti atau sudah lama sekali, lewat perintah CALR0 tersendiri.
  if (cmdResetBase) {
    cmdResetBase = false;
    hrBaseline = 0; prvBaseline = 0; prvMinWindow = 0;
    hrDevEma = 6.0f; baselineReady = false;
    baselineStartMs = 0; devAnomStartMs = 0;
    vocBreathBase = 0; tempBreathBase = 0; humBreathBase = 0;
    lastPpgProb = 0; lastVocProb = 0; lastJointProb = 0;
    prefs.putFloat("hrbase", 0); prefs.putFloat("prvbase", 0);
    prefs.putFloat("vocbase", 0); prefs.putFloat("tbase", 0); prefs.putFloat("hbase", 0);
    resetHrState();          // denyut pemakai sebelumnya tak boleh terbawa
    lastReqMs = 0;           // pemakai baru tak mewarisi masa jeda 10 menit
    Serial.println(F("[CMD] Patokan PERSONAL direset (hrBaseline + napas). "
                     "R0 udara bersih dipertahankan - pakai CALR0 bila "
                     "sensornya diganti."));
  }

  // Kalibrasi UDARA BERSIH: pemanas dinyalakan, TANPA embusan napas.
  // Hasilnya menjadi R0, dasar pengubahan bacaan menjadi ppm.
  if (cmdCalR0) {
    cmdCalR0 = false;
    Serial.println(F("[CAL] Memanaskan sensor 60 dtk - JANGAN ditiup, "
                     "biarkan di udara bersih"));
    digitalWrite(MOSFET_PIN, HIGH);
    for (int i = 60; i > 0; i--) {
      display.clearDisplay(); display.setTextSize(1);
      display.setCursor(0, 12); display.println(F("KALIBRASI UDARA"));
      display.setCursor(0, 26); display.println(F("Jangan ditiup"));
      display.setTextSize(2); display.setCursor(50, 42);
      display.print(i); display.print(F("s")); tampilkan();
      tungguSambilPantau(1000);
    }
    long jum = 0;
    for (int i = 0; i < 20; i++) {
      jum += analogRead(MQ138_PIN); tungguSambilPantau(100);
    }
    vocR0Adc = jum / 20.0f;                 // rerata 2 detik, meredam derau
    prefs.putFloat("vocr0", vocR0Adc);
    digitalWrite(MOSFET_PIN, LOW);
    Serial.printf("[CAL] R0 udara bersih = %.0f ADC\n", vocR0Adc);
    display.clearDisplay(); display.setCursor(0, 20);
    display.printf("R0 = %.0f", vocR0Adc); tampilkan();
    tungguSambilPantau(3000);
  }

  // Kalibrasi NAPAS: urutan lengkap seperti pengukuran biasa, tetapi hasilnya
  // disimpan sebagai patokan, bukan dipakai memutuskan risiko.
  if (cmdCalNapas) {
    cmdCalNapas = false;
    modeCalNapas = true;
    Serial.println(F("[CAL] Merekam patokan napas - pastikan glukosa NORMAL"));
    currentState = HEATING;
  }
  // cmdReqVoc ditangani di STANDBY (memicu verifikasi napas)
}

// ---- Menunggu TANPA membutakan sensor ----------------------------------
// Seluruh tahap verifikasi dulu memakai delay() biasa: pemanasan 60 dtk,
// aba-aba napas 6,5 dtk, pengambilan gas 2 dtk, dan penayangan hasil 4 dtk.
// Selama itu loop() berhenti, sehingga sampleHR() tidak dipanggil sama sekali
// dan PPG mati sekitar 72 detik setiap satu kali verifikasi.
//
// Akibatnya berlapis: riwayat denyut habis termakan BEAT_TIMEOUT_MS, BPM
// kembali kosong begitu kembali ke STANDBY, dan tumpukan BLE tak terlayani
// selama itu sehingga HP rawan terputus sendiri.
//
// Penggantinya menunggu selama yang sama, tetapi terus mencuplik PPG dan
// memberi giliran ke RTOS. Urutan tahap sama sekali tidak berubah.
void tungguSambilPantau(uint32_t ms) {
  uint32_t t0 = millis();
  while (millis() - t0 < ms) {
    sampleHR();
    delay(1);
  }
}

// ================= LOOP ====================================
void loop() {
  sampleHR();
  prosesPerintah();

  switch (currentState) {
    case STANDBY:       jalankanStandby();   break;
    case HEATING:       jalankanPemanasan(); break;
    case BREATH_PROMPT: jalankanPrompt();    break;
    case MEASURING:     jalankanUkur();      break;
    case ALARM:         jalankanAlarm();     break;
  }
  delay(1);   // yield ke RTOS (jaga stack BLE tetap responsif)
}

void jalankanStandby() {
  // Perintah VOC dari HP atau anomali HR -> mulai verifikasi napas
  bool cooldownLewat = (lastReqMs == 0) || (millis() - lastReqMs > REQ_COOLDOWN_MS);
  bool manual = cmdReqVoc;
  // cekAnomaliHR() tetap dipanggil dalam mode uji supaya patokan detak terus
  // diperbarui, tetapi hasilnya diabaikan: selama sesi uji klinik pemeriksaan
  // napas hanya dimulai petugas. Pemicu otomatis di tengah sesi akan memotong
  // rekaman detak dan memanaskan sensor tanpa diminta.
  bool anomali = !manual && cekAnomaliHR() && cooldownLewat && !modeUji;
  if (manual || anomali) {
    verifManual = manual;
    if (manual) {
      cmdReqVoc = false;
      Serial.println(F("[CMD] VOC diminta HP"));
      // Permintaan manual BUKAN anomali. Dulu keduanya sama-sama mengirim
      // "risiko", sehingga menekan tombol cek napas membunyikan alarm
      // pengingat napas di HP dan layar gelang menulis POLA JANTUNG ANOMALI.
      notifyEvent("napas", beatAvg, 0, currentEpoch());
    } else {
      Serial.printf("[HR] Anomali bpm=%d base=%.0f\n", beatAvg, hrBaseline);
      // event awal risiko (peringatan LANGSUNG, tak menunggu VOC)
      notifyEvent("risiko", beatAvg, 0, currentEpoch());
    }
    lastReqMs = millis();
    currentState = HEATING;
    return;
  }

  // Telemetri: tiap 5 dtk saat tersambung; simpan penyangga tiap 60 dtk saat terputus
  if (bleConnected) {
    flushBuffer();
    if (millis() - lastLiveMs > LIVE_MS_CONN) {
      lastLiveMs = millis();
      Buffered b = snapshot();
      notifyLive(b.hr, b.prv, b.voc, b.t, b.h, b.ts, false);
    }
  } else {
    if (millis() - lastLiveMs > BUFFER_MS_DISC) {
      lastLiveMs = millis();
      pushBuffer(snapshot());
    }
  }

  // Debug
  if (millis() - lastDbgMs > 3000) {
    lastDbgMs = millis();
    // Tiga keadaan dibedakan supaya jelas di tahap mana sinyal tersendat:
    //   SENSOR-DIAM  sensor tak menjawab sama sekali
    //   cari-denyut  sinyal layak, denyut sedang dikumpulkan (< 8)
    //   TERKUNCI     delapan denyut terkumpul, pembacaan sudah dapat dipakai
    const char* st = (lastIR == 0)            ? "SENSOR-DIAM"
                   : (lastIR >= IR_SATURATED) ? "SATURASI"
                   : !sigValid                ? "tak-layak"
                   : (beatCount >= RATE_SIZE) ? "TERKUNCI" : "cari-denyut";
    // Kemajuan patokan personal ikut dicetak. Tanpa ini tak ada cara melihat
    // apakah masa pemanasan 10 menit benar-benar berjalan — dan bila patokan
    // tak pernah selesai, seluruh deteksi anomali diam tanpa gejala apa pun.
    int majuBase = !baselineReady && baselineStartMs > 0
                     ? (int)((millis() - baselineStartMs) * 100 / BASELINE_WARMUP_MS)
                     : (baselineReady ? 100 : 0);
    Serial.printf("[PPG] DC=%.0f PI=%.2f%% bpm=%d ibi=%.0fms prv=%.0fms n=%d %s "
                  "| patokan=%.0f %s(%d%%) | BLE=%s buf=%d pulih=%u\n",
      sigDC, sigPI, beatAvg, lastGoodIbi, computePrv(), ibiFill, st,
      hrBaseline, baselineReady ? "SIAP" : "membangun", majuBase,
      bleConnected ? "ON" : "off", bufLen, i2cJumlahPulih);
  }

  // OLED tiap 250 ms
  if (millis() - lastOledMs > 250) { lastOledMs = millis(); renderStandby(); }
}

void renderStandby() {
  display.clearDisplay();

  // ── Baris status: koneksi BLE ──
  // Persentase baterai dihapus: pembagi tegangannya belum terpasang sehingga
  // angka yang ditampilkan tidak mencerminkan keadaan sebenarnya. Menampilkan
  // angka yang keliru lebih buruk daripada tidak menampilkannya, sebab
  // pengguna dapat mengira dayanya masih cukup padahal tidak.
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print(bleConnected ? F("BLE:HP") : F("BLE:cari"));

  // ── Jam HH:MM:SS + simpan komponen tanggal (dari epoch lokal) ──
  static const char* const DOW[] = {"Min", "Sen", "Sel", "Rab",
                                     "Kam", "Jum", "Sab"};
  int mday = 0, mon = 0, wday = 0;
  display.setTextSize(2);
  display.setCursor(16, 10);
  if (timeSynced) {
    time_t tt = (time_t)currentEpoch();
    struct tm* tv = gmtime(&tt);   // epoch sudah lokal → komponen lokal
    display.printf("%02d:%02d:%02d", tv->tm_hour, tv->tm_min, tv->tm_sec);
    mday = tv->tm_mday; mon = tv->tm_mon + 1; wday = tv->tm_wday;
  } else {
    display.print(F("--:--:--"));
  }

  display.drawLine(0, 29, 128, 29, SSD1306_WHITE);

  // ── Vital baris 1: BPM & PRV ──
  display.setTextSize(1);
  display.setCursor(0, 33);
  if (beatAvg > 0) display.printf("BPM:%d", beatAvg);
  else             display.print(F("BPM:--"));
  float prv = computePrv();
  display.setCursor(70, 33);
  if (prv > 0) display.printf("PRV:%.0f", prv);
  else         display.print(F("PRV:--"));

  // ── Vital baris 2: Acetone (MQ-138) & Suhu (SHT31) ──
  // MQ-138 hanya bermakna bila pemanasnya menyala. Saat mati, analogRead
  // tetap mengembalikan angka — tapi itu sekadar tegangan diam, BUKAN kadar
  // gas. Menampilkannya akan menyesatkan, jadi ditandai "off".
  display.setCursor(0, 43);
  if (digitalRead(MOSFET_PIN)) display.printf("Ace:%d", analogRead(MQ138_PIN));
  else                         display.print(F("Ace:off"));
  // Suhu di-cache 2 dtk supaya pembacaan I2C tak mengganggu sampling PPG.
  static uint32_t lastTempMs = 0;
  static float cachedTemp = NAN;
  if (millis() - lastTempMs > 2000) {
    lastTempMs = millis();
    cachedTemp = sht31.readTemperature();
  }
  display.setCursor(70, 43);
  if (!isnan(cachedTemp)) display.printf("T:%.1fC", cachedTemp);
  else                    display.print(F("T:--"));

  // ── Baris bawah: hari + tanggal (kiri) + data tertunda (kanan) ──
  display.setCursor(0, 54);
  if (timeSynced) display.printf("%s %02d/%02d", DOW[wday], mday, mon);
  else            display.print(F("-- --/--"));
  if (bufLen > 0) { display.setCursor(90, 54); display.printf("Buf:%d", bufLen); }

  tampilkan();
}

void jalankanPemanasan() {
  digitalWrite(MOSFET_PIN, HIGH);
  for (int i = 60; i > 0; i--) {
    display.clearDisplay(); display.setTextSize(1);
    display.setCursor(0, 10);
    // Judul mengikuti ALASAN pemanasan. Menulis POLA JANTUNG ANOMALI pada
    // permintaan manual atau kalibrasi membuat pemakai — dan pasien yang
    // melihat gelangnya — mengira ada yang tidak beres.
    if (modeCalNapas)     display.println(F("KALIBRASI NAPAS"));
    else if (verifManual) display.println(F("PEMERIKSAAN NAPAS"));
    else                  display.println(F("POLA JANTUNG ANOMALI"));
    display.drawLine(0, 22, 128, 22, SSD1306_WHITE);
    display.setCursor(0, 30); display.println(F("Memanaskan sensor gas"));
    display.setTextSize(2); display.setCursor(50, 45);
    display.print(i); display.print(F("s")); tampilkan();
    tungguSambilPantau(1000);
  }
  currentState = BREATH_PROMPT;
}

void jalankanPrompt() {
  display.clearDisplay(); display.setTextSize(1);
  display.setCursor(0, 10); display.println(F("! BUKA KATUP GESER !"));
  display.setCursor(0, 30); display.println(F("Hembuskan napas ke"));
  display.println(F("kabin sensor"));
  tampilkan();
  tungguSambilPantau(6500);
  currentState = MEASURING;
}

void jalankanUkur() {
  display.clearDisplay(); display.setTextSize(1);
  display.setCursor(0, 20); display.print(F("Menganalisis...")); tampilkan();

  float suhu = sht31.readTemperature();
  float hum  = sht31.readHumidity();
  // Rerata dua detik: satu bacaan tunggal terlalu berderau untuk dijadikan
  // dasar keputusan maupun patokan.
  long jum = 0;
  for (int i = 0; i < 20; i++) {
    jum += analogRead(MQ138_PIN); tungguSambilPantau(100);
  }
  int rawGas = jum / 20;

  // Menjalankan CALNAPAS: hasilnya menjadi patokan, tidak dipakai memutuskan.
  if (modeCalNapas) {
    modeCalNapas = false;
    vocBreathBase  = rawGas;
    tempBreathBase = isnan(suhu) ? 0.0f : suhu;
    humBreathBase  = isnan(hum)  ? 0.0f : hum;
    prefs.putFloat("vocbase", vocBreathBase);
    prefs.putFloat("tbase",   tempBreathBase);
    prefs.putFloat("hbase",   humBreathBase);
    Serial.printf("[CAL] Patokan napas = %.0f ADC (ppm %.1f)\n",
                  vocBreathBase, ppmAseton(rawGas));
    display.clearDisplay(); display.setTextSize(1);
    display.setCursor(0, 8);  display.println(F("PATOKAN NAPAS"));
    display.setCursor(0, 22); display.println(F("tersimpan"));
    display.setTextSize(2); display.setCursor(0, 40);
    display.printf("%d", rawGas); tampilkan();
    tungguSambilPantau(4000);
    digitalWrite(MOSFET_PIN, LOW);
    currentState = STANDBY;
    return;
  }

  bool positif = putuskanRisiko(rawGas, suhu, hum);
  float ppm = ppmAseton(rawGas);
  float rel = vocBreathBase > 0
                ? (rawGas - vocBreathBase) / vocBreathBase * 100.0f : 0.0f;

  display.clearDisplay(); display.setTextSize(1);
  display.setCursor(0, 0);  display.println(F("HASIL:"));
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);
  display.setCursor(0, 14); display.printf("BPM : %d", beatAvg);
  display.setCursor(0, 24); display.printf("Gas : %d", rawGas);
  display.setCursor(0, 34);
  if (isnan(ppm)) display.print(F("ppm : - (cal R0)"));
  else            display.printf("ppm : %.1f", ppm);
  display.setCursor(0, 44); display.printf("T%.0fC H%.0f%%",
                                           isnan(suhu) ? 0 : suhu,
                                           isnan(hum) ? 0 : hum);
  display.setCursor(0, 54);
  display.printf("vs patokan: %+.0f%%", rel);
  tampilkan();

  // Kirim hasil verifikasi sebagai event (dan sebagai live agar tercatat).
  // Dalam mode uji klinik hasilnya berlabel "sampel", bukan vonis — lihat
  // catatan pada deklarasi modeUji.
  float suhuKirim = isnan(suhu) ? 0 : suhu;
  float humKirim  = isnan(hum) ? 0 : hum;
  const char* label = modeUji ? "sampel" : (positif ? "positif" : "negatif");
  notifyHasil(label, beatAvg, rawGas, rel, suhuKirim, humKirim, currentEpoch());
  notifyLive(beatAvg, computePrv(), rawGas, suhuKirim, humKirim,
             currentEpoch(), false);

  tungguSambilPantau(4000);
  digitalWrite(MOSFET_PIN, LOW);
  // Pengosongan "beatAvg = 0; beatCount = 0;" DIHAPUS di sini dan pada cabang
  // CALNAPAS di atas. Maksud semula adalah mencegah verifikasi terpicu lagi
  // seketika, tetapi tugas itu sudah dijalankan REQ_COOLDOWN_MS (10 menit)
  // lewat lastReqMs. Yang tersisa hanyalah kerugiannya: BPM kembali kosong
  // setiap selesai verifikasi, dan beatCount yang jatuh ke nol menahan
  // pembaruan patokan personal sampai delapan denyut terkumpul lagi.
  verifManual = false;
  if (positif && !modeUji) { alarmStartMs = millis(); currentState = ALARM; }
  else                     { currentState = STANDBY; }
}

void jalankanAlarm() {
  bool on = ((millis() / 500) % 2) == 0;
  display.clearDisplay();
  if (on) {
    display.setTextSize(2);
    display.setCursor(10, 8);  display.println(F("!RISIKO!"));
    display.setCursor(4, 20);  display.println(F("HIPOGLIKEMI"));
  }
  display.setTextSize(1);
  display.setCursor(0, 48); display.println(F("Cek gula darah &"));
  display.println(F("konsumsi karbo cepat"));
  tampilkan();

  if (millis() - alarmStartMs > ALARM_SHOW_MS) currentState = STANDBY;
  delay(100);
}

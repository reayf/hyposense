import json
import numpy as np

raw_data = {
    "idx": 2,
    "id": "93784cfb-22ee-45bb-98e3-e11856760598",
    "subject_id": "e8bd1dda-0470-4083-bc1a-28b87a958b54",
    "started_at": "2026-09-30 16:06:35.858998+00",
    "duration_s": 300,
    "lengkap": True,
    "n_beats": 62,
    "lost_beats": 0,
    "gap_s": 70,
    "ibi_raw": [1165,953,718,823,712,874,933,855,908,783,692,562,608,542,517,592,522,552,648,513,517,492,593,552,527,522,502,542,552,513,1919,1456,1576,855,796,983,822,703,572,581,557,572,693,583,597,467,532,572,561,1225,1224,1191,1245,1415,1154,1124,964,724,680,638,543,653],
    "samples": [
        {"hr": 0, "hum": 63.8, "prv": 0.0, "voc": 762, "temp": 30.6, "detik": 1},
        {"hr": 56, "hum": 63.9, "prv": 197.4, "voc": 776, "temp": 30.6, "detik": 6},
        {"hr": 66, "hum": 64.0, "prv": 172.1, "voc": 781, "temp": 30.6, "detik": 11},
        {"hr": 69, "hum": 64.1, "prv": 156.8, "voc": 776, "temp": 30.7, "detik": 16},
        {"hr": 0, "hum": 64.1, "prv": 0.0, "voc": 763, "temp": 30.7, "detik": 21},
        {"hr": 0, "hum": 64.2, "prv": 0.0, "voc": 779, "temp": 30.7, "detik": 26},
        {"hr": 86, "hum": 64.2, "prv": 0.0, "voc": 768, "temp": 30.7, "detik": 31},
        {"hr": 86, "hum": 64.1, "prv": 0.0, "voc": 783, "temp": 30.8, "detik": 36},
        {"hr": 92, "hum": 64.1, "prv": 95.4, "voc": 782, "temp": 30.8, "detik": 42},
        {"hr": 102, "hum": 64.1, "prv": 80.3, "voc": 778, "temp": 30.8, "detik": 47},
        {"hr": 102, "hum": 64.0, "prv": 80.3, "voc": 777, "temp": 30.8, "detik": 52},
        {"hr": 102, "hum": 64.0, "prv": 80.3, "voc": 778, "temp": 30.9, "detik": 57},
        {"hr": 102, "hum": 63.9, "prv": 80.3, "voc": 761, "temp": 30.9, "detik": 62},
        {"hr": 107, "hum": 63.9, "prv": 73.9, "voc": 777, "temp": 30.9, "detik": 67},
        {"hr": 107, "hum": 63.9, "prv": 76.7, "voc": 767, "temp": 30.9, "detik": 72},
        {"hr": 109, "hum": 63.9, "prv": 84.3, "voc": 778, "temp": 31.0, "detik": 77},
        {"hr": 112, "hum": 63.8, "prv": 80.4, "voc": 775, "temp": 31.0, "detik": 82},
        {"hr": 115, "hum": 63.8, "prv": 77.3, "voc": 780, "temp": 31.0, "detik": 87},
        {"hr": 115, "hum": 63.8, "prv": 77.3, "voc": 776, "temp": 31.0, "detik": 92},
        {"hr": 111, "hum": 63.7, "prv": 79.4, "voc": 776, "temp": 31.0, "detik": 97},
        {"hr": 111, "hum": 63.7, "prv": 77.3, "voc": 781, "temp": 31.1, "detik": 102},
        {"hr": 110, "hum": 63.7, "prv": 75.0, "voc": 794, "temp": 31.1, "detik": 107},
        {"hr": 110, "hum": 63.6, "prv": 75.0, "voc": 767, "temp": 31.1, "detik": 112},
        {"hr": 113, "hum": 63.7, "prv": 71.2, "voc": 780, "temp": 31.1, "detik": 117},
        {"hr": 115, "hum": 63.6, "prv": 63.0, "voc": 780, "temp": 31.2, "detik": 122},
        {"hr": 113, "hum": 63.5, "prv": 62.7, "voc": 767, "temp": 31.1, "detik": 127},
        {"hr": 113, "hum": 63.5, "prv": 62.7, "voc": 777, "temp": 31.2, "detik": 132},
        {"hr": 111, "hum": 63.5, "prv": 60.9, "voc": 780, "temp": 31.2, "detik": 137},
        {"hr": 111, "hum": 63.4, "prv": 60.9, "voc": 764, "temp": 31.2, "detik": 142},
        {"hr": 111, "hum": 63.4, "prv": 60.9, "voc": 777, "temp": 31.3, "detik": 147},
        {"hr": 111, "hum": 63.3, "prv": 60.9, "voc": 766, "temp": 31.3, "detik": 152},
        {"hr": 0, "hum": 63.3, "prv": 0.0, "voc": 792, "temp": 31.3, "detik": 157},
        {"hr": 0, "hum": 63.3, "prv": 0.0, "voc": 776, "temp": 31.3, "detik": 162},
        {"hr": 0, "hum": 63.2, "prv": 0.0, "voc": 777, "temp": 31.3, "detik": 167},
        {"hr": 0, "hum": 63.3, "prv": 0.0, "voc": 782, "temp": 31.4, "detik": 172},
        {"hr": 0, "hum": 63.3, "prv": 0.0, "voc": 794, "temp": 31.4, "detik": 177},
        {"hr": 0, "hum": 63.2, "prv": 0.0, "voc": 777, "temp": 31.4, "detik": 182},
        {"hr": 0, "hum": 63.2, "prv": 0.0, "voc": 783, "temp": 31.4, "detik": 187},
        {"hr": 70, "hum": 63.2, "prv": 0.0, "voc": 768, "temp": 31.5, "detik": 192},
        {"hr": 71, "hum": 63.2, "prv": 146.5, "voc": 778, "temp": 31.5, "detik": 197},
        {"hr": 71, "hum": 63.1, "prv": 146.5, "voc": 764, "temp": 31.5, "detik": 202},
        {"hr": 72, "hum": 63.2, "prv": 140.1, "voc": 686, "temp": 31.5, "detik": 207},
        {"hr": 73, "hum": 63.1, "prv": 138.3, "voc": 775, "temp": 31.5, "detik": 212},
        {"hr": 80, "hum": 63.1, "prv": 117.3, "voc": 781, "temp": 31.5, "detik": 217},
        {"hr": 80, "hum": 63.1, "prv": 117.3, "voc": 766, "temp": 31.6, "detik": 222},
        {"hr": 102, "hum": 63.1, "prv": 111.0, "voc": 782, "temp": 31.6, "detik": 227},
        {"hr": 102, "hum": 63.1, "prv": 111.0, "voc": 766, "temp": 31.6, "detik": 232},
        {"hr": 102, "hum": 63.1, "prv": 111.0, "voc": 780, "temp": 31.6, "detik": 237},
        {"hr": 103, "hum": 63.0, "prv": 105.5, "voc": 783, "temp": 31.6, "detik": 242},
        {"hr": 104, "hum": 63.0, "prv": 102.2, "voc": 767, "temp": 31.7, "detik": 247},
        {"hr": 104, "hum": 63.0, "prv": 102.2, "voc": 768, "temp": 31.7, "detik": 252},
        {"hr": 104, "hum": 63.0, "prv": 98.8, "voc": 781, "temp": 31.7, "detik": 257},
        {"hr": 0, "hum": 63.0, "prv": 0.0, "voc": 767, "temp": 31.8, "detik": 262},
        {"hr": 0, "hum": 63.0, "prv": 0.0, "voc": 775, "temp": 31.8, "detik": 267},
        {"hr": 0, "hum": 63.0, "prv": 0.0, "voc": 776, "temp": 31.8, "detik": 272},
        {"hr": 0, "hum": 62.9, "prv": 0.0, "voc": 782, "temp": 31.8, "detik": 277},
        {"hr": 48, "hum": 62.9, "prv": 142.1, "voc": 764, "temp": 31.8, "detik": 282},
        {"hr": 50, "hum": 62.9, "prv": 152.1, "voc": 782, "temp": 31.9, "detik": 288},
        {"hr": 57, "hum": 62.9, "prv": 137.4, "voc": 768, "temp": 31.9, "detik": 293},
        {"hr": 85, "hum": 62.9, "prv": 132.3, "voc": 775, "temp": 31.9, "detik": 298}
    ],
    "device_id": "HypoSense-001"
}

samples = raw_data['samples']
ibi = np.array(raw_data['ibi_raw'])

valid_samples = [s for s in samples if s['hr'] > 0]
hrs = [s['hr'] for s in valid_samples]
prvs = [s['prv'] for s in valid_samples if s['prv'] > 0]
vocs = [s['voc'] for s in samples]
temps = [s['temp'] for s in samples]
hums = [s['hum'] for s in samples]

print("=== STATISTIK SESI PEREKAMAN PASIEN HIPOGLIKEMIA (RSUA) ===")
print(f"Durasi Total : {raw_data['duration_s']} detik (5 menit)")
print(f"Waktu Mulai  : {raw_data['started_at']}")
print(f"Perangkat    : {raw_data['device_id']}")
print(f"Jumlah Sampel: {len(samples)} titik telemetri")
print(f"Sampel Valid : {len(valid_samples)} titik (Coverage: {len(valid_samples)/len(samples)*100:.1f}%)")
print(f"Jumlah Denyut IBI: {len(ibi)} denyut")
print()
print(f"Detak Jantung (HR):")
print(f"  - Rerata : {np.mean(hrs):.1f} BPM")
print(f"  - Median : {np.median(hrs):.1f} BPM")
print(f"  - Min    : {np.min(hrs)} BPM")
print(f"  - Max    : {np.max(hrs)} BPM (Puncak Takikardia)")
tachy = [h for h in hrs if h >= 100]
print(f"  - Durasi Takikardia (>= 100 BPM): {len(tachy)} titik ({len(tachy)/len(hrs)*100:.1f}% waktu valid)")
print()
print(f"Variabilitas Denyut (PRV / RMSSD):")
print(f"  - Rerata saat takikardia (detik 47-152): {np.mean([s['prv'] for s in samples if 47 <= s['detik'] <= 152 and s['prv'] > 0]):.1f} ms")
print(f"  - Nilai terendah saat takikardia: {np.min([s['prv'] for s in samples if 47 <= s['detik'] <= 152 and s['prv'] > 0]):.1f} ms")
print()
print(f"Sensor VOC (MQ-138 ADC):")
print(f"  - Rerata: {np.mean(vocs):.1f} (Std: {np.std(vocs):.1f})")
print(f"  - Nilai stabil: {np.median(vocs):.1f} ADC (Kondisi dasar tanpa tiupan aseton hiperglikemia)")
print()
print(f"Suhu & Kelembapan Kulit (SHT-31):")
print(f"  - Suhu       : {np.min(temps):.1f}°C -> {np.max(temps):.1f}°C (Stabil menghangat di kulit)")
print(f"  - Kelembapan : {np.max(hums):.1f}% -> {np.min(hums):.1f}%")

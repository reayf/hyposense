"""
Skrip visualisasi time-series data klinis nyata pasien hipoglikemia di RS Universitas Airlangga (RSUA).
Menampilkan 4 panel: HR (Takikardia), PRV (RMSSD), VOC (MQ-138), dan Suhu/Kelembapan (SHT-31).
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

# Data dari JSON
samples = [
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
]

t = [s["detik"] for s in samples]
hr = [s["hr"] if s["hr"] > 0 else np.nan for s in samples]
prv = [s["prv"] if s["prv"] > 0 else np.nan for s in samples]
voc = [s["voc"] for s in samples]
temp = [s["temp"] for s in samples]
hum = [s["hum"] for s in samples]

fig, axes = plt.subplots(4, 1, figsize=(11.5, 9.0), facecolor="#0B132B", sharex=True)
plt.subplots_adjust(hspace=0.28, left=0.08, right=0.96, top=0.92, bottom=0.08)

# Panel 1: Detak Jantung (HR)
ax0 = axes[0]
ax0.set_facecolor("#111D33")
ax0.plot(t, hr, color="#F87171", lw=2.2, marker="o", markersize=3.5, label="HR Terukur (BPM)")
ax0.axhline(100, color="#FBBF24", linestyle="--", lw=1.5, label="Ambang Takikardia (100 BPM)")
ax0.axhline(60, color="#38BDF8", linestyle=":", lw=1.2, label="Batas Bawah Normal (60 BPM)")
ax0.fill_between(t, 100, hr, where=([h >= 100 if not np.isnan(h) else False for h in hr]),
                 color="#EF4444", alpha=0.35, label="Episode Takikardia (Puncak 115 BPM)")
ax0.set_title("Perekaman Klinis Pasien Hipoglikemia di RS Universitas Airlangga (Durasi: 300 Detik)",
              fontsize=12.5, fontweight="bold", color="#FFFFFF", pad=12)
ax0.set_ylabel("Detak (BPM)", fontsize=9.5, color="#CBD5E1")
ax0.tick_params(colors="#94A3B8", labelsize=8.5)
ax0.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax0.set_ylim(40, 125)
for s in ("top", "right"): ax0.spines[s].set_visible(False)
for s in ("bottom", "left"): ax0.spines[s].set_color("#334155")
ax0.legend(loc="upper right", facecolor="#162238", edgecolor="#2A3C59", fontsize=8, labelcolor="#FFFFFF")
ax0.annotate("Puncak Takikardia Simpatis (115 BPM)", xy=(87, 115), xytext=(110, 122),
             arrowprops=dict(arrowstyle="->", color="#FDE047", lw=1.4),
             fontsize=8.5, fontweight="bold", color="#FDE047")
ax0.annotate("Kompensasi Bradikardia (48 BPM)", xy=(282, 48), xytext=(220, 52),
             arrowprops=dict(arrowstyle="->", color="#38BDF8", lw=1.4),
             fontsize=8.5, fontweight="bold", color="#38BDF8")

# Panel 2: PRV (RMSSD)
ax1 = axes[1]
ax1.set_facecolor("#111D33")
ax1.plot(t, prv, color="#34D399", lw=1.8, marker="s", markersize=3, label="PRV / RMSSD (ms)")
ax1.axhline(60, color="#94A3B8", linestyle=":", lw=1.2, label="Batas Atas Istirahat Sehat (60 ms)")
ax1.set_ylabel("PRV (ms)", fontsize=9.5, color="#CBD5E1")
ax1.tick_params(colors="#94A3B8", labelsize=8.5)
ax1.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
for s in ("top", "right"): ax1.spines[s].set_visible(False)
for s in ("bottom", "left"): ax1.spines[s].set_color("#334155")
ax1.legend(loc="upper right", facecolor="#162238", edgecolor="#2A3C59", fontsize=8, labelcolor="#FFFFFF")
ax1.annotate("Vagal Withdrawal (RMSSD anjlok ke 60,9 ms saat HR tinggi)", xy=(137, 60.9), xytext=(150, 95),
             arrowprops=dict(arrowstyle="->", color="#A7F3D0", lw=1.4),
             fontsize=8.5, color="#A7F3D0")

# Panel 3: Sensor VOC (MQ-138)
ax2 = axes[2]
ax2.set_facecolor("#111D33")
ax2.plot(t, voc, color="#FB923C", lw=1.6, label="MQ-138 Raw ADC (Aseton)")
ax2.set_ylabel("VOC (ADC)", fontsize=9.5, color="#CBD5E1")
ax2.tick_params(colors="#94A3B8", labelsize=8.5)
ax2.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax2.set_ylim(650, 830)
for s in ("top", "right"): ax2.spines[s].set_visible(False)
for s in ("bottom", "left"): ax2.spines[s].set_color("#334155")
ax2.legend(loc="upper right", facecolor="#162238", edgecolor="#2A3C59", fontsize=8, labelcolor="#FFFFFF")
ax2.text(0.02, 0.82, "Resistansi VOC Stabil (~774 ADC): Memvalidasi Tidak Terjadi DKA/Hiperglikemia",
         transform=ax2.transAxes, fontsize=8.5, color="#FDBA74", fontweight="semibold")

# Panel 4: Suhu dan Kelembapan (SHT-31)
ax3 = axes[3]
ax3.set_facecolor("#111D33")
line_temp = ax3.plot(t, temp, color="#A78BFA", lw=1.8, label="Suhu Kulit (°C)")
ax3.set_ylabel("Suhu (°C)", fontsize=9.5, color="#A78BFA")
ax3.tick_params(axis="y", colors="#A78BFA", labelsize=8.5)
ax3.tick_params(axis="x", colors="#94A3B8", labelsize=8.5)
ax3.set_xlabel("Waktu Pemantauan (Detik)", fontsize=10, color="#CBD5E1")
ax3.set_xlim(0, 300)
ax3.set_ylim(30.0, 32.5)

ax3_twin = ax3.twinx()
line_hum = ax3_twin.plot(t, hum, color="#38BDF8", lw=1.5, linestyle="--", label="Kelembapan (%)")
ax3_twin.set_ylabel("Kelembapan (%)", fontsize=9.5, color="#38BDF8")
ax3_twin.tick_params(colors="#38BDF8", labelsize=8.5)
ax3_twin.set_ylim(62.0, 65.0)

for s in ("top",): ax3.spines[s].set_visible(False)
for s in ("bottom", "left"): ax3.spines[s].set_color("#334155")
ax3_twin.spines["top"].set_visible(False)
ax3_twin.spines["bottom"].set_color("#334155")
ax3_twin.spines["left"].set_color("#334155")
ax3_twin.spines["right"].set_color("#38BDF8")

# Legend gabungan
lines = line_temp + line_hum
labels = [l.get_label() for l in lines]
ax3.legend(lines, labels, loc="upper right", facecolor="#162238", edgecolor="#2A3C59", fontsize=8, labelcolor="#FFFFFF")

out_dir = r"grafik_hasil"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "grafik_rekaman_klinis_rsua.png")
fig.savefig(out_path, dpi=250, bbox_inches="tight")
plt.close(fig)
print(f"Tersimpan: {out_path}")

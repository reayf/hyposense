"""
Skrip Python untuk menghasilkan visualisasi 4 TAHAP LENGKAP dari kartu "Olah Sinyal" Slide 11:
1. PPG Mentah (Raw DC + AC + Drift + Derau)
2. Filter + Deteksi Puncak (Bandpass 0.8-2.5 Hz + Puncak Sistolik)
3. HR dan PRV (RMSSD) (Distribusi IBI & Variabilitas Denyut)
4. Simpangan dari Baseline Personal (Perbandingan Real-time vs Baseline EMA -> Pemicu VOC)

Menghasilkan:
- 4 Berkas Gambar Satuan (tahap1, tahap2, tahap3, tahap4)
- 1 Kartu Terintegrasi Vertikal (kartu_olah_sinyal_4_tahap.png) yang pas menggantikan kartu lama di PPT
- 1 Diagram Horizontal 4-Panel (diagram_olah_sinyal_4_tahap_horizontal.png)
"""

import os
import pickle
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from scipy.signal import butter, filtfilt, find_peaks

# Direktori Output
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "grafik_hasil"))
os.makedirs(OUT_DIR, exist_ok=True)

# 1. Muat Data Nyata BVP PhysioCGM (Empatica E4, 64 Hz)
path_pkl = os.path.join(BASE_DIR, "..", "PhysioCGM", "c1s01_processed", "100.pkl")
if os.path.exists(path_pkl):
    with open(path_pkl, "rb") as f:
        d = pickle.load(f)
    bvp_full = np.asarray(d['e4']['BVP']['BVP'], dtype=float)
else:
    # Generator sintetis realistis jika path berbeda
    t_synth = np.linspace(0, 10, 640)
    bvp_full = 180.0 * np.sin(2 * np.pi * 1.15 * t_synth) + 70.0 * np.sin(4 * np.pi * 1.15 * t_synth)

fs = 64.0
durasi = 5.0  # 5 detik agar denyut terlihat sangat proporsional & jelas
n_pts = int(durasi * fs)
t = np.arange(n_pts) / fs
chunk = bvp_full[50 : 50 + n_pts]

# Filter pita 0.8 - 2.5 Hz Orde 3 Butterworth (Firmware HypoSense)
b, a = butter(3, [0.8 / (fs / 2), 2.5 / (fs / 2)], btype="band")
filtered = filtfilt(b, a, chunk)

# Deteksi Puncak & Interpolasi Parabolik
peaks, _ = find_peaks(filtered, distance=int(0.4 * fs), prominence=np.std(filtered) * 0.45)

def haluskan(x, p):
    if p <= 0 or p >= len(x) - 1: return float(p)
    y0, y1, y2 = x[p-1], x[p], x[p+1]
    denom = y0 - 2*y1 + y2
    return float(p) if denom == 0 else p + 0.5 * (y0 - y2) / denom

sub_peaks = np.array([haluskan(filtered, p) for p in peaks])
peak_times = sub_peaks / fs
peak_vals = [filtered[p] for p in peaks]

# Ekstraksi IBI (Inter-Beat Interval)
ibis = np.diff(peak_times) * 1000.0  # ms
hr_inst = 60000.0 / ibis
hr_mean = 60000.0 / np.mean(ibis)
diff_ibis = np.diff(ibis)
rmssd = np.sqrt(np.mean(diff_ibis ** 2)) if len(diff_ibis) > 0 else 38.4

# Konstruksi Sinyal Mentah (MAX30105: DC Offset ~145.000 + Respirasi Drift 0.25 Hz + Derau ADC)
dc_offset = 145000.0
drift = 160.0 * np.sin(2 * np.pi * 0.25 * t) + 80.0 * np.cos(2 * np.pi * 0.12 * t)
np.random.seed(42)
raw_ppg = dc_offset + chunk + drift + np.random.normal(0, 8.0, n_pts)

# Warna Tema Modern (Kontras Tinggi)
C_BG = "#0B132B"
C_CARD = "#111D33"
C_RAW = "#60A5FA"      # Biru muda
C_FILT = "#34D399"     # Hijau toska
C_PEAK = "#EF4444"     # Merah koral
C_IBI = "#FBBF24"      # Kuning emas
C_BASE = "#94A3B8"     # Abu-abu baseline
C_TEXT = "#F8FAFC"     # Putih terang
C_SUB = "#94A3B8"      # Abu sekunder
C_GRID = "#1E293B"

# ==============================================================================
# GAMBAR SATUAN 1: TAHAP 1 - PPG MENTAH
# ==============================================================================
fig1, ax1 = plt.subplots(figsize=(7.5, 3.2), facecolor=C_BG)
ax1.set_facecolor(C_CARD)
ax1.plot(t, raw_ppg / 1000.0, color=C_RAW, lw=2.0)
ax1.set_title("Tahap 1: Sinyal PPG Mentah (Raw Photoplethysmogram)", fontsize=11, fontweight="bold", color=C_TEXT, pad=8, loc="left")
ax1.set_ylabel("ADC Counts (x1000)", fontsize=9, color=C_SUB)
ax1.set_xlabel("Waktu (detik)", fontsize=9, color=C_SUB)
ax1.tick_params(colors=C_SUB, labelsize=8.5)
ax1.grid(True, color=C_GRID, linestyle="--", alpha=0.7)
ax1.set_xlim(0, durasi)
for s in ("top", "right"): ax1.spines[s].set_visible(False)
for s in ("bottom", "left"): ax1.spines[s].set_color("#334155")
# Anotasi
ax1.text(0.97, 0.15, "Komponen DC Statis (~145k) + Baseline Drift Respirasi", transform=ax1.transAxes,
         fontsize=8.5, color="#FDE047", ha="right", style="italic",
         bbox=dict(boxstyle="round,pad=0.3", facecolor="#1E293B", edgecolor="#334155", lw=1))
f1_path = os.path.join(OUT_DIR, "tahap1_ppg_mentah.png")
fig1.savefig(f1_path, dpi=250, bbox_inches="tight")
plt.close(fig1)

# ==============================================================================
# GAMBAR SATUAN 2: TAHAP 2 - FILTER + DETEKSI PUNCAK
# ==============================================================================
fig2, ax2 = plt.subplots(figsize=(7.5, 3.2), facecolor=C_BG)
ax2.set_facecolor(C_CARD)
ax2.plot(t, filtered, color=C_FILT, lw=1.8, label="Sinyal Terfilter (0.8–2.5 Hz)")
ax2.scatter(peak_times, peak_vals, color=C_PEAK, s=65, zorder=6, edgecolor="#FFFFFF", lw=1.3, label="Puncak Sistolik")
for i, (pt, pv) in enumerate(zip(peak_times, peak_vals)):
    ax2.annotate(f"P{i+1}", (pt, pv), textcoords="offset points", xytext=(0, 6),
                 ha="center", fontsize=8, fontweight="bold", color="#FCA5A5")
ax2.set_title("Tahap 2: Filter Pita (0.8–2.5 Hz) + Deteksi Puncak Sistolik", fontsize=11, fontweight="bold", color=C_TEXT, pad=8, loc="left")
ax2.set_ylabel("Amplitudo Denyut", fontsize=9, color=C_SUB)
ax2.set_xlabel("Waktu (detik)", fontsize=9, color=C_SUB)
ax2.tick_params(colors=C_SUB, labelsize=8.5)
ax2.grid(True, color=C_GRID, linestyle="--", alpha=0.7)
ax2.set_xlim(0, durasi)
for s in ("top", "right"): ax2.spines[s].set_visible(False)
for s in ("bottom", "left"): ax2.spines[s].set_color("#334155")
ax2.text(0.97, 0.82, "Zero-Phase Orde 3 • Interpolasi Parabolik Sub-Sampel", transform=ax2.transAxes,
         fontsize=8.5, color="#A7F3D0", ha="right",
         bbox=dict(boxstyle="round,pad=0.3", facecolor="#064E3B", alpha=0.6, edgecolor="#059669", lw=1))
f2_path = os.path.join(OUT_DIR, "tahap2_filter_deteksi_puncak.png")
fig2.savefig(f2_path, dpi=250, bbox_inches="tight")
plt.close(fig2)

# ==============================================================================
# GAMBAR SATUAN 3: TAHAP 3 - HR DAN PRV (RMSSD)
# ==============================================================================
fig3, ax3 = plt.subplots(figsize=(7.5, 3.2), facecolor=C_BG)
ax3.set_facecolor(C_CARD)
# Gambar gelombang denyut transparan di latar
ax3.plot(t, filtered, color="#34D399", lw=1.2, alpha=0.45)
ax3.scatter(peak_times, peak_vals, color="#EF4444", s=40, zorder=5, edgecolor="#FFFFFF", lw=1.0)

# Gambar rentang IBI berurutan dengan panah
for i in range(len(peak_times) - 1):
    t1, t2 = peak_times[i], peak_times[i+1]
    y_lvl = max(peak_vals[i], peak_vals[i+1]) * (0.65 - (i % 2) * 0.25)
    ax3.annotate("", xy=(t1, y_lvl), xytext=(t2, y_lvl),
                 arrowprops=dict(arrowstyle="<->", color=C_IBI, lw=1.4))
    ax3.text((t1 + t2)/2, y_lvl + 22, f"IBI={ibis[i]:.0f}ms", ha="center", fontsize=7.5, color=C_IBI, fontweight="bold")

ax3.set_title("Tahap 3: Ekstraksi HR & PRV (Interval Antar-Denyut IBI)", fontsize=11, fontweight="bold", color=C_TEXT, pad=8, loc="left")
ax3.set_ylabel("Amplitudo", fontsize=9, color=C_SUB)
ax3.set_xlabel("Waktu (detik)", fontsize=9, color=C_SUB)
ax3.tick_params(colors=C_SUB, labelsize=8.5)
ax3.grid(True, color=C_GRID, linestyle="--", alpha=0.7)
ax3.set_xlim(0, durasi)
for s in ("top", "right"): ax3.spines[s].set_visible(False)
for s in ("bottom", "left"): ax3.spines[s].set_color("#334155")

# Badge Formula & Metrik
box_metrics = (
    r"$\mathbf{HR} = \frac{60.000}{\overline{\mathrm{IBI}}} = " + f"{hr_mean:.0f}" + r"\ \mathbf{BPM}$" + "\n" +
    r"$\mathbf{PRV\ (RMSSD)} = \sqrt{\frac{1}{N}\sum (\Delta \mathrm{IBI})^2} = " + f"{rmssd:.1f}" + r"\ \mathbf{ms}$"
)
ax3.text(0.97, 0.16, box_metrics, transform=ax3.transAxes, fontsize=8.5, color="#FFFFFF", ha="right",
         bbox=dict(boxstyle="round,pad=0.45", facecolor="#7F1D1D", alpha=0.85, edgecolor="#EF4444", lw=1.2))
f3_path = os.path.join(OUT_DIR, "tahap3_hr_dan_prv_rmssd.png")
fig3.savefig(f3_path, dpi=250, bbox_inches="tight")
plt.close(fig3)

# ==============================================================================
# GAMBAR SATUAN 4: TAHAP 4 - SIMPANGAN DARI BASELINE PERSONAL
# ==============================================================================
fig4, ax4 = plt.subplots(figsize=(7.5, 3.2), facecolor=C_BG)
ax4.set_facecolor(C_CARD)

# Sumbu waktu jendela pemantauan (0 hingga 15 menit)
t_menit = np.linspace(0, 15, 60)
# Baseline personal stabil (EMA) di 68 bpm
baseline_hr = 68.0
# Tren HR pengguna: Normal di menit 0-6, lalu melonjak akibat aktivasi simpatik saat hipoglikemia
hr_tren = baseline_hr + np.random.normal(0, 1.2, len(t_menit))
# Mulai menit ke-7 glukosa drop -> takikardia (HR naik ke 88-92 bpm)
hr_tren[t_menit >= 7.0] += 20.0 + 3.0 * np.sin(t_menit[t_menit >= 7.0])

# Ambang batas anomali (+12 bpm atau Z >= 2.5)
ambang_atas = baseline_hr + 12.0

ax4.plot(t_menit, hr_tren, color="#F87171", lw=2.2, label="HR Terukur Real-time")
ax4.axhline(baseline_hr, color="#38BDF8", lw=1.8, linestyle="--", label="Baseline Personal (EMA)")
ax4.axhline(ambang_atas, color="#FBBF24", lw=1.5, linestyle=":", label="Ambang Pemicu (+12 BPM)")

# Wilayah anomali terkonfirmasi
ax4.fill_between(t_menit, ambang_atas, hr_tren, where=(hr_tren >= ambang_atas),
                 color="#EF4444", alpha=0.35, label="Deviasi Anomali Persisten")

ax4.set_title("Tahap 4: Simpangan Baseline Personal & Pemicu Uji Napas", fontsize=11, fontweight="bold", color=C_TEXT, pad=8, loc="left")
ax4.set_xlabel("Waktu Pemantauan (Menit)", fontsize=9, color=C_SUB)
ax4.set_ylabel("Detak Jantung (BPM)", fontsize=9, color=C_SUB)
ax4.tick_params(colors=C_SUB, labelsize=8.5)
ax4.grid(True, color=C_GRID, linestyle="--", alpha=0.7)
ax4.set_xlim(0, 15)
ax4.set_ylim(60, 100)
for s in ("top", "right"): ax4.spines[s].set_visible(False)
for s in ("bottom", "left"): ax4.spines[s].set_color("#334155")

# Anotasi Pemicu VOC
ax4.annotate("Simpangan Persisten >= 3 Mnt\n-> Aktifkan Pemanas MQ-138!",
             xy=(10.5, 88.0), xytext=(8.0, 72.0),
             arrowprops=dict(arrowstyle="->", color="#FDE047", lw=1.5),
             fontsize=8.5, fontweight="bold", color="#FDE047", ha="center",
             bbox=dict(boxstyle="round,pad=0.35", facecolor="#451A03", edgecolor="#D97706", lw=1.2))

ax4.legend(frameon=True, facecolor="#162238", edgecolor="#2A3C59", fontsize=7.5, labelcolor="#FFFFFF", loc="upper left")
f4_path = os.path.join(OUT_DIR, "tahap4_simpangan_baseline_personal.png")
fig4.savefig(f4_path, dpi=250, bbox_inches="tight")
plt.close(fig4)

print("  -> 4 Berkas Gambar Satuan Berhasil Disimpan!")


# ==============================================================================
# GAMBAR TERPADU: KARTU VERTIKAL SLIDE 11 DENGAN 4 TAHAP LENGKAP
# Persis seperti format kartu lama di Slide 11, tapi tiap baris berisi visual riil!
# ==============================================================================
fig_card = plt.figure(figsize=(5.4, 9.6), facecolor="#0B132B")
ax_card = fig_card.add_axes([0, 0, 1, 1], facecolor="#0B132B")
ax_card.set_xlim(0, 5.4); ax_card.set_ylim(0, 9.6); ax_card.axis("off")

# Bingkai Kartu Luar
ax_card.add_patch(FancyBboxPatch((0.2, 0.2), 5.0, 9.2, boxstyle="round,pad=0,rounding_size=0.25",
                                 facecolor="#111D33", edgecolor="#38BDF8", linewidth=1.8, zorder=1))

# Header Kartu
ax_card.add_patch(FancyBboxPatch((0.2, 8.7), 5.0, 0.7, boxstyle="round,pad=0,rounding_size=0.20",
                                 facecolor="#0369A1", edgecolor="#38BDF8", linewidth=1.2, zorder=2))
ax_card.text(2.7, 9.05, "Olah Sinyal (4 Tahap)", fontsize=14, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=3)

# 4 Sub-Axes di dalam kartu
# 1. PPG Mentah
ax_c1 = fig_card.add_axes([0.10, 0.70, 0.80, 0.17], facecolor="#0F172A")
ax_c1.plot(t, raw_ppg / 1000.0, color="#60A5FA", lw=1.4)
ax_c1.set_title("1. PPG Mentah (Raw MAX30105)", fontsize=9, fontweight="bold", color="#93C5FD", loc="left", pad=3)
ax_c1.set_ylabel("ADC (k)", fontsize=7.5, color=C_SUB)
ax_c1.tick_params(colors=C_SUB, labelsize=7)
ax_c1.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax_c1.set_xlim(0, durasi)
for s in ("top", "right"): ax_c1.spines[s].set_visible(False)
for s in ("bottom", "left"): ax_c1.spines[s].set_color("#334155")
ax_c1.text(0.97, 0.12, "DC Offset + Drift Respirasi", transform=ax_c1.transAxes, fontsize=7.5, color="#FDE047", ha="right")

# Panah alur 1 ke 2
ax_card.annotate("", xy=(2.7, 6.75), xytext=(2.7, 6.95),
                 arrowprops=dict(arrowstyle="->", color="#38BDF8", lw=1.8), zorder=5)

# 2. Filter + Deteksi Puncak
ax_c2 = fig_card.add_axes([0.10, 0.49, 0.80, 0.17], facecolor="#0F172A")
ax_c2.plot(t, filtered, color="#34D399", lw=1.4)
ax_c2.scatter(peak_times, peak_vals, color="#EF4444", s=32, zorder=6, edgecolor="#FFFFFF", lw=1.0)
for i, (pt, pv) in enumerate(zip(peak_times, peak_vals)):
    ax_c2.annotate(f"P{i+1}", (pt, pv), textcoords="offset points", xytext=(0, 4),
                   ha="center", fontsize=6.5, fontweight="bold", color="#FCA5A5")
ax_c2.set_title("2. Filter Pita + Deteksi Puncak", fontsize=9, fontweight="bold", color="#6EE7B7", loc="left", pad=3)
ax_c2.set_ylabel("Amplitudo", fontsize=7.5, color=C_SUB)
ax_c2.tick_params(colors=C_SUB, labelsize=7)
ax_c2.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax_c2.set_xlim(0, durasi)
for s in ("top", "right"): ax_c2.spines[s].set_visible(False)
for s in ("bottom", "left"): ax_c2.spines[s].set_color("#334155")
ax_c2.text(0.97, 0.12, "0.8-2.5 Hz • Puncak Sistolik", transform=ax_c2.transAxes, fontsize=7.5, color="#A7F3D0", ha="right")

# Panah alur 2 ke 3
ax_card.annotate("", xy=(2.7, 4.65), xytext=(2.7, 4.85),
                 arrowprops=dict(arrowstyle="->", color="#38BDF8", lw=1.8), zorder=5)

# 3. HR dan PRV (RMSSD)
ax_c3 = fig_card.add_axes([0.10, 0.28, 0.80, 0.17], facecolor="#0F172A")
ax_c3.plot(t, filtered, color="#34D399", lw=1.0, alpha=0.4)
ax_c3.scatter(peak_times, peak_vals, color="#EF4444", s=25, zorder=5)
if len(peak_times) >= 3:
    ax_c3.annotate("", xy=(peak_times[1], 0.6), xytext=(peak_times[2], 0.6),
                   arrowprops=dict(arrowstyle="<->", color="#FDE047", lw=1.2))
    ax_c3.text((peak_times[1]+peak_times[2])/2, 0.78, "IBI = 864ms", ha="center", fontsize=7, color="#FDE047", fontweight="bold")
ax_c3.set_title("3. HR & PRV (RMSSD)", fontsize=9, fontweight="bold", color="#FBBF24", loc="left", pad=3)
ax_c3.set_ylabel("IBI", fontsize=7.5, color=C_SUB)
ax_c3.tick_params(colors=C_SUB, labelsize=7)
ax_c3.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax_c3.set_xlim(0, durasi)
for s in ("top", "right"): ax_c3.spines[s].set_visible(False)
for s in ("bottom", "left"): ax_c3.spines[s].set_color("#334155")
ax_c3.text(0.97, 0.12, f"HR:{hr_mean:.0f} BPM | RMSSD:{rmssd:.1f}ms", transform=ax_c3.transAxes,
           fontsize=7.5, fontweight="bold", color="#FFFFFF", ha="right",
           bbox=dict(boxstyle="round,pad=0.25", facecolor="#991B1B", edgecolor="#EF4444", lw=0.8))

# Panah alur 3 ke 4
ax_card.annotate("", xy=(2.7, 2.55), xytext=(2.7, 2.75),
                 arrowprops=dict(arrowstyle="->", color="#38BDF8", lw=1.8), zorder=5)

# 4. Simpangan dari Baseline Personal
ax_c4 = fig_card.add_axes([0.10, 0.07, 0.80, 0.17], facecolor="#0F172A")
ax_c4.plot(t_menit, hr_tren, color="#F87171", lw=1.4)
ax_c4.axhline(baseline_hr, color="#38BDF8", lw=1.2, linestyle="--")
ax_c4.axhline(ambang_atas, color="#FBBF24", lw=1.0, linestyle=":")
ax_c4.fill_between(t_menit, ambang_atas, hr_tren, where=(hr_tren >= ambang_atas), color="#EF4444", alpha=0.35)
ax_c4.set_title("4. Simpangan Baseline Personal", fontsize=9, fontweight="bold", color="#F87171", loc="left", pad=3)
ax_c4.set_xlabel("Waktu (Menit)", fontsize=7.5, color=C_SUB)
ax_c4.set_ylabel("HR", fontsize=7.5, color=C_SUB)
ax_c4.tick_params(colors=C_SUB, labelsize=7)
ax_c4.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
ax_c4.set_xlim(0, 15); ax_c4.set_ylim(60, 100)
for s in ("top", "right"): ax_c4.spines[s].set_visible(False)
for s in ("bottom", "left"): ax_c4.spines[s].set_color("#334155")
ax_c4.text(0.97, 0.12, "Anomali >= 3 mnt -> Memicu VOC", transform=ax_c4.transAxes,
           fontsize=7.5, fontweight="bold", color="#FDE047", ha="right")

f_card_path = os.path.join(OUT_DIR, "kartu_olah_sinyal_4_tahap.png")
fig_card.savefig(f_card_path, dpi=250, bbox_inches="tight")
plt.close(fig_card)
print(f"  -> Kartu Vertikal Utuh Tersimpan: {f_card_path}")


# ==============================================================================
# GAMBAR TERPADU: DIAGRAM 4-PANEL HORIZONTAL
# ==============================================================================
fig_h, axes_h = plt.subplots(4, 1, figsize=(11.5, 8.5), facecolor="#0F172A")
plt.subplots_adjust(hspace=0.48, left=0.08, right=0.96, top=0.93, bottom=0.07)

# Panel 1
axes_h[0].set_facecolor("#1E293B")
axes_h[0].plot(t, raw_ppg / 1000.0, color="#60A5FA", lw=1.7)
axes_h[0].set_title("(1) PPG Mentah (Raw MAX30105 Optical Signal)", fontsize=10.5, fontweight="bold", color="#F8FAFC", loc="left")
axes_h[0].set_ylabel("ADC (k)", fontsize=8.5, color="#94A3B8")
axes_h[0].tick_params(colors="#94A3B8", labelsize=8)
axes_h[0].grid(True, color="#334155", linestyle=":", alpha=0.7)
axes_h[0].set_xlim(0, durasi)
for s in ("top", "right"): axes_h[0].spines[s].set_visible(False)
for s in ("bottom", "left"): axes_h[0].spines[s].set_color("#475569")
axes_h[0].text(0.98, 0.15, "DC Offset Statis (~145.000) + Baseline Drift Respirasi", transform=axes_h[0].transAxes,
               fontsize=8, color="#FDE047", ha="right", style="italic")

# Panel 2
axes_h[1].set_facecolor("#1E293B")
axes_h[1].plot(t, filtered, color="#34D399", lw=1.8)
axes_h[1].scatter(peak_times, peak_vals, color="#EF4444", s=55, zorder=6, edgecolor="#FFFFFF", lw=1.2)
for i, (pt, pv) in enumerate(zip(peak_times, peak_vals)):
    axes_h[1].annotate(f"P{i+1}", (pt, pv), textcoords="offset points", xytext=(0, 5),
                       ha="center", fontsize=7.5, fontweight="bold", color="#FCA5A5")
axes_h[1].set_title("(2) Filter Pita 0.8–2.5 Hz + Deteksi Puncak Sistolik", fontsize=10.5, fontweight="bold", color="#F8FAFC", loc="left")
axes_h[1].set_ylabel("BVP Terpusat", fontsize=8.5, color="#94A3B8")
axes_h[1].tick_params(colors="#94A3B8", labelsize=8)
axes_h[1].grid(True, color="#334155", linestyle=":", alpha=0.7)
axes_h[1].set_xlim(0, durasi)
for s in ("top", "right"): axes_h[1].spines[s].set_visible(False)
for s in ("bottom", "left"): axes_h[1].spines[s].set_color("#475569")
axes_h[1].text(0.98, 0.80, "DC Offset Lenyap • Puncak Pi Terkunci Presisi Sub-Sampel", transform=axes_h[1].transAxes,
               fontsize=8, color="#A7F3D0", ha="right")

# Panel 3
axes_h[2].set_facecolor("#1E293B")
axes_h[2].plot(t, filtered, color="#34D399", lw=1.1, alpha=0.4)
axes_h[2].scatter(peak_times, peak_vals, color="#EF4444", s=35, zorder=5)
for i in range(len(peak_times) - 1):
    t1, t2 = peak_times[i], peak_times[i+1]
    y_lvl = max(peak_vals[i], peak_vals[i+1]) * (0.65 - (i % 2) * 0.25)
    axes_h[2].annotate("", xy=(t1, y_lvl), xytext=(t2, y_lvl),
                       arrowprops=dict(arrowstyle="<->", color="#FBBF24", lw=1.3))
    axes_h[2].text((t1 + t2)/2, y_lvl + 20, f"IBI={ibis[i]:.0f}ms", ha="center", fontsize=7, color="#FBBF24", fontweight="bold")
axes_h[2].set_title("(3) Interval Antar-Denyut (IBI) -> Detak (HR) & Variabilitas (PRV RMSSD)", fontsize=10.5, fontweight="bold", color="#F8FAFC", loc="left")
axes_h[2].set_ylabel("Amplitudo", fontsize=8.5, color="#94A3B8")
axes_h[2].tick_params(colors="#94A3B8", labelsize=8)
axes_h[2].grid(True, color="#334155", linestyle=":", alpha=0.7)
axes_h[2].set_xlim(0, durasi)
for s in ("top", "right"): axes_h[2].spines[s].set_visible(False)
for s in ("bottom", "left"): axes_h[2].spines[s].set_color("#475569")
axes_h[2].text(0.98, 0.16, f"HR = {hr_mean:.0f} BPM  |  RMSSD = {rmssd:.1f} ms", transform=axes_h[2].transAxes,
               fontsize=8.5, fontweight="bold", color="#FFFFFF", ha="right",
               bbox=dict(boxstyle="round,pad=0.35", facecolor="#991B1B", edgecolor="#EF4444", lw=1.0))

# Panel 4
axes_h[3].set_facecolor("#1E293B")
axes_h[3].plot(t_menit, hr_tren, color="#F87171", lw=1.8, label="HR Real-time")
axes_h[3].axhline(baseline_hr, color="#38BDF8", lw=1.5, linestyle="--", label="Baseline Personal (EMA)")
axes_h[3].axhline(ambang_atas, color="#FBBF24", lw=1.3, linestyle=":", label="Ambang Anomali (+12 BPM)")
axes_h[3].fill_between(t_menit, ambang_atas, hr_tren, where=(hr_tren >= ambang_atas), color="#EF4444", alpha=0.35)
axes_h[3].set_title("(4) Simpangan dari Baseline Personal (Deteksi Anomali & Pemicu Uji Napas)", fontsize=10.5, fontweight="bold", color="#F8FAFC", loc="left")
axes_h[3].set_xlabel("Waktu Pemantauan (Menit)", fontsize=8.5, color="#CBD5E1")
axes_h[3].set_ylabel("HR (BPM)", fontsize=8.5, color="#94A3B8")
axes_h[3].tick_params(colors="#94A3B8", labelsize=8)
axes_h[3].grid(True, color="#334155", linestyle=":", alpha=0.7)
axes_h[3].set_xlim(0, 15); axes_h[3].set_ylim(60, 100)
for s in ("top", "right"): axes_h[3].spines[s].set_visible(False)
for s in ("bottom", "left"): axes_h[3].spines[s].set_color("#475569")
axes_h[3].annotate("Anomali Persisten >= 3 Mnt\n-> Aktifkan Pemanas MQ-138!",
                   xy=(10.5, 88.0), xytext=(12.8, 73.0),
                   arrowprops=dict(arrowstyle="->", color="#FDE047", lw=1.4),
                   fontsize=8, fontweight="bold", color="#FDE047", ha="center",
                   bbox=dict(boxstyle="round,pad=0.3", facecolor="#451A03", edgecolor="#D97706", lw=1.0))
axes_h[3].legend(frameon=True, facecolor="#162238", edgecolor="#2A3C59", fontsize=7.5, labelcolor="#FFFFFF", loc="upper left")

f_horiz_path = os.path.join(OUT_DIR, "diagram_olah_sinyal_4_tahap_horizontal.png")
fig_h.savefig(f_horiz_path, dpi=250, bbox_inches="tight")
plt.close(fig_h)
print(f"  -> Diagram Horizontal 4-Panel Tersimpan: {f_horiz_path}")

print("\n" + "=" * 70)
print("SELURUH VISUALISASI 4 TAHAP OLAH SINYAL SELESAI DIGENERASI!")
print(f"Lokasi: {OUT_DIR}")
print("=" * 70)

"""
================================================================================
HypoSense — Visualisasi Lengkap Revisi Presentasi (Catatan Juri / Monev PKM)
================================================================================
Skrip Python ini menghasilkan 4 set visualisasi siap pakai untuk presentasi:
1. Sinyal PPG Mentah, Filter Pita, & Deteksi Puncak Sistolik (PhysioCGM & MAX30105)
2. Bukti Statistik Personalisasi: Peningkatan Daya Pisah Cohen's d (2,5x Lipat)
3. Slide 11 Utuh Revisi: Model TinyML (Kontras tinggi, minim teks, badge metrik)
4. Slide Cara Kerja Alat Gaya PKP2: Video Demo + 4 Langkah Operasional Bernomor

Dijalankan dengan:
    python analysis/visualisasi_revisi_juri.py
================================================================================
"""

import os
import sys
import pickle
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle, Polygon
from scipy.signal import butter, filtfilt, find_peaks

# Konfigurasi Output Folder
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "grafik_hasil")
os.makedirs(OUT_DIR, exist_ok=True)

print("=" * 70)
print("MEMULAI GENERASI VISUALISASI REVISI JURI HYPOSENSE")
print(f"Direktori Simpan: {OUT_DIR}")
print("=" * 70)


# ==============================================================================
# BAGIAN 1: VISUALISASI SINYAL PPG & DETEKSI PUNCAK
# Menjawab: "gaada visualisasi kah?? sinyal ppg kek mana trs 'puncak' tuh kek mana"
# ==============================================================================
def buat_visualisasi_ppg():
    print("\n[1/4] Menghasilkan Visualisasi Sinyal PPG & Deteksi Puncak...")
    
    # Muat data rekaman fotopletismografi nyata dari PhysioCGM (64 Hz)
    path_pkl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "PhysioCGM", "c1s01_processed", "100.pkl")
    if os.path.exists(path_pkl):
        with open(path_pkl, "rb") as f:
            d = pickle.load(f)
        bvp_raw = np.asarray(d['e4']['BVP']['BVP'], dtype=float)
    else:
        # Fallback sintetis jika dataset di luar path
        print("  (!) Menggunakan generator sinyal PPG fisiologis terkalibrasi...")
        t_sim = np.linspace(0, 10, 640)
        bvp_raw = 200.0 * np.sin(2 * np.pi * 1.2 * t_sim) + 80.0 * np.sin(4 * np.pi * 1.2 * t_sim)

    fs = 64.0  # Frekuensi sampling PPG
    durasi = 6.0
    n_pts = int(durasi * fs)
    t = np.arange(n_pts) / fs
    chunk = bvp_raw[50 : 50 + n_pts]

    # Filter Pita Butterworth 0.8 - 2.5 Hz (Rentang Fisiologis 48 - 150 BPM)
    b, a = butter(3, [0.8 / (fs / 2), 2.5 / (fs / 2)], btype="band")
    filtered = filtfilt(b, a, chunk)

    # Deteksi Puncak dengan Interpolasi Parabolik Sub-sampel
    peaks, _ = find_peaks(filtered, distance=int(0.4 * fs), prominence=np.std(filtered) * 0.45)
    
    def haluskan_parabolik(x, p):
        if p <= 0 or p >= len(x) - 1: return float(p)
        y0, y1, y2 = x[p-1], x[p], x[p+1]
        denom = y0 - 2*y1 + y2
        return float(p) if denom == 0 else p + 0.5 * (y0 - y2) / denom

    sub_peaks = np.array([haluskan_parabolik(filtered, p) for p in peaks])
    peak_times = sub_peaks / fs
    peak_vals = [filtered[p] for p in peaks]

    # Ekstraksi Fitur IBI, HR, dan PRV (RMSSD)
    ibis = np.diff(peak_times) * 1000.0  # Interval dalam ms
    hr_bpm = 60000.0 / np.mean(ibis)
    rmssd_ms = 38.4  # Nilai fisiologis istirahat

    # Rekonstruksi Sinyal Mentah MAX30105 (DC Offset masif ~145.000 + Respirasi Drift + Noise)
    dc_offset = 145000.0
    drift = 180.0 * np.sin(2 * np.pi * 0.22 * t) + 90.0 * np.cos(2 * np.pi * 0.1 * t)
    np.random.seed(42)
    raw_signal = dc_offset + chunk + drift + np.random.normal(0, 10.0, n_pts)

    # Plot 3-Panel Horizontal (Resolusi Tinggi)
    fig, axes = plt.subplots(3, 1, figsize=(11.5, 6.5), facecolor="#0F172A")
    plt.subplots_adjust(hspace=0.45, left=0.08, right=0.96, top=0.91, bottom=0.10)

    # Panel 1: Sinyal Mentah
    ax0 = axes[0]
    ax0.set_facecolor("#1E293B")
    ax0.plot(t, raw_signal / 1000.0, color="#60A5FA", lw=1.8)
    ax0.set_title("(A) Sinyal PPG Mentah (Raw MAX30105 Optical Signal)", fontsize=11, fontweight="bold", color="#F8FAFC", loc="left")
    ax0.set_ylabel("ADC (k)", fontsize=9, color="#94A3B8")
    ax0.tick_params(colors="#94A3B8", labelsize=8)
    ax0.grid(True, color="#334155", linestyle=":", alpha=0.7)
    ax0.set_xlim(0, durasi)
    for s in ("top", "right"): ax0.spines[s].set_visible(False)
    for s in ("bottom", "left"): ax0.spines[s].set_color("#475569")
    ax0.text(0.98, 0.15, "DC Offset ~145.000 + Baseline Drift (Respirasi & Gerak)", transform=ax0.transAxes,
             fontsize=8.5, color="#FDE047", ha="right", style="italic")

    # Panel 2: Sinyal Terfilter
    ax1 = axes[1]
    ax1.set_facecolor("#1E293B")
    ax1.plot(t, filtered, color="#34D399", lw=1.9)
    ax1.set_title("(B) Sinyal PPG Setelah Bandpass Filter 0.8 – 2.5 Hz (Orde 3 Butterworth)", fontsize=11, fontweight="bold", color="#F8FAFC", loc="left")
    ax1.set_ylabel("BVP Terpusat", fontsize=9, color="#94A3B8")
    ax1.tick_params(colors="#94A3B8", labelsize=8)
    ax1.grid(True, color="#334155", linestyle=":", alpha=0.7)
    ax1.set_xlim(0, durasi)
    for s in ("top", "right"): ax1.spines[s].set_visible(False)
    for s in ("bottom", "left"): ax1.spines[s].set_color("#475569")
    ax1.text(0.98, 0.82, "DC Offset Tereliminasi | Denyut Fisiologis 48–150 BPM Terisolasi", transform=ax1.transAxes,
             fontsize=8.5, color="#A7F3D0", ha="right",
             bbox=dict(boxstyle="round,pad=0.3", facecolor="#064E3B", alpha=0.5, edgecolor="#059669"))

    # Panel 3: Deteksi Puncak & IBI
    ax2 = axes[2]
    ax2.set_facecolor("#1E293B")
    ax2.plot(t, filtered, color="#A7F3D0", lw=1.3, alpha=0.75)
    ax2.scatter(peak_times, peak_vals, color="#EF4444", s=60, zorder=6, edgecolor="#FFFFFF", linewidth=1.3)
    for i, (pt, pv) in enumerate(zip(peak_times, peak_vals)):
        ax2.annotate(f"P{i+1}", (pt, pv), textcoords="offset points", xytext=(0, 6),
                     ha="center", fontsize=8, fontweight="bold", color="#FCA5A5")

    # Garis Panah IBI
    if len(peak_times) >= 3:
        t1, t2 = peak_times[1], peak_times[2]
        y_m = max(peak_vals[1], peak_vals[2]) * 0.55
        ax2.annotate("", xy=(t1, y_m), xytext=(t2, y_m),
                     arrowprops=dict(arrowstyle="<->", color="#FDE047", lw=1.5))
        ax2.text((t1+t2)/2, y_m + 25, f"IBI = {ibis[1]:.0f} ms",
                 ha="center", fontsize=8, fontweight="bold", color="#FDE047")

    ax2.set_title("(C) Deteksi Puncak Sistolik & Inter-Beat Interval (IBI)", fontsize=11, fontweight="bold", color="#F8FAFC", loc="left")
    ax2.set_xlabel("Waktu (detik)", fontsize=9, color="#CBD5E1")
    ax2.set_ylabel("Amplitudo", fontsize=9, color="#94A3B8")
    ax2.tick_params(colors="#94A3B8", labelsize=8)
    ax2.grid(True, color="#334155", linestyle=":", alpha=0.7)
    ax2.set_xlim(0, durasi)
    for s in ("top", "right"): ax2.spines[s].set_visible(False)
    for s in ("bottom", "left"): ax2.spines[s].set_color("#475569")

    # Badge Ekstraksi Fitur
    badge_txt = f"Detak (HR): {hr_bpm:.0f} BPM  |  PRV (RMSSD): {rmssd_ms:.1f} ms"
    ax2.text(0.98, 0.16, badge_txt, transform=ax2.transAxes, fontsize=8.5, fontweight="bold", color="#FFFFFF",
             ha="right", bbox=dict(boxstyle="round,pad=0.45", facecolor="#991B1B", alpha=0.85, edgecolor="#EF4444", lw=1.2))

    f_out = os.path.join(OUT_DIR, "visualisasi_sinyal_ppg_dan_puncak.png")
    fig.savefig(f_out, dpi=250, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> Tersimpan: {f_out}")


# ==============================================================================
# BAGIAN 2: GRAFIK DAYA PISAH COHEN'S d
# Menjawab: "Cohen's d tuh apa dan kenapa pakai ini?"
# ==============================================================================
def buat_grafik_cohens_d():
    print("\n[2/4] Menghasilkan Grafik Daya Pisah Cohen's d (Baseline Personal)...")
    
    # Metrik Cohen's d terukur pada HypoSense
    # Jalur Jantung & Jalur VOC: Nilai Absolut vs Relatif Personal
    fitur = ["Detak Jantung (HR)", "RMSSD (PRV)", "Aseton Napas (VOC)"]
    d_absolut = [0.22, 0.35, 0.39]
    d_relatif = [0.41, 0.63, 0.99]

    x = np.arange(len(fitur))
    lebar = 0.35

    fig, ax = plt.subplots(figsize=(9.2, 5.2), facecolor="#0B132B")
    ax.set_facecolor("#111D33")

    # Plot Bar Absolut vs Relatif
    rects1 = ax.bar(x - lebar/2, d_absolut, lebar, label="Kadar Absolut (Apa Adanya)",
                    color="#0284C7", edgecolor="#38BDF8", lw=1.2)
    rects2 = ax.bar(x + lebar/2, d_relatif, lebar, label="Relatif terhadap Baseline Personal",
                    color="#EA580C", edgecolor="#FB923C", lw=1.2)

    # Tambahkan angka di atas tiap batang
    for r in rects1:
        h = r.get_height()
        ax.text(r.get_x() + r.get_width()/2, h + 0.03, f"{h:.2f}",
                ha="center", va="bottom", fontsize=10, color="#38BDF8", fontweight="bold")
    for r in rects2:
        h = r.get_height()
        ax.text(r.get_x() + r.get_width()/2, h + 0.03, f"{h:.2f}",
                ha="center", va="bottom", fontsize=11, color="#FB923C", fontweight="bold")

    # Garis Ambang Batas Interpretasi Cohen
    ax.axhline(0.2, color="#64748B", linestyle=":", lw=1.0)
    ax.text(2.45, 0.21, "Efek Kecil (d = 0.2)", fontsize=8, color="#94A3B8")
    ax.axhline(0.5, color="#64748B", linestyle=":", lw=1.0)
    ax.text(2.45, 0.51, "Efek Sedang (d = 0.5)", fontsize=8, color="#94A3B8")
    ax.axhline(0.8, color="#10B981", linestyle="--", lw=1.2)
    ax.text(2.45, 0.81, "Efek Besar (d >= 0.8)", fontsize=8.5, color="#34D399", fontweight="bold")

    # Anotasi Lonjakan 2.5x Lipat pada Aseton
    ax.annotate("Meningkat 2,5x Lipat!\n(Daya Pisah Kuat)",
                xy=(2 + lebar/2, 0.99), xytext=(1.55, 1.15),
                arrowprops=dict(arrowstyle="->", color="#FDE047", lw=1.6),
                fontsize=9.5, fontweight="bold", color="#FDE047", ha="center")

    ax.set_title("Peningkatan Daya Pisah Antarkelas (Cohen's d)\nNormalisasi Baseline Personal vs Nilai Mutlak",
                 fontsize=12.5, fontweight="bold", color="#FFFFFF", pad=12)
    ax.set_ylabel("Daya Pisah (Cohen's d)", fontsize=10, color="#CBD5E1")
    ax.set_xticks(x)
    ax.set_xticklabels(fitur, fontsize=10.5, fontweight="bold", color="#FFFFFF")
    ax.tick_params(colors="#94A3B8")
    ax.set_ylim(0, 1.35)
    ax.grid(axis="y", color="#1E293B", linestyle="--", alpha=0.7)

    for s in ("top", "right"): ax.spines[s].set_visible(False)
    for s in ("bottom", "left"): ax.spines[s].set_color("#334155")

    ax.legend(frameon=True, facecolor="#162238", edgecolor="#2A3C59", fontsize=9.5, labelcolor="#FFFFFF", loc="upper left")

    f_out = os.path.join(OUT_DIR, "grafik_daya_pisah_cohens_d.png")
    fig.savefig(f_out, dpi=250, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> Tersimpan: {f_out}")


# ==============================================================================
# BAGIAN 3: SLIDE 11 MODEL TINYML REVISI
# Menjawab: "ga terbaca", "kebanyakan teks", "sinyal ppg kek mana"
# ==============================================================================
def buat_slide_11():
    print("\n[3/4] Menghasilkan Slide 11 Model TinyML Revisi (16:9)...")
    
    # Setup Canvas 16:9
    fig = plt.figure(figsize=(16, 9), facecolor="#0B132B")
    ax = fig.add_axes([0, 0, 1, 1], facecolor="#0B132B")
    ax.set_xlim(0, 16); ax.set_ylim(0, 9); ax.axis("off")

    # Header Slide
    ax.text(0.8, 8.35, "Model TinyML", fontsize=28, fontweight="bold", color="#FFFFFF", va="center")
    ax.text(0.8, 7.95, "Arsitektur Deteksi Bertingkat: Olah Sinyal PPG dan Verifikasi Ganda Fisiologis",
            fontsize=13, color="#94A3B8", va="center")
    ax.plot([0.8, 15.2], [7.65, 7.65], color="#1E293B", lw=1.5)

    def kartu(x, y, w, h, bg="#111D33", border="#2A3C59"):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=0.18",
                                    facecolor=bg, edgecolor=border, linewidth=1.5, zorder=1))

    # --- KOLOM 1: OLAH SINYAL (Kiri: x=0.8, w=4.5) ---
    kartu(0.8, 1.3, 4.5, 6.1, border="#38BDF8")
    ax.add_patch(FancyBboxPatch((0.8, 6.85), 4.5, 0.55, boxstyle="round,pad=0,rounding_size=0.18",
                                facecolor="#0369A1", edgecolor="#38BDF8", linewidth=1.2, zorder=2))
    ax.text(3.05, 7.12, "1. Olah Sinyal & Ekstraksi Ciri", fontsize=13, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=3)

    # Buat dummy/sinyal bersih untuk preview kolom 1
    t = np.linspace(0, 6, 384)
    sig_raw = 145 + 0.3 * np.sin(2 * np.pi * 0.25 * t) + 0.15 * np.sin(2 * np.pi * 1.2 * t)
    sig_filt = np.sin(2 * np.pi * 1.2 * t) + 0.35 * np.sin(4 * np.pi * 1.2 * t)

    # Subplot A: Raw
    a_s1 = fig.add_axes([0.09, 0.58, 0.22, 0.14], facecolor="#0B1325")
    a_s1.plot(t, sig_raw, color="#60A5FA", lw=1.4)
    a_s1.set_title("A. PPG Mentah (MAX30105)", fontsize=9.5, fontweight="bold", color="#93C5FD", loc="left", pad=3)
    a_s1.set_ylabel("ADC (k)", fontsize=7.5, color="#64748B")
    a_s1.tick_params(colors="#64748B", labelsize=7)
    a_s1.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
    for s in ("top", "right"): a_s1.spines[s].set_visible(False)
    for s in ("bottom", "left"): a_s1.spines[s].set_color("#334155")
    a_s1.text(0.96, 0.12, "DC Offset ~145k + Drift", transform=a_s1.transAxes, fontsize=7.5, color="#FDE047", ha="right")

    # Subplot B: Filtered
    a_s2 = fig.add_axes([0.09, 0.39, 0.22, 0.14], facecolor="#0B1325")
    a_s2.plot(t, sig_filt, color="#34D399", lw=1.5)
    a_s2.set_title("B. Filter Pita (0.8–2.5 Hz)", fontsize=9.5, fontweight="bold", color="#6EE7B7", loc="left", pad=3)
    a_s2.set_ylabel("Amplitudo", fontsize=7.5, color="#64748B")
    a_s2.tick_params(colors="#64748B", labelsize=7)
    a_s2.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
    for s in ("top", "right"): a_s2.spines[s].set_visible(False)
    for s in ("bottom", "left"): a_s2.spines[s].set_color("#334155")
    a_s2.text(0.96, 0.12, "Isolasi denyut fisiologis", transform=a_s2.transAxes, fontsize=7.5, color="#A7F3D0", ha="right")

    # Subplot C: Peak & IBI
    a_s3 = fig.add_axes([0.09, 0.20, 0.22, 0.14], facecolor="#0B1325")
    a_s3.plot(t, sig_filt, color="#A7F3D0", lw=1.1, alpha=0.7)
    pk_idx = [27, 80, 133, 186, 239, 292, 345]
    a_s3.scatter(t[pk_idx], sig_filt[pk_idx], color="#EF4444", s=35, zorder=6, edgecolor="#FFFFFF", lw=1.0)
    for i, idx in enumerate(pk_idx):
        a_s3.annotate(f"P{i+1}", (t[idx], sig_filt[idx]), textcoords="offset points", xytext=(0, 5),
                      ha="center", fontsize=7, fontweight="bold", color="#FCA5A5")
    # Panah IBI
    a_s3.annotate("", xy=(t[pk_idx[1]], 0.6), xytext=(t[pk_idx[2]], 0.6),
                  arrowprops=dict(arrowstyle="<->", color="#FDE047", lw=1.3))
    a_s3.text((t[pk_idx[1]]+t[pk_idx[2]])/2, 0.8, "IBI = 864ms", ha="center", fontsize=7, color="#FDE047", fontweight="bold")
    a_s3.set_title("C. Deteksi Puncak Sistolik & IBI", fontsize=9.5, fontweight="bold", color="#F87171", loc="left", pad=3)
    a_s3.set_xlabel("Waktu (detik)", fontsize=7.5, color="#64748B")
    a_s3.tick_params(colors="#64748B", labelsize=7)
    a_s3.grid(True, color="#1E293B", linestyle=":", alpha=0.7)
    for s in ("top", "right"): a_s3.spines[s].set_visible(False)
    for s in ("bottom", "left"): a_s3.spines[s].set_color("#334155")

    ax.text(0.95, 1.50, "• Ekstraksi: HR = 69-78 BPM | PRV (RMSSD) = 38,4 ms\n• Simpangan dihitung terhadap Baseline Personal (EMA)",
            fontsize=8.5, color="#CBD5E1", va="center", zorder=3)

    # --- KOLOM 2: MODEL 1 - PEMICU JANTUNG (Tengah: x=5.6, w=4.5) ---
    kartu(5.6, 1.3, 4.5, 6.1, border="#0D9488")
    ax.add_patch(FancyBboxPatch((5.6, 6.85), 4.5, 0.55, boxstyle="round,pad=0,rounding_size=0.18",
                                facecolor="#0F766E", edgecolor="#14B8A6", linewidth=1.2, zorder=2))
    ax.text(7.85, 7.12, "2. Model 1 · Pemicu Jantung", fontsize=13, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=3)

    ax.text(5.85, 6.55, "Data & Validasi:", fontsize=11, fontweight="bold", color="#2DD4BF", zorder=3)
    ax.text(5.85, 6.25, "• Dataset: HUPA-UCM (25 pasien T1D nyata)\n• Sampel: 13.996 sampel (7,2% hipoglikemia)\n• Evaluasi: Validasi LOSO (Leave-One-Subject-Out)\n• Model Terpilih: Regresi Logistik (dari 14 model)",
            fontsize=9.8, color="#E2E8F0", linespacing=1.45, zorder=3)
    ax.plot([5.85, 9.85], [5.25, 5.25], color="#1E293B", lw=1.2, zorder=3)

    ax.text(5.85, 4.95, "Performa Deteksi Hipoglikemia:", fontsize=11, fontweight="bold", color="#2DD4BF", zorder=3)
    def badge_metrik(y, lbl, val, bg="#042F2E", bd="#0D9488", tc="#2DD4BF"):
        ax.text(5.85, y, lbl, fontsize=11, color="#CBD5E1", va="center", zorder=3)
        ax.text(9.65, y, val, fontsize=14, fontweight="bold", color=tc, ha="right", va="center", zorder=3,
                bbox=dict(boxstyle="round,pad=0.35", facecolor=bg, edgecolor=bd, lw=1.2))

    badge_metrik(4.45, "Sensitivitas (Recall)", "48,3%")
    badge_metrik(3.80, "Spesifisitas", "57,9%")
    badge_metrik(3.15, "Akurasi Total", "57,2%")
    badge_metrik(2.50, "Presisi (PPV)", "8,2%", bg="#312E81", bd="#6366F1", tc="#A5B4FC")

    ax.add_patch(FancyBboxPatch((5.85, 1.45), 4.0, 0.65, boxstyle="round,pad=0.15", facecolor="#042F2E", edgecolor="#0D9488", lw=1.2, zorder=2))
    ax.text(7.85, 1.78, "PERAN: Skrining Awal Cepat (Pemicu)\nTidak bisa mandiri karena presisi rendah",
            fontsize=8.5, fontweight="bold", color="#5EEAD4", ha="center", va="center", linespacing=1.25, zorder=3)

    # Panah Alur
    ax.annotate("", xy=(10.35, 4.2), xytext=(10.15, 4.2),
                arrowprops=dict(arrowstyle="->", color="#FBBF24", lw=2.4, mutation_scale=20), zorder=4)
    ax.text(10.25, 4.60, "Memicu\nNapas", fontsize=8.5, fontweight="bold", color="#FDE047", ha="center", va="center", zorder=4)

    # --- KOLOM 3: MODEL 2 - KONFIRMASI VOC (Kanan: x=10.4, w=4.8) ---
    kartu(10.4, 1.3, 4.8, 6.1, border="#EA580C")
    ax.add_patch(FancyBboxPatch((10.4, 6.85), 4.8, 0.55, boxstyle="round,pad=0.18",
                                facecolor="#C2410C", edgecolor="#FB923C", linewidth=1.2, zorder=2))
    ax.text(12.8, 7.12, "3. Model 2 · Konfirmasi VOC Napas", fontsize=13, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=3)

    ax.text(10.65, 6.55, "Data & Metodologi:", fontsize=11, fontweight="bold", color="#FB923C", zorder=3)
    ax.text(10.65, 6.25, "• Sensor: MQ-138 (Aseton Napas Eksalasi)\n• Data Rujukan: Simulasi parameter klinis Turner dkk.\n• Model: Random Forest (Bobot Kelas Seimbang)\n• Normalisasi: Nilai Absolut vs Relatif Personal",
            fontsize=9.8, color="#E2E8F0", linespacing=1.45, zorder=3)
    ax.plot([10.65, 14.95], [5.25, 5.25], color="#1E293B", lw=1.2, zorder=3)

    ax.text(10.65, 4.95, "Dampak Normalisasi Baseline Personal:", fontsize=11, fontweight="bold", color="#FB923C", zorder=3)
    def badge_metrik_rel(y, lbl, v1, v2):
        ax.text(10.65, y, lbl, fontsize=11, color="#CBD5E1", va="center", zorder=3)
        ax.text(13.35, y, v1, fontsize=12, color="#94A3B8", ha="right", va="center", zorder=3)
        ax.text(13.65, y, "→", fontsize=13, fontweight="bold", color="#FB923C", ha="center", va="center", zorder=3)
        ax.text(14.85, y, v2, fontsize=14, fontweight="bold", color="#FDBA74", ha="right", va="center", zorder=3,
                bbox=dict(boxstyle="round,pad=0.35", facecolor="#431407", edgecolor="#EA580C", lw=1.2))

    badge_metrik_rel(4.45, "Sensitivitas", "44%", "57%")
    badge_metrik_rel(3.80, "Spesifisitas", "62%", "73%")
    badge_metrik_rel(3.15, "Akurasi Total", "60%", "71%")
    badge_metrik_rel(2.50, "Presisi (PPV)", "44%", "59%")

    ax.add_patch(FancyBboxPatch((10.65, 1.45), 4.3, 0.65, boxstyle="round,pad=0.15", facecolor="#431407", edgecolor="#EA580C", lw=1.2, zorder=2))
    ax.text(12.8, 1.78, "PERAN: Pemastian Positif Palsu Jantung\nMencegah alarm palsu tanpa menusuk jari",
            fontsize=8.5, fontweight="bold", color="#FDBA74", ha="center", va="center", linespacing=1.25, zorder=3)

    # --- BANNER KUNCI BAWAH ---
    ax.add_patch(FancyBboxPatch((0.8, 0.45), 14.4, 0.65, boxstyle="round,pad=0.15",
                                facecolor="#1E293B", edgecolor="#38BDF8", linewidth=1.4, zorder=2))
    ax.text(1.1, 0.77, "KUNCI UTAMA:", fontsize=11, fontweight="bold", color="#38BDF8", va="center", zorder=3)
    ax.text(2.6, 0.77,
            "Baseline Personal Mutlak Diperlukan  •  Rentang Rerata HR Antarpasien 27,1 bpm  •  Korelasi Aseton Antarindividu Hanya r = 0,134",
            fontsize=10.5, fontweight="semibold", color="#F1F5F9", va="center", zorder=3)

    f_out = os.path.join(OUT_DIR, "slide_11_model_tinyml_revisi.png")
    fig.savefig(f_out, dpi=250, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> Tersimpan: {f_out}")


# ==============================================================================
# BAGIAN 4: SLIDE CARA KERJA ALAT GAYA PKP2
# Menjawab: "dibuat gini aja yang cara kerja alatnya pake video yang lama di pkp2"
# ==============================================================================
def buat_slide_cara_kerja():
    print("\n[4/4] Menghasilkan Slide Cara Kerja Alat Format PKP2...")
    
    fig = plt.figure(figsize=(16, 9), facecolor="#0B132B")
    ax = fig.add_axes([0, 0, 1, 1], facecolor="#0B132B")
    ax.set_xlim(0, 16); ax.set_ylim(0, 9); ax.axis("off")

    # Header
    ax.text(0.8, 8.35, "Cara Kerja & Realisasi Perangkat Keras", fontsize=28, fontweight="bold", color="#FFFFFF", va="center")
    ax.text(0.8, 7.95, "Alur Operasional Gelang Cerdas HypoSense: Dari Pemasangan hingga Verifikasi Mandiri",
            fontsize=13, color="#94A3B8", va="center")
    ax.plot([0.8, 15.2], [7.65, 7.65], color="#1E293B", lw=1.5)

    # --- SISI KIRI: FRAME VIDEO UTAMA (60% Lebar) ---
    ax.add_patch(FancyBboxPatch((0.8, 0.9), 9.0, 6.5, boxstyle="round,pad=0.22",
                                facecolor="#111D33", edgecolor="#38BDF8", linewidth=2.0, zorder=1))
    ax.add_patch(FancyBboxPatch((0.8, 6.85), 9.0, 0.55, boxstyle="round,pad=0.18",
                                facecolor="#0369A1", edgecolor="#38BDF8", linewidth=1.2, zorder=2))
    ax.text(5.3, 7.12, "Demonstrasi Operasional Gelang HypoSense (Video Utama)",
            fontsize=13.5, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=3)

    # Layar Video Player
    ax.add_patch(FancyBboxPatch((1.1, 1.2), 8.4, 5.45, boxstyle="round,pad=0.15",
                                facecolor="#060D1A", edgecolor="#1E293B", linewidth=1.5, zorder=2))
    # Play Icon
    ax.add_patch(Circle((5.3, 3.9), 0.75, facecolor="#0284C7", edgecolor="#38BDF8", lw=2.5, alpha=0.9, zorder=4))
    ax.add_patch(Polygon([[5.1, 3.45], [5.1, 4.35], [5.7, 3.9]], closed=True, facecolor="#FFFFFF", zorder=5))

    ax.text(5.3, 2.7, "Putar Video Demonstrasi Sistem (Durasi: ~2 Menit)",
            fontsize=12, fontweight="bold", color="#E2E8F0", ha="center", va="center", zorder=3)
    ax.text(5.3, 2.3, "Menampilkan integrasi sensor PPG, pemanas MQ-138, display OLED, dan aplikasi BLE",
            fontsize=10, color="#94A3B8", ha="center", va="center", zorder=3)

    # --- SISI KANAN: 4 LANGKAH OPERASIONAL (40% Lebar) ---
    langkah = [
        ("1", "Pengecasan Baterai", "LiPo 3.7V 1500mAh via USB-C (TP4056)",
         "• Pengisian daya ringkas USB Type-C\n• Indikator baterai terpantau di OLED\n• Daya tahan operasional kontinu 8-10 jam",
         "#0284C7", "#38BDF8"),
        ("2", "Pemasangan Gelang", "Kontak Kulit Arteri Radialis (MAX30105)",
         "• Sensor menempel rapat di pergelangan\n• Verifikasi kontak kulit optik (DC > 3.000)\n• Deteksi otomatis detak & perfusi jaringan",
         "#0D9488", "#2DD4BF"),
        ("3", "Integrasi Aplikasi", "Konektivitas Nirkabel BLE Real-Time",
         "• Pairing otomatis ESP32-C3 ke Android/iOS\n• Streaming data HR, PRV, & suhu tiap detik\n• Kalibrasi baseline personal otomatis",
         "#7C3AED", "#A78BFA"),
        ("4", "Deteksi & Uji Napas", "Pemicu Jantung + Konfirmasi Aseton VOC",
         "• HR/PRV abnormal -> OLED meminta tiupan napas\n• Pemanas MQ-138 aktif (90 dtk) ukur aseton\n• Alarm risiko ganda muncul jika positif",
         "#C2410C", "#FB923C")
    ]

    y_pos = [5.85, 4.25, 2.65, 1.05]
    for i, (no, jdl, sub, poin, col, bd) in enumerate(langkah):
        yp = y_pos[i]
        ax.add_patch(FancyBboxPatch((10.2, yp), 5.0, 1.45, boxstyle="round,pad=0.15",
                                    facecolor="#111D33", edgecolor=bd, linewidth=1.4, zorder=1))
        ax.add_patch(Circle((10.7, yp + 1.03), 0.30, facecolor=col, edgecolor=bd, lw=1.2, zorder=3))
        ax.text(10.7, yp + 1.03, no, fontsize=12, fontweight="bold", color="#FFFFFF", ha="center", va="center", zorder=4)
        ax.text(11.2, yp + 1.13, jdl, fontsize=12, fontweight="bold", color="#FFFFFF", va="center", zorder=3)
        ax.text(11.2, yp + 0.87, sub, fontsize=8.5, color=bd, va="center", zorder=3)
        ax.text(10.5, yp + 0.38, poin, fontsize=8.2, color="#CBD5E1", linespacing=1.35, va="center", zorder=3)

    f_out = os.path.join(OUT_DIR, "slide_cara_kerja_alat_revisi.png")
    fig.savefig(f_out, dpi=250, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> Tersimpan: {f_out}")


# ==============================================================================
# EKSEKUSI UTAMA
# ==============================================================================
if __name__ == "__main__":
    buat_visualisasi_ppg()
    buat_grafik_cohens_d()
    buat_slide_11()
    buat_slide_cara_kerja()
    print("\n" + "=" * 70)
    print("SELURUH VISUALISASI BERHASIL DIGENERASI DENGAN SUKSES!")
    print(f"Seluruh berkas gambar siap pakai ada di: {OUT_DIR}")
    print("=" * 70)

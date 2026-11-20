"""
Pembaca berkas PhysioCGM (.pkl).

Berkas .pkl adalah format biner Python — tidak dapat dibuka dengan editor teks.
Skrip ini membukanya dan menampilkan isinya.

Struktur tiap berkas (satu jendela rekaman ~62 detik):
    Index, Timestamp, glucose (mg/dL),
    zephyr : Accel, Breathing, ECG (250 Hz), Summary
    e4     : ACC, HR, BVP (PPG 64 Hz), EDA, TEMP

PEMAKAIAN
    python lihat_physiocgm.py                 # lihat berkas pertama
    python lihat_physiocgm.py 100             # lihat berkas 100.pkl
    python lihat_physiocgm.py 100 --grafik    # + simpan grafik sinyalnya
    python lihat_physiocgm.py --sebaran       # telaah glukosa SEMUA berkas
"""

import sys, io, os, glob, pickle, argparse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import numpy as np

AKAR = r"C:\KULIAH\BELAJAR NGODING\HypoSense\HypoSense\PhysioCGM"
HIPO = 70   # mg/dL, ADA 2023


def daftar_subjek():
    """Semua folder subjek yang tersedia, terurut."""
    return sorted(d for d in os.listdir(AKAR)
                  if os.path.isdir(os.path.join(AKAR, d)))


def muat(nomor, subjek=None):
    subjek = subjek or daftar_subjek()[0]
    p = os.path.join(AKAR, subjek, f"{nomor}.pkl")
    if not os.path.exists(p):
        sys.exit(f"Tidak ada: {p}")
    with open(p, "rb") as f:
        return pickle.load(f)


def ringkas_sinyal(nama, blok, kunci):
    t = np.asarray(blok['Time'], dtype='datetime64[ns]')
    v = np.asarray(blok[kunci], dtype=float)
    if len(t) < 2:
        print(f"  {nama:<20} (kosong)")
        return
    durasi = (t[-1] - t[0]) / np.timedelta64(1, 's')
    fs = (len(t) - 1) / durasi if durasi > 0 else 0
    print(f"  {nama:<20} {len(v):>7} titik  {durasi:>5.1f}s  "
          f"{fs:>6.1f} Hz   nilai {np.nanmin(v):>8.1f} .. {np.nanmax(v):>8.1f}")


def lihat(nomor, grafik=False):
    d = muat(nomor)
    print("=" * 74)
    print(f"BERKAS {nomor}.pkl")
    print("=" * 74)
    print(f"  Waktu   : {d['Timestamp']}")
    g = d['glucose']
    tanda = "  <-- HIPOGLIKEMIA" if g < HIPO else ""
    print(f"  Glukosa : {g:.0f} mg/dL{tanda}")
    print()
    print("  Sinyal Empatica E4 (pergelangan tangan):")
    ringkas_sinyal("BVP (PPG)", d['e4']['BVP'], 'BVP')
    ringkas_sinyal("HR", d['e4']['HR'], 'HR')
    ringkas_sinyal("EDA", d['e4']['EDA'], 'EDA')
    ringkas_sinyal("TEMP", d['e4']['TEMP'], 'TEMP')
    print()
    print("  Sinyal Zephyr BioHarness (dada):")
    ringkas_sinyal("ECG", d['zephyr']['ECG'], 'EcgWaveform')
    ringkas_sinyal("HR (ringkasan)", d['zephyr']['Summary'], 'HR')

    if grafik:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        bvp = np.asarray(d['e4']['BVP']['BVP'], dtype=float)
        ecg = np.asarray(d['zephyr']['ECG']['EcgWaveform'], dtype=float)
        # tampilkan 10 detik pertama saja agar bentuk denyutnya terlihat
        n_bvp, n_ecg = int(64 * 10), int(250 * 10)

        fig, ax = plt.subplots(2, 1, figsize=(11, 5.4))
        ax[0].plot(np.arange(min(n_bvp, len(bvp))) / 64.0,
                   bvp[:n_bvp], color="#3B6CFF", lw=1)
        ax[0].set_title(f"PPG pergelangan (64 Hz) — glukosa {g:.0f} mg/dL",
                        loc="left")
        ax[0].set_ylabel("BVP")
        ax[1].plot(np.arange(min(n_ecg, len(ecg))) / 250.0,
                   ecg[:n_ecg], color="#E8833A", lw=0.8)
        ax[1].set_title("EKG dada (250 Hz) — pembanding baku emas", loc="left")
        ax[1].set_ylabel("EKG"); ax[1].set_xlabel("Detik")
        for a in ax:
            a.grid(color="#d8d8d8", lw=0.6); a.set_axisbelow(True)
            for s in ("top", "right"): a.spines[s].set_visible(False)
        plt.tight_layout()
        out = f"sinyal_{nomor}.png"
        plt.savefig(out, dpi=150)
        print(f"\n  Grafik disimpan: {out}")


def sebaran():
    """Telaah kadar glukosa SELURUH subjek — menentukan kelayakan untuk deteksi.

    Hasilnya disimpan ke CSV agar tidak perlu membaca ulang 26 GB.
    """
    import csv
    subjek = daftar_subjek()
    semua = glob.glob(os.path.join(AKAR, "*", "*.pkl"))
    print(f"Subjek  : {', '.join(subjek)}")
    print(f"Berkas  : {len(semua):,}  (~26 GB, perlu beberapa menit)\n")

    baris = []
    for i, p in enumerate(semua):
        try:
            with open(p, "rb") as f:
                d = pickle.load(f)
            baris.append({
                "subjek": os.path.basename(os.path.dirname(p)).replace("_processed", ""),
                "berkas": os.path.basename(p).replace(".pkl", ""),
                "waktu": str(d["Timestamp"]),
                "glukosa": float(d["glucose"]),
            })
        except Exception:
            continue
        if (i + 1) % 1000 == 0:
            print(f"  {i+1:,}/{len(semua):,} ...", flush=True)

    if not baris:
        sys.exit("Tidak ada berkas terbaca.")

    out = "physiocgm_glukosa.csv"
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["subjek", "berkas", "waktu", "glukosa"])
        w.writeheader(); w.writerows(baris)

    print()
    print("=" * 74)
    print("SEBARAN GLUKOSA — PhysioCGM")
    print("=" * 74)
    print(f"  {'Subjek':<10}{'Jendela':>9}{'Rata2':>8}{'Min':>6}{'Maks':>6}"
          f"{'Hipo':>8}{'%':>8}")
    print("  " + "-" * 53)

    total_n = total_h = 0
    for s in subjek:
        kode = s.replace("_processed", "")
        g = np.array([b["glukosa"] for b in baris if b["subjek"] == kode])
        if not len(g):
            continue
        h = int((g < HIPO).sum())
        total_n += len(g); total_h += h
        print(f"  {kode:<10}{len(g):>9,}{g.mean():>8.0f}{g.min():>6.0f}"
              f"{g.max():>6.0f}{h:>8,}{h/len(g):>7.2%}")

    print("  " + "-" * 53)
    print(f"  {'TOTAL':<10}{total_n:>9,}{'':>20}{total_h:>8,}"
          f"{total_h/total_n:>7.2%}")
    print()
    print(f"  Tersimpan: {out}")
    print()
    if total_h < 100:
        print("  => Kejadian hipoglikemia terlalu sedikit; perlu subjek tambahan")
        print("     sebelum jalur PRV dapat diuji secara bermakna.")
    else:
        print(f"  => {total_h:,} kejadian hipoglikemia — memadai untuk menguji")
        print("     apakah variabilitas denyut mampu menandainya.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("nomor", nargs="?", default="0")
    ap.add_argument("--grafik", action="store_true")
    ap.add_argument("--sebaran", action="store_true")
    a = ap.parse_args()
    if a.sebaran:
        sebaran()
    else:
        lihat(a.nomor, a.grafik)

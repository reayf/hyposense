# Validasi metode deteksi hipoglikemia HypoSense pada dataset HUPA-UCM.
# Menguji: baseline HR personal (EMA, terpisah siang/malam) + anomali skor-z
# dua-arah + persistensi + ACTIVITY-GATING (buang anomali HR akibat gerak).
#
# Catatan kejujuran:
#  - HUPA-UCM = HR per 5 menit (Fitbit terolah) -> validasi metode berbasis HR
#    (inti pemicu alarm), BUKAN PRV (perlu PPG mentah).
#  - ONLINE/kausal (hanya data lampau) -> jujur seperti di perangkat.
#  - Activity-gating: hipo paling relevan dideteksi saat ISTIRAHAT/tidur.
#    HR naik saat aktivitas itu wajar (bukan hipo) -> ditekan.

import glob, os
import numpy as np
import pandas as pd

DATA_DIR = r"C:\KULIAH\BELAJAR NGODING\HypoSense\HypoSense\HUPA-UCM Diabetes Dataset\HUPA-UCM Diabetes Dataset\Preprocessed"

# ---- Parameter (USULAN — perlu kalibrasi) ----
HYPO_MG    = 70
Z_THRESH   = 2.5
PERSIST    = 2       # 2 sampel x 5mnt = 10 menit
ALPHA_BASE = 0.02
ALPHA_DEV  = 0.05
MIN_DEV    = 2.0
WARMUP     = 288     # 1 hari
NIGHT_START, NIGHT_END = 23, 7
STEP_THRESH = 20     # istirahat = langkah < 20 per 5 menit (aktivitas rendah)


def is_night(h):
    return (h >= NIGHT_START) or (h < NIGHT_END)


def process_patient(path, z_thresh=Z_THRESH, persist=PERSIST):
    df = pd.read_csv(path, sep=';')
    df['time'] = pd.to_datetime(df['time'])
    df = df.dropna(subset=['heart_rate', 'glucose']).reset_index(drop=True)
    if len(df) < WARMUP + 50:
        return None
    hr = df['heart_rate'].to_numpy(float)
    glu = df['glucose'].to_numpy(float)
    steps = df['steps'].fillna(0).to_numpy(float)
    night = df['time'].dt.hour.map(is_night).to_numpy(bool)
    resting = steps < STEP_THRESH
    label = glu < HYPO_MG

    base = {True: None, False: None}
    dev = {True: MIN_DEV * 2, False: MIN_DEV * 2}
    anom = np.zeros(len(df), bool)
    for i in range(len(df)):
        n = bool(night[i])
        if base[n] is None:
            base[n] = hr[i]
            continue
        d = hr[i] - base[n]
        z = d / max(dev[n], MIN_DEV)
        a = abs(z) > z_thresh
        anom[i] = a
        if not a:
            base[n] += ALPHA_BASE * d
            dev[n] += ALPHA_DEV * (abs(d) - dev[n])

    pred = np.zeros(len(df), bool)
    run = 0
    for i in range(len(df)):
        run = run + 1 if anom[i] else 0
        pred[i] = run >= persist

    m = np.arange(len(df)) >= WARMUP
    return dict(pred=pred[m], label=label[m], night=night[m], rest=resting[m])


def metrics(pred, label):
    tp = int((pred & label).sum()); fp = int((pred & ~label).sum())
    fn = int((~pred & label).sum()); tn = int((~pred & ~label).sum())
    se = tp / (tp + fn) if (tp + fn) else float('nan')
    sp = tn / (tn + fp) if (tn + fp) else float('nan')
    pr = tp / (tp + fp) if (tp + fp) else float('nan')
    return se, sp, pr


def gather(z_thresh=Z_THRESH, persist=PERSIST):
    P, L, N, R = [], [], [], []
    used = 0
    for f in sorted(glob.glob(os.path.join(DATA_DIR, "*.csv"))):
        r = process_patient(f, z_thresh, persist)
        if r is None:
            continue
        used += 1
        P.append(r['pred']); L.append(r['label']); N.append(r['night']); R.append(r['rest'])
    return (np.concatenate(P), np.concatenate(L),
            np.concatenate(N), np.concatenate(R), used)


def line(name, pred, label):
    se, sp, pr = metrics(pred, label)
    print(f"  {name:<28} sens={100*se:5.1f}%  spes={100*sp:5.1f}%  "
          f"presisi={100*pr:4.1f}%  (n={len(label)}, hipo={int(label.sum())})")


if __name__ == "__main__":
    P, L, N, R, used = gather()
    print(f"=== HUPA-UCM + activity-gating | Z={Z_THRESH} persistensi={PERSIST*5}mnt "
          f"| istirahat=langkah<{STEP_THRESH} ===")
    print(f"Pasien: {used} | sampel: {len(L)} | hipo: {int(L.sum())} ({100*L.mean():.1f}%)\n")

    print("PERBANDINGAN:")
    line("Tanpa gating (semua)",        P,            L)
    line("Gated (alarm saat istirahat)", P & R,        L)          # tekan saat aktif
    line("Subset ISTIRAHAT saja",        P[R],         L[R])
    line("Subset MALAM + ISTIRAHAT",     P[N & R],     L[N & R])   # target nokturnal

    print("\n=== SWEEP Z (subset MALAM + ISTIRAHAT) ===")
    for z in [2.0, 2.5, 3.0, 3.5]:
        P, L, N, R, _ = gather(z_thresh=z)
        mask = N & R
        se, sp, pr = metrics(P[mask], L[mask])
        print(f"  Z={z}: sens={100*se:5.1f}%  spes={100*sp:5.1f}%  presisi={100*pr:4.1f}%")

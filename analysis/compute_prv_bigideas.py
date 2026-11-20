# Ekstraksi PRV (RMSSD) dari IBI.csv BIG IDEAs — membuktikan pipeline PRV
# menghasilkan nilai yang masuk akal pada data PPG pergelangan nyata.
# (Ini validasi EKSTRAKSI PRV, bukan deteksi hipo — dataset ini nyaris tanpa hipo.)

import glob, os
import numpy as np
import pandas as pd

D = r"C:\KULIAH\BELAJAR NGODING\HypoSense\HypoSense\analysis\bigideas"
WINDOW_S = 120                 # jendela 2 menit (sesuai usulan 2-3 mnt)
MIN_BEATS = 20                 # minimal denyut/jendela agar RMSSD sah
IBI_MIN, IBI_MAX = 300, 2000   # ms (30-200 bpm), buang IBI tak fisiologis


def rmssd(ibi_ms):
    d = np.diff(ibi_ms)
    return float(np.sqrt(np.mean(d * d))) if len(d) else np.nan


files = sorted(glob.glob(os.path.join(D, "IBI_*.csv")))
print(f"{'partisipan':<11}{'n_beat':>9}{'n_jendela':>10}{'RMSSD_med':>11}{'HR_med':>8}")
print("-" * 50)
meds = []
for f in files:
    try:
        df = pd.read_csv(f)
        df.columns = [c.strip() for c in df.columns]
        ibi = pd.to_numeric(df['ibi'], errors='coerce') * 1000.0
        t = pd.to_datetime(df['datetime'], errors='coerce')
        ok = ibi.notna() & t.notna() & (ibi >= IBI_MIN) & (ibi <= IBI_MAX)
        ibi, t = ibi[ok].to_numpy(), t[ok].reset_index(drop=True)
        if len(ibi) < MIN_BEATS:
            continue
        secs = (t - t.iloc[0]).dt.total_seconds().to_numpy()
        winid = (secs // WINDOW_S).astype(int)
        rs, hrs = [], []
        for w in np.unique(winid):
            seg = ibi[winid == w]
            if len(seg) < MIN_BEATS:
                continue
            rs.append(rmssd(seg))
            hrs.append(60000.0 / np.mean(seg))
        if not rs:
            continue
        pid = os.path.basename(f).replace('IBI_', '').replace('.csv', '')
        print(f"{pid:<11}{len(ibi):>9}{len(rs):>10}{np.median(rs):>9.1f}ms{np.median(hrs):>7.0f}")
        meds.append(np.median(rs))
    except Exception as e:
        print(f"  ({os.path.basename(f)} dilewati: {e})")

if meds:
    print("-" * 50)
    print(f"RMSSD median antar-partisipan: {np.median(meds):.1f} ms "
          f"(rentang {np.min(meds):.1f}-{np.max(meds):.1f} ms)")
    print("Rujukan: RMSSD istirahat dewasa sehat ~20-60 ms → nilai wajar = pipeline OK")

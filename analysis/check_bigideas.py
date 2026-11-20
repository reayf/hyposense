# Cek distribusi hipoglikemia (<70 mg/dL) di BIG IDEAs Lab.
# Go/no-go untuk validasi PRV: kalau hipo nyaris nol, dataset ini tak bisa
# menguji DETEKSI hipo (tak ada kelas positif) — hanya ekstraksi PRV.
# Menangani nilai Dexcom "Low" (<40 = hipo berat) & "High" yg berupa string.

import glob, os
import pandas as pd

D = r"C:\KULIAH\BELAJAR NGODING\HypoSense\HypoSense\analysis\bigideas"
COL = 'Glucose Value (mg/dL)'

files = sorted(glob.glob(os.path.join(D, "Dexcom_*.csv")))
tot_n = tot_h = 0
print(f"{'partisipan':<11}{'n_glukosa':>10}{'hipo<70':>9}{'%hipo':>8}{'min':>7}")
print("-" * 45)
for f in files:
    df = pd.read_csv(f, low_memory=False)
    raw = df[COL].astype(str).str.strip()
    num = pd.to_numeric(raw, errors='coerce')
    low = raw.str.lower().eq('low')                 # Dexcom "Low" = <40
    high = raw.str.lower().eq('high')
    valid = num.notna() | low | high                # bacaan glukosa sah
    hypo = (num < 70) | low                          # hipoglikemia
    n = int(valid.sum())
    h = int((hypo & valid).sum())
    tot_n += n; tot_h += h
    pid = os.path.basename(f).replace('Dexcom_', '').replace('.csv', '')
    mn = num.min()
    print(f"{pid:<11}{n:>10}{h:>9}{(100*h/n if n else 0):>7.1f}%{mn:>7.0f}")

print("-" * 45)
print(f"TOTAL: {tot_n} bacaan | hipo<70: {tot_h} ({100*tot_h/tot_n:.2f}%)")
print(f"Partisipan dengan >=10 sampel hipo: dihitung di atas (lihat kolom hipo<70)")

-- ============================================================
-- clinical_trial_setup.sql
-- Tabel pengumpulan data UJI KLINIK HypoSense.
-- Jalankan di Supabase → SQL Editor (sekali saja).
--
-- Model: 1 alat dipakai BANYAK orang (subjek). Tiap subjek punya
-- kode pasien + gender + umur. Tiap pengukuran menyimpan data sensor
-- (dari gelang) + glukosa referensi (dari glukometer suster = label).
-- ============================================================

-- ── Subjek uji klinik (BUKAN akun login) ────────────────────
create table if not exists public.clinical_subjects (
  id          uuid primary key default gen_random_uuid(),
  patient_code text not null,
  gender      text,
  age         int,
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);

-- ── Pengukuran per subjek ────────────────────────────────────
create table if not exists public.clinical_measurements (
  id          uuid primary key default gen_random_uuid(),
  subject_id  uuid not null references public.clinical_subjects(id) on delete cascade,
  heart_rate  int,
  prv         numeric,
  voc_acetone numeric,
  temperature numeric,
  humidity    numeric,
  glucose_ref numeric,        -- glukosa referensi glukometer (mg/dL) = LABEL
  ibi_raw     text,           -- IBI mentah "[812,798,...]" → PRV bisa dihitung ulang offline
  note        text,
  device_id   text,
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);

create index if not exists idx_clinical_meas_subject
  on public.clinical_measurements (subject_id, created_at desc);

-- Kode pasien wajib unik. Tanpa ini, kode yang tak sengaja diketik dua kali
-- akan memecah satu orang menjadi dua subjek — dan validasi per-subjek
-- (Leave-One-Subject-Out) akan memperlakukannya sebagai dua orang berbeda,
-- sehingga hasilnya menyesatkan tanpa gejala apa pun.
-- Dibandingkan setelah huruf disamakan dan spasi tepi dibuang, sebab
-- "P001", "p001", dan "P001 " menunjuk pasien yang sama.
create unique index if not exists idx_clinical_subject_code
  on public.clinical_subjects (lower(trim(patient_code)));

-- Aman dijalankan ulang: menambah kolom bila tabel sudah dibuat lebih dulu.
alter table public.clinical_measurements
  add column if not exists ibi_raw text;

-- Kolom untuk sampel napas.
--   jenis    'napas'  = hasil satu embusan, disimpan otomatis dari gelang
--            'manual' = snapshot yang disimpan petugas lewat tombol
--   voc_rel  simpangan aseton terhadap embusan pertama pasien pada sesi itu (%)
alter table public.clinical_measurements
  add column if not exists jenis text;
alter table public.clinical_measurements
  add column if not exists voc_rel numeric;

-- ── Rekaman detak 5 menit ────────────────────────────────────
-- Satu baris = satu rekaman. PRV jangka pendek dibakukan pada rekaman 5 menit,
-- sedangkan satu snapshot hanya memuat 16 denyut terakhir.
--   ibi_raw     selang antar-denyut yang sudah disambung tanpa dobel
--   lost_beats  denyut yang tak terkirim (lebih dari 16 di antara dua paket)
--   gap_s       perkiraan detik tanpa data layak
--   samples     cuplikan tiap 5 detik: detik ke-, hr, prv, voc, suhu, lembap
--   oximeter    HR oksimeter rujukan beserta detik dan HR gelang saat itu
--   lengkap     false bila rekaman berhenti sebelum 5 menit (mis. terputus)
create table if not exists public.clinical_recordings (
  id           uuid primary key default gen_random_uuid(),
  subject_id   uuid not null references public.clinical_subjects(id) on delete cascade,
  started_at   timestamptz not null,
  duration_s   int not null,
  lengkap      boolean not null default true,
  n_beats      int not null default 0,
  lost_beats   int not null default 0,
  gap_s        int not null default 0,
  ibi_raw      text,
  samples      jsonb not null default '[]'::jsonb,
  oximeter     jsonb not null default '[]'::jsonb,
  glucose_ref  numeric,
  note         text,
  device_id    text,
  created_by   uuid references auth.users(id) default auth.uid(),
  created_at   timestamptz not null default now()
);

create index if not exists idx_clinical_rec_subject
  on public.clinical_recordings (subject_id, created_at desc);

-- ── RLS: aktif; tim peneliti (user terautentikasi) boleh CRUD ─
alter table public.clinical_subjects     enable row level security;
alter table public.clinical_measurements enable row level security;
alter table public.clinical_recordings   enable row level security;

drop policy if exists clinical_subjects_all on public.clinical_subjects;
create policy clinical_subjects_all on public.clinical_subjects
  for all to authenticated using (true) with check (true);

drop policy if exists clinical_measurements_all on public.clinical_measurements;
create policy clinical_measurements_all on public.clinical_measurements
  for all to authenticated using (true) with check (true);

drop policy if exists clinical_recordings_all on public.clinical_recordings;
create policy clinical_recordings_all on public.clinical_recordings
  for all to authenticated using (true) with check (true);

-- Ekspor data untuk analisis: Supabase → Table Editor →
-- clinical_measurements → tombol Export → CSV.


-- ============================================================
-- PEMERIKSAAN RANTAI PENUH
-- Jalankan SETELAH satu pengukuran percobaan dari aplikasi.
-- Yang paling penting diperiksa: kolom ibi_raw terisi atau tidak,
-- sebab dari situlah PRV dihitung ulang saat analisis.
-- ============================================================
-- select
--   s.patient_code,
--   m.created_at,
--   m.heart_rate,
--   m.prv,
--   m.voc_acetone,
--   m.glucose_ref,
--   case
--     when m.ibi_raw is null or m.ibi_raw = '' then 'KOSONG - PERIKSA'
--     else length(m.ibi_raw) || ' karakter, ' ||
--          (length(m.ibi_raw) - length(replace(m.ibi_raw, ',', '')) + 1) ||
--          ' denyut'
--   end as status_ibi
-- from public.clinical_measurements m
-- join public.clinical_subjects s on s.id = m.subject_id
-- order by m.created_at desc
-- limit 5;

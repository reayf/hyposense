-- ============================================================
-- HypoSense — Setup tabel `readings` (data sensor dari ESP32)
-- Jalankan di: Supabase Dashboard → SQL Editor → New query → Run
-- Aman dijalankan berulang kali (idempotent).
--
-- Skema mengikuti dokumen konteks proyek (bagian 3.4).
-- ============================================================

create table if not exists public.readings (
  id           bigint generated always as identity primary key,
  device_id    text not null default 'gelang_001',
  heart_rate   int,                          -- bpm dari MAX30105
  prv          double precision,             -- Pulse Rate Variability (opsional)
  voc_acetone  double precision,             -- nilai mentah MQ-138
  temperature  double precision,             -- SHT31 (derajat C)
  humidity     double precision,             -- SHT31 (%)
  risk_status  text not null default 'negatif',  -- 'positif' | 'negatif'
  created_at   timestamptz not null default now()
);

-- Index untuk query "reading terbaru" yang dipakai aplikasi
create index if not exists readings_created_at_idx
  on public.readings (created_at desc);

-- ── Kolom untuk pengambilan data primer ─────────────────────
-- Aman dijalankan ulang. Ditambahkan supaya rekaman semalaman benar-benar
-- dapat dipakai untuk analisis, bukan sekadar ditampilkan di layar.
--
-- ibi_raw  DERET SELANG ANTAR-DENYUT, "[812,798,...]". Kolom terpenting di
--          antara ketiganya. Kolom `prv` hanya memuat SATU angka dari rumus
--          yang kebetulan dipakai malam itu; bila kemudian ingin dihitung
--          RMSSD, SDNN, atau pNN50 — persis ciri yang dipakai model —
--          semuanya harus dihitung dari deret mentah. Tanpa kolom ini, data
--          semalaman tidak dapat dipakai ulang dan perekaman harus diulang.
--
-- voc_ppm  hasil pengubahan Rs/R0 ke ppm. NULL selama R0 belum dikalibrasi
--          lewat CALR0, sehingga angka yang belum sahih tidak tersimpan
--          seolah-olah sahih.
--
-- voc_rel  simpangan terhadap patokan napas personal, dalam persen. Inilah
--          yang sesungguhnya dipakai gerbang VOC mengambil keputusan, dan
--          satu-satunya besaran VOC yang tidak bergantung pada kurva ppm
--          yang belum terkalibrasi.
alter table public.readings add column if not exists ibi_raw text;
alter table public.readings add column if not exists voc_ppm double precision;
alter table public.readings add column if not exists voc_rel double precision;

-- ── Row Level Security ──────────────────────────────────────
-- Catatan prototipe PKM: insert dibuka untuk anon karena ESP32
-- mengirim data memakai publishable/anon key. Untuk produksi,
-- perketat dengan per-device secret atau Edge Function.
alter table public.readings enable row level security;

drop policy if exists "esp32_insert_readings" on public.readings;
create policy "esp32_insert_readings"
  on public.readings for insert
  to anon, authenticated
  with check (true);

drop policy if exists "app_select_readings" on public.readings;
create policy "app_select_readings"
  on public.readings for select
  to anon, authenticated
  using (true);

-- ── Aktifkan Realtime untuk tabel ini ───────────────────────
do $$
begin
  alter publication supabase_realtime add table public.readings;
exception
  when duplicate_object then null;  -- sudah terdaftar, aman dilewati
end $$;

-- ── (Opsional) Data contoh untuk menguji tampilan realtime ──
-- Hapus tanda komentar lalu Run untuk menyisipkan 1 baris uji.
-- Baris ini akan langsung muncul di homepage aplikasi jika
-- realtime sudah jalan.
--
-- insert into public.readings
--   (device_id, heart_rate, prv, voc_acetone, temperature, humidity, risk_status)
-- values
--   ('gelang_001', 72, 42.5, 310.0, 36.6, 55.0, 'negatif');

-- =============================================================
-- HypoSense — Tahap 5: Penautan Perangkat (device_id <-> akun)
-- AMAN dijalankan berulang kali (idempotent).
-- Jalankan di: Supabase Dashboard → SQL Editor → Run
-- PRASYARAT: roles_setup.sql sudah dijalankan (fungsi get_my_role dkk).
--
-- Isi:
--  1. Tabel devices — pasien mengklaim device_id gelangnya
--  2. Kolom user_id di readings + index
--  3. Trigger: reading masuk otomatis ditandai pemilik perangkatnya
--  4. Trigger: saat perangkat diklaim, reading lama ikut diklaim
--  5. RLS readings diperketat per-pasien (+ hormati toggle
--     share_with_caregiver untuk data live)
-- =============================================================

-- ── 1. Tabel devices ─────────────────────────────────────────
create table if not exists public.devices (
  device_id  text primary key,          -- mis. 'gelang_001' (di firmware)
  user_id    uuid references public.profiles on delete cascade not null,
  claimed_at timestamptz not null default now()
);

alter table public.devices enable row level security;

drop policy if exists "devices_select" on public.devices;
create policy "devices_select"
  on public.devices for select
  using (user_id = auth.uid() or public.get_my_role() = 'admin');

drop policy if exists "devices_insert" on public.devices;
create policy "devices_insert"
  on public.devices for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "devices_delete" on public.devices;
create policy "devices_delete"
  on public.devices for delete
  using (user_id = auth.uid() or public.get_my_role() = 'admin');

-- ── 2. Kolom pemilik di readings ─────────────────────────────
alter table public.readings
  add column if not exists user_id uuid references public.profiles on delete set null;

create index if not exists readings_user_created_idx
  on public.readings (user_id, created_at desc);

-- ── 3. Reading baru otomatis ditandai pemiliknya ─────────────
-- ESP32 tidak perlu tahu akun siapa-siapa — cukup kirim device_id;
-- trigger ini mengisi user_id dari tabel devices.
create or replace function public.assign_reading_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.user_id is null then
    select user_id into new.user_id
    from public.devices
    where device_id = new.device_id;
  end if;
  return new;
end;
$$;

drop trigger if exists readings_assign_user on public.readings;
create trigger readings_assign_user
  before insert on public.readings
  for each row execute procedure public.assign_reading_user();

-- ── 4. Klaim perangkat -> reading lama ikut diklaim ──────────
create or replace function public.claim_existing_readings()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.readings
  set user_id = new.user_id
  where device_id = new.device_id and user_id is null;
  return new;
end;
$$;

drop trigger if exists devices_claim_readings on public.devices;
create trigger devices_claim_readings
  after insert on public.devices
  for each row execute procedure public.claim_existing_readings();

-- ── 5. RLS readings per-pasien ───────────────────────────────
-- Yang boleh MEMBACA sebuah reading:
--  * reading dari perangkat yang belum diklaim siapapun (mode demo)
--  * pemiliknya sendiri
--  * admin
--  * perawat yang terhubung DAN pasiennya mengizinkan berbagi data
-- Insert tetap terbuka untuk anon (jalur ESP32) — tidak diubah.
drop policy if exists "app_select_readings" on public.readings;
drop policy if exists "readings_select" on public.readings;
create policy "readings_select"
  on public.readings for select
  to anon, authenticated
  using (
    user_id is null
    or user_id = auth.uid()
    or public.get_my_role() = 'admin'
    or (public.is_caregiver_of(user_id) and public.patient_shares_data(user_id))
  );

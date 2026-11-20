-- =============================================================
-- HypoSense — Tahap 3: Sistem Peran (patient / caregiver / admin)
-- AMAN dijalankan berulang kali (idempotent).
-- Jalankan di: Supabase Dashboard → SQL Editor → Run
--
-- Isi:
--  1. Normalisasi nilai peran + kolom email di profiles
--  2. Tabel care_links (relasi perawat<->pasien, di-assign admin)
--  3. Fungsi helper RLS (SECURITY DEFINER, anti-rekursi)
--  4. Trigger pengaman: hanya admin boleh mengubah peran
--  5. Kebijakan RLS baru (profiles, care_links, risk_logs —
--     termasuk penegakan toggle share_with_caregiver!)
--  6. Trigger signup diperbarui (role 'patient' + simpan email)
--  7. Bootstrap: jadikan akunmu admin (GANTI EMAIL BILA PERLU)
-- =============================================================

-- ── 1. Normalisasi peran + kolom email ───────────────────────
update public.profiles set role = lower(role) where role <> lower(role);

alter table public.profiles add column if not exists email text;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

-- ── 2. Tabel relasi perawat <-> pasien ───────────────────────
create table if not exists public.care_links (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid references public.profiles on delete cascade not null,
  patient_id uuid references public.profiles on delete cascade not null,
  created_at timestamptz not null default now(),
  unique (caregiver_id, patient_id)
);

alter table public.care_links enable row level security;

-- ── 3. Fungsi helper RLS ─────────────────────────────────────
-- SECURITY DEFINER: membaca tabel tanpa melewati RLS pemanggil,
-- sehingga kebijakan tidak rekursif.
create or replace function public.get_my_role()
returns text
language sql stable security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_caregiver_of(p uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.care_links
    where caregiver_id = auth.uid() and patient_id = p
  )
$$;

create or replace function public.patient_shares_data(p uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(
    (select share_with_caregiver from public.user_settings where user_id = p),
    true
  )
$$;

-- ── 4. Pengaman perubahan peran ──────────────────────────────
-- User biasa tidak boleh menaikkan perannya sendiri (mis. jadi admin
-- lewat REST API). auth.uid() null = akses service-role/SQL Editor,
-- tetap diizinkan agar bootstrap manual bisa dilakukan.
create or replace function public.guard_role_change()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and public.get_my_role() is distinct from 'admin' then
    raise exception 'Hanya admin yang boleh mengubah peran';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
  before update on public.profiles
  for each row execute procedure public.guard_role_change();

-- ── 5. Kebijakan RLS baru ────────────────────────────────────

-- PROFILES: lihat = milik sendiri / admin / perawat yang terhubung
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select"
  on public.profiles for select
  using (
    auth.uid() = id
    or public.get_my_role() = 'admin'
    or public.is_caregiver_of(id)
  );

-- PROFILES: update = milik sendiri / admin (perubahan role tetap
-- dijaga trigger di atas)
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;
create policy "profiles_update"
  on public.profiles for update
  using (auth.uid() = id or public.get_my_role() = 'admin');

-- CARE_LINKS: lihat = admin / perawat ybs / pasien ybs;
-- tambah & hapus = admin saja
drop policy if exists "care_links_select" on public.care_links;
create policy "care_links_select"
  on public.care_links for select
  using (
    public.get_my_role() = 'admin'
    or caregiver_id = auth.uid()
    or patient_id = auth.uid()
  );

drop policy if exists "care_links_insert" on public.care_links;
create policy "care_links_insert"
  on public.care_links for insert
  with check (public.get_my_role() = 'admin');

drop policy if exists "care_links_delete" on public.care_links;
create policy "care_links_delete"
  on public.care_links for delete
  using (public.get_my_role() = 'admin');

-- RISK_LOGS: di sinilah toggle "Share data with caregiver"
-- DITEGAKKAN — perawat hanya bisa membaca riwayat pasien yang
-- terhubung dengannya DAN mengizinkan berbagi data.
drop policy if exists "Users can manage own risk logs" on public.risk_logs;
drop policy if exists "risk_logs_select" on public.risk_logs;
create policy "risk_logs_select"
  on public.risk_logs for select
  using (
    auth.uid() = user_id
    or public.get_my_role() = 'admin'
    or (public.is_caregiver_of(user_id) and public.patient_shares_data(user_id))
  );

drop policy if exists "risk_logs_insert" on public.risk_logs;
create policy "risk_logs_insert"
  on public.risk_logs for insert
  with check (auth.uid() = user_id);

-- ── 6. Trigger signup: peran default 'patient' + simpan email ─
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    'patient',
    new.email
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- ── 7. Bootstrap admin pertama ───────────────────────────────
-- GANTI email di bawah jika akun admin-nya bukan ini.
update public.profiles
set role = 'admin'
where id in (
  select id from auth.users where email = 'rafiebarus01@gmail.com'
);

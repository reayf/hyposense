-- =============================================================
-- HypoSense — Tahap 4: Halaman Akun (foto profil)
-- AMAN dijalankan berulang kali (idempotent).
-- Jalankan di: Supabase Dashboard → SQL Editor → Run
--
-- Isi:
--  1. Kolom avatar_url di profiles
--  2. Storage bucket `avatars` (publik untuk dibaca)
--  3. Kebijakan storage: tiap user hanya bisa unggah/ubah file
--     di folder miliknya sendiri ({user_id}/...)
-- =============================================================

-- ── 1. Kolom avatar ──────────────────────────────────────────
alter table public.profiles add column if not exists avatar_url text;

-- ── 2. Bucket avatars ────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- ── 3. Kebijakan storage ─────────────────────────────────────
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars_user_insert" on storage.objects;
create policy "avatars_user_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_user_update" on storage.objects;
create policy "avatars_user_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_user_delete" on storage.objects;
create policy "avatars_user_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

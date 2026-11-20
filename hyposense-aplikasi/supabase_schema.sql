-- =============================================
-- HypoSense — Supabase Database Schema
-- Jalankan di: Supabase Dashboard → SQL Editor
-- =============================================

-- 1. PROFILES
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null default 'User',
  role text not null default 'Patient',
  emergency_contact text,
  created_at timestamptz not null default now()
);

-- 2. DEVICE DATA
create table if not exists public.device_data (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles on delete cascade not null,
  battery_level int not null default 0,
  connection_strength text not null default 'Unknown',
  last_update timestamptz not null default now(),
  voc_sensor_active boolean not null default false
);

-- 3. SENSOR READINGS
create table if not exists public.sensor_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles on delete cascade not null,
  voc_trend text not null default 'Stable',
  sleep_quality text not null default 'Restful',
  temperature float not null default 36.5,
  recorded_at timestamptz not null default now()
);

-- 4. RISK LOGS
create table if not exists public.risk_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles on delete cascade not null,
  risk_status text not null default 'SAFE', -- SAFE | WARNING | DANGER
  message text not null default '',
  created_at timestamptz not null default now()
);

-- 5. USER SETTINGS
create table if not exists public.user_settings (
  user_id uuid references public.profiles on delete cascade primary key,
  save_to_cloud boolean not null default true,
  share_with_caregiver boolean not null default true,
  enable_alarm boolean not null default true,
  risk_alert_level text not null default 'moderate',
  alert_method text not null default 'sound',
  theme text not null default 'light',
  language text not null default 'English'
);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

alter table public.profiles enable row level security;
alter table public.device_data enable row level security;
alter table public.sensor_readings enable row level security;
alter table public.risk_logs enable row level security;
alter table public.user_settings enable row level security;

-- Profiles
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- Device Data
drop policy if exists "Users can manage own device data" on public.device_data;
create policy "Users can manage own device data"
  on public.device_data for all using (auth.uid() = user_id);

-- Sensor Readings
drop policy if exists "Users can manage own sensor readings" on public.sensor_readings;
create policy "Users can manage own sensor readings"
  on public.sensor_readings for all using (auth.uid() = user_id);

-- Risk Logs
drop policy if exists "Users can manage own risk logs" on public.risk_logs;
create policy "Users can manage own risk logs"
  on public.risk_logs for all using (auth.uid() = user_id);

-- User Settings
drop policy if exists "Users can manage own settings" on public.user_settings;
create policy "Users can manage own settings"
  on public.user_settings for all using (auth.uid() = user_id);

-- =============================================
-- AUTO-CREATE PROFILE ON REGISTER (Trigger)
-- =============================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    'Patient'
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- SIGNAL360 proposed PostgreSQL + PostGIS schema
-- Review with a qualified database/security engineer before production use.
create extension if not exists pgcrypto;
create extension if not exists postgis;

create type public.verification_status as enum ('unknown','reported','verified','rejected');
create type public.building_visibility as enum ('private','public');
create type public.membership_role as enum ('owner','admin','analyst','field_verifier','viewer');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  org_type text not null check (org_type in ('isp','property_manager','developer','service_partner','other')),
  country_code char(2) not null default 'KE',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role public.membership_role not null,
  created_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);

create table public.buildings (
  id uuid primary key default gen_random_uuid(),
  public_slug text unique,
  display_name text not null,
  address_public text,
  neighbourhood text,
  city text not null,
  region text,
  country_code char(2) not null,
  building_type text,
  approximate_location geography(point,4326),
  visibility public.building_visibility not null default 'private',
  verification public.verification_status not null default 'unknown',
  last_verified_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index buildings_location_idx on public.buildings using gist(approximate_location);
create index buildings_city_idx on public.buildings(country_code,city,neighbourhood);

create table public.infrastructure_assessments (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.buildings(id) on delete cascade,
  fibre_status public.verification_status not null default 'unknown',
  internal_cabling_status public.verification_status not null default 'unknown',
  access_status public.verification_status not null default 'unknown',
  provider_serviceability public.verification_status not null default 'unknown',
  readiness_score smallint check (readiness_score between 0 and 100),
  methodology_version text not null default '0.1',
  assessed_by uuid references auth.users(id),
  assessed_at timestamptz not null default now(),
  review_status public.verification_status not null default 'reported'
);

create table public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.infrastructure_assessments(id) on delete cascade,
  evidence_type text not null,
  storage_path text,
  source_description text,
  captured_at timestamptz,
  submitted_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  review_status public.verification_status not null default 'reported',
  created_at timestamptz not null default now()
);

create table public.provider_presence (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.buildings(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  service_type text not null,
  status public.verification_status not null default 'reported',
  evidence_id uuid references public.evidence_items(id),
  checked_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique(building_id,organization_id,service_type,checked_at)
);

create table public.network_incidents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id),
  building_id uuid references public.buildings(id),
  incident_category text not null,
  started_at timestamptz not null,
  restored_at timestamptz,
  impact_count integer,
  source_quality public.verification_status not null default 'reported',
  description_private text,
  created_at timestamptz not null default now(),
  check (restored_at is null or restored_at >= started_at)
);

create table public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references public.buildings(id) on delete cascade,
  organization_id uuid references public.organizations(id),
  insight_type text not null check (insight_type in ('opportunity','reliability','data_quality')),
  summary text not null,
  recommendations jsonb not null default '[]'::jsonb,
  confidence numeric(4,3) check (confidence between 0 and 1),
  model_name text,
  model_version text,
  input_snapshot jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  organization_id uuid references public.organizations(id),
  action text not null,
  resource_type text not null,
  resource_id uuid,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

-- SECURITY DESIGN NOTES:
-- 1) Enable RLS on every table before production.
-- 2) Public users should read only a curated PUBLIC VIEW, never raw tables.
-- 3) Never expose exact private infrastructure coordinates, incident descriptions,
--    uploaded evidence, contact details or provider-specific confidential records.
-- 4) Organization membership must be checked server-side for every tenant query.
-- 5) Field verifiers may submit evidence; a separate reviewer should approve it.
-- 6) AI insights must be generated server-side and include evidence provenance.
-- 7) Add retention, deletion, export and consent workflows appropriate to applicable law.

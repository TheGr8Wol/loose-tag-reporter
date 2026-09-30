-- BE-04: report table with frozen columns (docs/ADR-001-architecture.md)
-- Depends on: store, store_floor, location_node (BE-03) — stubbed here for apply order.

create table if not exists store (
  id uuid primary key,
  code text unique not null,
  name text not null,
  is_multi_floor boolean not null default false
);

create table if not exists store_floor (
  id uuid primary key,
  store_id uuid not null references store(id),
  code text not null,
  label text not null,
  sort_order int not null default 0,
  unique (store_id, code)
);

create table if not exists location_node (
  id uuid primary key, -- StableLocationID UUIDv5 — never regenerated
  store_id uuid not null references store(id),
  floor_id uuid references store_floor(id),
  area_type area_type not null,
  parent_id uuid references location_node(id),
  code text not null,
  label text not null,
  is_other_bucket boolean not null default false,
  is_template boolean not null default false,
  sort_order int not null default 0,
  active boolean not null default true
);

create table if not exists report (
  id uuid primary key default gen_random_uuid(),
  client_uuid uuid not null unique,
  store_id uuid not null references store(id),
  location_id uuid not null references location_node(id),
  location_other_text text,
  found_bucket found_bucket not null,
  found_at timestamptz not null,
  found_at_is_estimate boolean not null default false,
  found_window_start timestamptz, -- FROZEN: incident review window (nullable)
  found_window_end timestamptz,   -- FROZEN: incident review window (nullable)
  notes text,
  status report_status not null default 'submitted',
  tag_count int not null check (tag_count between 1 and 15),
  device_id text not null,
  reporter_emp_id text not null,  -- FROZEN: text, not char(8)
  app_version text,
  created_at timestamptz not null,
  synced_at timestamptz
);

create table if not exists tag (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references report(id) on delete cascade,
  tag_barcode text,
  item_code text,                 -- FROZEN: nullable
  size text not null default '',
  colour text not null default '',
  identify_method identify_method not null,
  tag_state tag_state not null,
  item_name text,
  item_category text,
  style_family_id text
);

create table if not exists report_photo (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references report(id) on delete cascade,
  storage_path text not null,
  captured_at timestamptz not null
);

create table if not exists escalation_event (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references report(id),
  from_status report_status not null,
  to_status report_status not null,
  reason text not null,
  actor text not null,
  note text,
  created_at timestamptz not null default now()
);

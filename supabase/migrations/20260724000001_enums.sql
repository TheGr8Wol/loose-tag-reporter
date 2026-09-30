-- Schema freeze note (docs/ADR-001-architecture.md)
-- Enum labels must match TagReportingCore Enums.swift raw values 1:1.
-- Scaffold only: never applied to a hosted project (data-residency decision was pending).

create type area_type as enum ('SF', 'BOH');
create type found_bucket as enum ('now', 'lt15m', 'lt30m', 'b30m_1h', 'b1_2h', 'b2h_plus', 'custom');
create type tag_state as enum ('intact', 'torn_off', 'cut', 'damaged', 'concealed');
create type identify_method as enum ('scan', 'manual_code', 'name_search', 'unidentified');
create type report_status as enum ('submitted', 'reviewed', 'actioned');
create type trading_phase as enum ('pre_open', 'trading', 'post_close');
create type flag_threshold_scope as enum ('global', 'area', 'floor', 'endpoint');
create type sync_state as enum ('pending', 'syncing', 'synced', 'failed');

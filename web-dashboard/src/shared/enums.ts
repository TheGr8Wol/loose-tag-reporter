/** Frozen enums — must match TagReportingCore Enums.swift / Postgres DDL 1:1 (ADR-001). */
export type AreaType = 'SF' | 'BOH'
export type FoundBucket = 'now' | 'lt15m' | 'lt30m' | 'b30m_1h' | 'b1_2h' | 'b2h_plus' | 'custom'
export type TagState = 'intact' | 'torn_off' | 'cut' | 'damaged' | 'concealed'
export type IdentifyMethod = 'scan' | 'manual_code' | 'name_search' | 'unidentified'
export type ReportStatus = 'submitted' | 'reviewed' | 'actioned'
export type TradingPhase = 'pre_open' | 'trading' | 'post_close'
export type FlagThresholdScope = 'global' | 'area' | 'floor' | 'endpoint'
export type DashboardRole = 'supervisor' | 'lp_admin'

export const IDENTIFY_METHODS: IdentifyMethod[] = [
  'scan',
  'manual_code',
  'name_search',
  'unidentified',
]

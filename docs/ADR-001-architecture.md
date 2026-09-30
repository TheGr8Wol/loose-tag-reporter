# ADR-001: Architecture & Schema Freeze (M0 Gate)

**Status:** Accepted
**Date:** 2026-07-24
**Blocks:** M2 persistence, backend row-level security work, web dashboard data screens

## Context

The Loose Tag Reporter proof of concept needs an offline-first iOS reporter, a web loss-prevention
dashboard and a shared Supabase (Postgres) backend. Three clients must agree on enums, columns and
stable location IDs before any persistence code lands, or they drift apart silently.

## Decisions

### 1. Local store: GRDB/SQLite (single `app.sqlite`)

SwiftData is rejected in favour of GRDB for explicit SQL, migrations and predictable concurrency.
One `DatabasePool` holds the outbox plus the reference/config tables. Files use iOS Data Protection;
SQLCipher remains a drop-in behind `DatabaseManager` if database-level encryption is mandated.

### 2. Layering (compiler + CI enforced)

```
Presentation (SwiftUI) → Repositories (app target) → TagReportingCore (Foundation-only)
```

- `TagReportingCore` must not import SwiftUI, GRDB or Supabase.
- `Features/` must not import Supabase directly.
- Enforced by `Scripts/layering_guardrail.sh` in CI and as an Xcode pre-build step.

### 3. Cold-start contract

1. Camera/scanner goes live immediately (target < 1.5 s).
2. Reference seeding runs async, off the critical path.
3. The location step is gated on `seedReady`.
4. Codes that cannot be enriched yet submit as "Unknown item" and back-fill when the index is ready.

### 4. Schema freeze

These override earlier draft DDL in the PRD:

| Item | Frozen decision |
|------|-----------------|
| `reporter_emp_id` | **`text`** (opaque string, not a fixed-width char) |
| `found_window_start` / `found_window_end` | **Added** to `report` (nullable `timestamptz`) |
| `tag.item_code` | **Nullable** |
| `identify_method` | Adds **`unidentified`** |
| Loss-prevention dashboard surface | **Web-only**; no dashboard screens in the iOS app |
| Flag engine location | **Server-side** evaluation recommended |

### 5. StableLocationID (frozen)

- **Namespace UUID:** `7c9e6679-7425-40de-944b-e07fc1f90ae7`
- **Algorithm:** UUIDv5 (RFC 4122) over the UTF-8 stable key
- **Key format:** `{storeCode}/{floorCode?}/{areaType}/{path...}` where `areaType` is `SF` or `BOH`
- **Golden vectors:** `Packages/TagReportingCore/Tests/TagReportingCoreTests/StableLocationIDTests.swift`
  (cross-checked against Python's `uuid.uuid5`)

A future visual map picker binds to these IDs, so they must never be regenerated.

### 6. Silent app constraint

No audio APIs (`AudioToolbox`, `AVAudioPlayer`, system sounds). Haptics only, gated on Reduce Motion.
Enforced by the CI lint in `Scripts/layering_guardrail.sh`.

### 7. Dev-default store binding

When the MDM managed configuration is absent, a dev-default store binding shows a **loud banner** and
**refuses submit** until a production binding is present. Reports can never be silently attributed
to the wrong store.

## Consequences

- The PRD's draft DDL is reconciled to this freeze in `supabase/migrations/`.
- Any backend seed generator must implement the same `StableLocationID` spec and pass the golden vectors.
- Web TypeScript types (`web-dashboard/src/shared/enums.ts`) must mirror the Core enums; the Core
  `EnumDriftTests` pin the raw values to the Postgres enum labels.

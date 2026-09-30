# Progress (status and milestones)

**Overall status:** proof of concept, stopped before any pilot. Not deployed; no real users or data.

## Done

| Milestone | What exists | Evidence |
|-----------|-------------|----------|
| M0 scaffold + schema freeze | XcodeGen project, Core package, web shell, Postgres enums/core tables, ADR-001 | Core enum drift tests; StableLocationID golden vectors |
| M2 local data | GRDB store, idempotent seed import, single-slot draft autosave, orphan-photo sweep | `PersistenceTests` |
| Identity (parser) | Configurable `ArticleNumberParser` (OCR-tolerant), `ItemResolver` with unidentified escape | `ArticleNumberParserTests`, `ItemResolverTests` |
| Sync | Single-flight FIFO `SyncEngine` with resume-after-partial-failure, proven against an in-memory remote; `docs/SYNC_CONTRACT.md` | `SyncEngineTests` |
| Session / gate | Staff-code policy, Keychain session, idle lock, role-PIN gate (salted hash, constant-time compare) | `AuthTests` |
| Location survey + flow logic | `LocationSurveyViewModel`, `FoundTimeResolver`, `ReportingFlowCoordinator` with a tap-budget test | `SurveyAndCameraTests`, `FlowCoordinatorTests` |
| SwiftUI step screens | Scan, When, Photo, Where, Review, Confirmation wired to the coordinator (live camera and photo capture are stubs) | Source only; see verification note below |
| Design system (minimal) | Design tokens; primary and secondary buttons, chips, code field, centralised copy | — |

**Verification**
- `TagReportingCore`: 31/31 tests pass (re-run on this public copy).
- iOS app tests (`LooseTagReporterTests`): passed in the original environment with full Xcode; the
  public copy has **not** been rebuilt or re-run (no full Xcode available when it was prepared).

## Not done / blocked on external input

| Item | Blocked by |
|------|------------|
| Live camera scanning (VisionKit OCR) and photo capture | Test devices and real tags |
| Supabase project, real `RemoteReportStore`, dashboard data | Data-residency decision |
| Row-level security and dashboard auth exchange | Role-token decision (PIN → JWT) |
| Server-side auto-flag evaluation | Backend provisioning |
| Device distribution (MDM, enrollment) | Pilot approval (none sought) |
| Final back-of-house taxonomy | Store walk |
| Any real-data pilot | Staff-data privacy notice |

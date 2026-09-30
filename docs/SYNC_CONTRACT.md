# Sync / idempotency contract (BE-25)

Agreed between the iOS remote layer and the Supabase backend.

## Client → server

| Operation | Semantics |
|-----------|-----------|
| Report + tags upsert | `ON CONFLICT (client_uuid)` — replace/merge; never create a second report row |
| Tag re-sync | No-op when tags for `client_uuid` already match; safe to re-send full tag set |
| Photo PUT | Path `{store_id}/{client_uuid}/{photoId}.jpg` — overwrite same object key |
| Server stamp | `synced_at` set by server (or accepted from client then overwritten) |

## Engine rules (iOS)

1. **Single-flight** — concurrent `triggerSyncIfNeeded` coalesce to one run.
2. **FIFO** — process outbox ordered by `created_at`.
3. **Per report** — upsert report+tags, then upload each photo, then mark synced + dequeue.
4. **Partial failure** — if photo upload fails after upsert, row stays in outbox; retry must not create duplicate server reports.
5. **Offline** — enqueue only; zero loss; sync on foreground / reachability-online / post-login.

## Acceptance script

1. Double-upsert same `client_uuid` → exactly one `report` row + N `tag` rows.
2. Re-upload photo to same key → one object, overwritten bytes.
3. Interrupt after upsert before photo → resume completes photos; still one report row.

Validated against `MockRemoteReportStore` (see `LooseTagReporterTests/SyncAndAuthTests.swift`). A real Supabase implementation would slot in behind the same `RemoteReportStore` protocol; it was never built because the backend was never provisioned.

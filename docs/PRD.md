# Product Requirements — Loose Tag Reporter (condensed)

> This is a condensed version of the PRD. Store details (the "Demo Store", products, layout and
> identifiers) are synthetic. Numbers marked *illustrative* are placeholders.

**Platform:** iOS reporter on shared, store-managed devices + web dashboard for loss prevention
**Status:** Proof of concept. Never deployed or piloted.

---

## 1. Problem

In retail stores that use RFID price tags, the tag's embedded chip links the physical garment to
inventory and, where it is used, to RFID self-checkout. When a tag is torn or cut off a garment,
that link breaks:

- the garment can no longer be read at self-checkout, and
- inventory still counts it as in stock, so the loss is invisible — no time, no place, no trail.

Loose tags found on the floor tend to be thrown away. Each one is an early shrink signal with no
evidence attached, so loss prevention (LP) has no way to see where and when tags are being removed.

**Goal:** turn each loose-tag find into structured, time- and location-stamped evidence, captured in
seconds by floor staff, that aggregates into patterns LP can act on.

**Design tension:** the reporter must be effortless during busy trade (or staff won't use it), while the
data must be clean enough for analysis (or it's worthless). Resolution: a two-decision happy path, with
all richness pushed into optional or branching steps.

## 2. Goals and non-goals

**Goals**
1. Capture finds at the point of discovery with minimal friction (happy path ≈ two decisions: *Now* + *Submit*).
2. Produce a clean, reconciliation-ready dataset: tag identity + location + time window + tag state + optional photo.
3. Give LP a decision surface: zone heatmap, exception flags, filters, CSV export.
4. Work anywhere in the store: offline-first with a durable sync queue.
5. Onboard a new store with configuration, not code (per-store floors and back-of-house rooms).
6. Be a foundation: stable IDs and clean identity so RFID reconciliation and a map picker can attach later.

**Non-goals (this release)**
- **No suspect, customer or biometric data.** No suspect identity, no staff-as-suspect data; the
  schema has no column for any of it. The only person-linked fields are the reporter's staff code
  (`reporter_emp_id`) and the escalation `actor`, which are meant to be access-controlled (see §4).
- No live integrations with inventory, POS or incident tools (designed for, not built).
- No multi-tenant productisation; one organisation per deployment.
- No Android reporter.

## 3. Users and roles

| Role | Need | Access |
|---|---|---|
| Floor staff | Report a loose tag in seconds, one-handed, mid-trade | Submit-only. No read access to other reports. |
| Supervisor | Review, filter, spot patterns, escalate | Dashboard + escalation actions |
| LP admin | Tune flag thresholds, manage accounts, see reporter attribution | Everything above + configuration |

**POC authentication:** staff enter a numeric staff code for attribution only (no server validation;
works fully offline). The dashboard is a separate online surface gated by two role PINs, behind a
`DashboardAuthProviding` seam that can later be swapped for SSO. PINs are provisioned out-of-band and
never stored in source. Shared devices return to the code screen after an idle timeout.

## 4. Guardrails

- **Data scope is product / tag / location / time, plus reporter attribution.** No suspect, customer
  or biometric data. The reporter's staff code (`reporter_emp_id`) and the escalation `actor` are the
  only person-linked fields and are visible only to supervisor/LP roles; `device_id` identifies a
  shared, managed device. Server-side enforcement (row-level security) is planned, not built.
- **Store layout and back-of-house data are confidential.** Role-based access, encryption in transit
  and at rest, and floor staff see only what they need to file a report.
- **Speed is a guardrail.** Any change that adds a decision to the happy path is a regression.

## 5. Identity model

- Only the tag carries machine-readable identity; garments do not.
- The tag carries two identifiers:
  - a **retail barcode** (EAN-13 style), stored raw as `tag_barcode` — a durable key for later
    reconciliation even when the item can't be named today;
  - a **printed article number** containing item, colour and size codes in plain text, which the
    app OCRs and parses fully on-device.
- The article-number layout is configurable (`ArticleNumberFormat`); the repo ships a synthetic demo
  layout `PPP-IIIIIII-CC-SSS`.
- Product reference data is an **enrichment layer only** (name/category for display and search),
  never on the critical identity path. A missing item submits as "Unknown item".
- **Fallbacks** when a tag is damaged: enter the item code manually, search by name, or mark the tag
  *unidentified*. A find is never blocked.

## 6. Data model (summary)

Authoritative DDL: `supabase/migrations/`. Frozen deltas: `docs/ADR-001-architecture.md`.

- `report` — one submission; the unit LP reviews. Idempotency key `client_uuid`; `found_bucket`,
  `found_at`, `found_window_start/end` (the review window); `status` (`submitted → reviewed → actioned`);
  `tag_count` 1–15; `reporter_emp_id` (staff attribution, access-controlled).
- `tag` — 1–15 per report. `tag_barcode`, nullable `item_code`, size, colour, `identify_method`,
  required `tag_state` (`intact / torn_off / cut / damaged / concealed`), optional `style_family_id`
  to group re-released variants of the same design.
- `report_photo` — optional exact-spot photo, uploaded via the sync queue.
- `store`, `store_floor`, `location_node` — the survey taxonomy stored as a tree. `location_node.id`
  is a **StableLocationID** (UUIDv5 of a readable key) so a future map binds to the same IDs.
- `escalation_event` — intended as an append-only audit trail of every status transition (from, to,
  reason, actor, note). Table only: nothing writes it yet and append-only is not enforced in SQL.

## 7. Location taxonomy (Demo Store)

- **Level 1 — Floor** (only for multi-floor stores). Demo Store: `B1`, `GF`, `L1`.
- **Level 2 — Area:** Sales Floor (`SF`) or Back of House (`BOH`).
- **Level 3 — Endpoint:**
  - SF uses a **fixed template shared by every store**: Checkout, Fitting Rooms, Entrance, Zone A–D, Other?
    Per-floor exclusions come from the store profile (Demo Store's basement has no entrance).
  - BOH rooms are **per-store configuration** (Demo Store: Receiving Dock, Stockroom, Staff Break Room,
    Store Office).
- **Sub-levels** at the two hotspots only: Fitting Rooms → booth / corridor; Checkout → self-checkout / staffed.
- **Other?** turns into a text box; the text is copied into the report notes and the report is saved
  against the `Other` endpoint with a filterable flag, so taxonomy gaps surface in the data.

## 8. Reporting flow

`Scan → When → Photo (optional) → Where → Review → Done`

1. **Scan** — camera opens straight to scan. Tag state is chosen as a chip on the same screen.
   "Can't scan?" opens manual entry / unidentified.
2. **When** — *Now* (one tap, exact) or *Earlier* buckets (<15 min, <30 min, 30 min–1 h, 1–2 h, 2 h+).
   Buckets are stored verbatim **and** as a start/end window, avoiding false-precision timestamps.
3. **Photo** — optional, skippable in one tap; "photograph the spot, not people".
4. **Where** — the branching survey above, resolving to a single `location_id`.
5. **Review** — everything editable; add further tags found at the same place and time (cap 15);
   notes. Submit writes locally and enqueues.
6. **Done** — honest copy: "Queued · will sync" when offline, never "sent".

## 9. Dashboard and escalation

- **Dashboard (web):** zone heatmap, filters (zone, time, category, tag state, *Other* locations),
  CSV export.
- **Escalation (designed, not implemented):** `submitted → reviewed → actioned`; every transition is
  to write an `escalation_event`.
- **Auto-flag engine (designed, not implemented):** each report's found time is classified against the
  store's trading calendar (pre-open / trading / post-close) and combined with its area. A report is
  flagged for review when its tag count meets a **minimum per (phase, area)**, stored in
  `flag_threshold_rule` with precedence endpoint > floor > area > global. Flags only prompt a human;
  they never auto-escalate. The shipped defaults are *illustrative* (e.g. any tag in back of house;
  2 / 3 / 4 tags on the sales floor during trading / pre-open / post-close).

## 10. Non-functional requirements

| Area | Requirement |
|---|---|
| Cold start | Camera live in < ~1.5 s; seeding off the critical path |
| Offline | Full capture offline; durable local store; automatic idempotent sync |
| Security | Role-based access; TLS in transit; iOS Data Protection at rest; row-level security planned server-side |
| Privacy | No suspect, customer or biometric data; the reporter's staff code is the only person-linked report field and must be visible only to supervisor/LP roles (row-level security planned) |
| Configurability | New store = profile data (floors, exclusions, back-of-house rooms), no code |
| Accessibility | Dynamic Type, VoiceOver labels, ≥ 44 pt targets, bottom-anchored primary actions |
| Silent | No audio APIs (enforced by CI lint); haptics only |

## 11. Open questions at the time the POC stopped

1. Live OCR acceptance on real devices and real tags (hardware not available).
2. Data-residency decision for the hosted backend region.
3. Role-token mechanism for the dashboard (PIN → JWT) and row-level security policies.
4. Device enrollment / distribution.
5. Ground-truth back-of-house taxonomy from a store walk.
6. Staff-data privacy notice before any real data is collected.

## 12. Success metrics (targets, never measured)

- Median scan-to-submit < 20 s; p90 < 45 s.
- > 95 % of reports with a resolved item identity.
- Zero unrecoverable lost reports.
- "Other" rate per zone falling over time (taxonomy gaps being fixed).

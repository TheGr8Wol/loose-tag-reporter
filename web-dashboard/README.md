# Web dashboard (loss-prevention surface)

Vite + React + TypeScript shell for the supervisor / loss-prevention dashboard.

**Status:** scaffold only. Routing, role-aware navigation (supervisor vs `lp_admin`), light/dark
theming and the shared enum types (`src/shared/enums.ts`, mirrored from the Swift core and the
Postgres DDL) exist. The data screens (reports list, heatmap, flag settings, accounts) are
placeholders; they depend on auth and a live backend, which were never provisioned.

```bash
npm ci
npm run dev     # local dev server
npm run build   # type-check + production build
```

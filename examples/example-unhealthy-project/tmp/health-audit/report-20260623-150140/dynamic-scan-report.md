# Rails Health Audit — Pass 2 (runtime) — example-unhealthy-project

_Generated 2026-06-23 15:03. Booted the app against its database. Raw output in `raw_original_result/`._

## Data correctness & indexing (active_record_doctor)

| Detector | Findings |
|----------|----------|
| missing_unique_indexes | 1 |
| missing_non_null_constraint | 2 |
| missing_foreign_keys | 2 |
| unindexed_foreign_keys | 2 |
| incorrect_dependent_option | 0 |
| lol_dba (missing indexes) | 2 |

See `raw_original_result/pass2_ar_doctor.txt` and `raw_original_result/pass2_lol_dba.txt` for the specific tables/columns.

## Still manual (need the app exercised, not just booted)

- **N+1 queries** — add `bullet` (dev/test) or `prosopite`, then run the suite or
  click through the app; N+1s only surface on code paths that actually execute.
- **Test coverage** — run the suite with `simplecov`, read `coverage/index.html`.

# KMO HR — Production Preflight Evidence

Date: 2026-10-09 (Asia/Bangkok)

## Gate status

- Managed backups: **HOLD / unavailable** — the Supabase organization is on the Free plan; scheduled managed backups are unavailable on this plan.
- Manual logical backup: **PASS** — read-only export completed through the Supabase Session Pooler. Backup artifacts and SHA-256 inventory are stored in a private FileVault-protected location outside Git.
- Isolated restore: **PASS for the tested database and Storage scope**, with the version and project-configuration limits below.
- Independent review: **PASS** at report commit `58798fc5a559fb36f3db471243f01c7d43fc4e25`. The fresh reviewer rechecked the backup/restore totals, Production catalog/ledger, one-migration procedure, and the reported PR-status discrepancy.
- Production security migration: **PASS**. The user explicitly authorized Production Write; only the forward Security Migration was applied and verified. No Attendance test write was performed.
- Production release: **HOLD / in progress** until PR merges, GitHub Pages deployment, and live smoke checks finish. No PR merge or website deployment has been performed yet.
- Existing Supabase Local Test result remains **22/22 PASS**; it was not rerun. Both the original Local Test environment and this separate restore environment remain intact.

## Backup evidence

The manual export ran from 2026-10-09 11:29:11 through 11:40:32 ICT. It contains 7 SQL artifacts for roles, schema, application data, Auth data, Storage metadata, and migration-history schema/data, plus 53 Storage object files from 2 buckets. The payload is 60 files / 7,048,332 bytes; the Storage object files total 5,753,442 bytes. SHA-256 values for every payload file were verified and are held in the private checksum inventory, not this repository.

The SQL artifacts were produced as separate read-only Supabase CLI exports. The export set therefore has a capture window rather than one shared database transaction snapshot. This was checked against Production aggregates during restore verification; no application-table row-count differences were found. Preserve this limitation when using the backup for point-in-time recovery.

Supabase database dumps do not include Storage object bytes. Those 53 files were exported separately, path-mapped, restored through the isolated Local Storage API, and downloaded again for SHA-256 comparison. All 53 downloaded object contents matched their exported file checksums.

## Restore and verification evidence

The restore target was a separate Supabase Local workspace on the isolated Colima test profile; it was not linked to the Production project.

- Roles, schema, application data, Auth data, and application migration history restored successfully.
- Production and restored row counts matched for all 27 application tables.
- Public-schema RLS relation settings matched for 27 relations; 61 policies, 5 public functions, and 28 public triggers matched.
- Auth user and identity row counts matched. Four Auth tables available only in the newer Production Auth service schema were empty in Production. Auth and Storage service migration-history row counts differ because the Local service versions are older.
- Both Storage bucket settings matched for fields supported by the Local Storage schema. Production lifecycle configuration fields were null; the current Local Storage schema does not contain those columns.
- Storage object keys and sizes matched: 53 objects / 5,753,442 bytes. Every object was downloaded from Local and its content SHA-256 matched the private export.

This validates the listed database and object data in the isolated restore. It is not a complete Supabase project-settings backup: Auth provider configuration, API keys, Edge Function secrets, network settings, and similar project-level settings are not contained in these database and object exports.

## Production migration history mapping

The four existing KMO HR Production history entries map to current source files by migration name:

| Production version | Production name | Current source file |
| --- | --- | --- |
| `20261006104402` | `hr_v2_foundation` | `20261006174000_hr_v2_foundation.sql` |
| `20261006104528` | `hr_v2_hardening_bootstrap` | `20261006175500_hr_v2_hardening_bootstrap.sql` |
| `20261006132912` | `hr_line_employee_portal` | `20261006201500_hr_line_employee_portal.sql` |
| `20261006134110` | `hr_line_link_invoker` | `20261006202500_hr_line_link_invoker.sql` |

The Production timestamps differ from the current source filenames; this is a name mapping, not proof that each historical migration was byte-identical to the current file. The Production schema was dumped and restored, and the restored catalog checks above matched Production. A complete source-to-live schema reconciliation against every migration remains **unverified**.

## Pre-migration read-only release snapshot (2026-10-09 12:06 ICT)

- Supabase Management API reports project `ybyseaenceyswjnwdmdf` as `ACTIVE_HEALTHY`, PostgreSQL 17.6.1, in `ap-northeast-2`.
- At this snapshot, Production migration history contained 14 entries, including the four HR versions listed above. The target version `20261008053722` was not yet applied.
- Catalog checks confirm `public.hr_attendance_events` exists with RLS enabled. Effective INSERT is denied to `anon`, allowed to `authenticated`, and allowed to `service_role`. The `hr_attendance_insert` policy is still present for authenticated users. This is the exact security gap the target migration is intended to close; it remains open until that migration is applied.
- GitHub reports both PRs open. At 12:06 ICT, the official GitHub REST response for PR #2 head `62468085d2f24193c9270dc32d1cd238c9da1b16` reported `mergeable=true`, `mergeable_state=clean`; the base commit is an ancestor of that head and local `git merge-tree --write-tree` found no conflict. The Codex GitHub metadata connector returned `mergeable=false` for the same head. Subsequent commits changed PR #2 documentation only; GitHub's mergeability state must be checked again at the final head immediately before merging. PR #2 targets PR #1's branch; there are no submitted review decisions or configured checks reported for these PRs.
- Live GitHub Pages Home still lacks the Attendance History card. `https://kmorackbarcustom.github.io/kmo-tools/hr/attendance.html` currently returns HTTP 404. Therefore the new page is not live yet.
- On the current PR #2 head, `node --test tests/*.test.cjs` passes. Deno is not installed in this checkout environment; the previously recorded Deno test and type-check passes were on unchanged application source (subsequent commits are documentation-only). The existing 22/22 database security test was not repeated, per Owner instruction.
- No production SQL, migration-ledger change, merge, deploy, or Attendance write was performed during these checks.

The read-only catalog result confirmed the target migration's required starting state (existing Attendance table, RLS enabled, authenticated INSERT grant, and direct INSERT policy). It does not claim byte-identical historical migration source.

## Production migration and post-apply verification (2026-10-09 12:15 ICT)

- After explicit user authorization, Supabase CLI 2.116.0 connected through the Session Pooler with TLS required. A fresh CLI ledger comparison confirmed the 14 remote versions matched all 14 fail-fast guards and `20261008053722_hr_attendance_service_role_only` was the sole pending migration.
- `supabase migration up` ran against the isolated single-migration workdir only. CLI reported exactly the target file applied; no historical migration was replayed and no migration ledger was manually edited.
- Post-apply CLI history contains exactly 15 expected remote versions, including `20261008053722`; the Supabase Management API independently reports the same version/name.
- Read-only Production catalog checks passed: RLS remains enabled; effective INSERT is denied to `anon` and `authenticated` and allowed to `service_role`; `hr_attendance_insert` is absent; `hr_attendance_select` remains; `hr_record_line_attendance` EXECUTE is denied to `anon`/`authenticated` and allowed to `service_role`.
- No Production Attendance row was inserted, updated, or deleted for testing.
- The temporary Session Pooler credential file was removed after the CLI operation; no connection secret is recorded in this repository.

Security migration verification is **PASS**. Release remains in progress until PRs merge in order, Pages updates, and live smoke checks complete.

## Security Migration procedure — tested in Local and executed in Production

Target file: `supabase/migrations/20261008053722_hr_attendance_service_role_only.sql`.

Do not run `supabase db push`, replay any of the four historical migrations, or manually edit the Production migration ledger. The Supabase CLI `migration up --db-url` path was tested against a disposable Local database populated with the 14 existing Production migration-history rows and a minimal Attendance table. The temporary workdir contained only the Security Migration and fail-fast marker files for already-applied Production versions. The command applied exactly one new migration and recorded `20261008053722 | hr_attendance_service_role_only`; the ledger count increased from 14 to 15. The isolated privilege check returned INSERT denied for `anon` and `authenticated`, and allowed for `service_role`. The fail-fast markers ensure that an unexpected attempt to replay a prior migration stops the command.

For the Production operation, a temporary workdir contained the exact Security Migration plus fail-fast marker files named for every recorded Production version. The CLI connected through the Session Pooler URL with TLS and ran `supabase migration up --db-url <Session-Pooler-URL> --workdir <single-migration-workdir> --yes`, without `--include-all` or `--linked`. The fresh preflight confirmed all 14 prior versions were already recorded and the only pending file was `20261008053722_hr_attendance_service_role_only.sql`. The CLI recorded that exact version; post-apply ledger and catalog checks are above. The same procedure had previously been tested against a disposable Local database.

The user explicitly authorized the Production Write in this conversation. Post-apply verification used read-only catalog queries and wrote no Attendance rows. If any release verification fails, stop and keep Direct INSERT denied.

## Independent review and Owner decision

Independent backup review: **PASS** at report commit `58798fc5a559fb36f3db471243f01c7d43fc4e25`. The reviewer confirmed the private inventory contains 60 checksum-verified files / 7,048,332 bytes, the 53 Storage objects / 5,753,442 bytes, the four name-based migration mappings, and the Local-only CLI ledger probe. A separate post-migration read-only review verified the Production ledger, grants, RLS, policies, and RPC privileges. That review requested this report and PR-description update before merge; the current report records the post-migration state.

Historical migration SQL has not been proven byte-identical to current source; the four history entries are mapped by name. The target migration preconditions matched the Production catalog before apply, and the post-migration verification passed. Production release remains **HOLD** until the corrected report and PR descriptions receive an independent documentation check, PR #1 then PR #2 merge to `main`, Pages updates, and the live smoke checks pass. No Production Attendance test row will be written.

## References

- [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups)
- [Supabase Backup and Restore with the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
- [Supabase Storage download objects](https://supabase.com/docs/guides/storage/management/download-objects)
- [Supabase platform-to-self-hosted restore scope](https://supabase.com/docs/guides/self-hosting/restore-from-platform)

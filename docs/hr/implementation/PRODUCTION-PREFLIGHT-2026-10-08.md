# KMO HR — Production Preflight Evidence

Date: 2026-10-09 (Asia/Bangkok)

## Gate status

- Managed backups: **HOLD / unavailable** — the Supabase organization is on the Free plan; scheduled managed backups are unavailable on this plan.
- Manual logical backup: **PASS** — read-only export completed through the Supabase Session Pooler. Backup artifacts and SHA-256 inventory are stored in a private FileVault-protected location outside Git.
- Isolated restore: **PASS for the tested database and Storage scope**, with the version and project-configuration limits below.
- Independent review: **HOLD / pending final review** — the first review attempt could not locate this checkout; a second review is requested with the exact workspace path.
- Production release: **HOLD**. No Production migration, migration-ledger edit, Attendance test write, merge, or deployment was performed. Owner Production Write approval has not been given.
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

## Security Migration procedure — tested in Local, not executed in Production

Target file: `supabase/migrations/20261008053722_hr_attendance_service_role_only.sql`.

Do not run `supabase db push`, replay any of the four historical migrations, or manually edit the Production migration ledger. The Supabase CLI `migration up --db-url` path was tested against a disposable Local database populated with the 14 existing Production migration-history rows and a minimal Attendance table. The temporary workdir contained only the Security Migration and fail-fast marker files for already-applied Production versions. The command applied exactly one new migration and recorded `20261008053722 | hr_attendance_service_role_only`; the ledger count increased from 14 to 15. The isolated privilege check returned INSERT denied for `anon` and `authenticated`, and allowed for `service_role`. The fail-fast markers ensure that an unexpected attempt to replay a prior migration stops the command.

For the eventual Production operation, prepare a temporary workdir containing the exact Security Migration plus fail-fast marker files named for every currently recorded Production version. Connect through the Session Pooler URL with TLS and run only `supabase migration up --db-url <Session-Pooler-URL> --workdir <single-migration-workdir>` without `--include-all` or `--linked`. Proceed only if the preflight confirms all prior versions are already recorded and the only pending file is `20261008053722_hr_attendance_service_role_only.sql`. This makes the CLI record the exact version from the filename and causes any unexpected attempt to apply an older marker to abort. The procedure has been validated only against the disposable Local database; it has **not** been run against Production.

After a reviewer pass and explicit Owner Production Write approval, verify effective grants including inherited/PUBLIC privileges, RLS enablement, policies, and RPC execution privileges through read-only catalog checks. Do not create test Attendance rows. If any verification fails, stop release and keep Direct INSERT denied.

## Independent review and Owner decision

The independent reviewer must inspect the backup/restore evidence, source migration mapping, and tested single-migration procedure. The first review attempt returned HOLD because its workspace could not locate the report or backup manifest. A second review is requested with the exact checkout and manifest paths. This report will be updated with the result before requesting Production Write approval.

**Owner approval requested:** approve the later Production release only after the independent review passes and a version-safe single-migration/ledger procedure is established. This preflight does not authorize a Production write.

## References

- [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups)
- [Supabase Backup and Restore with the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
- [Supabase Storage download objects](https://supabase.com/docs/guides/storage/management/download-objects)
- [Supabase platform-to-self-hosted restore scope](https://supabase.com/docs/guides/self-hosting/restore-from-platform)

# KMO HR — Production Preflight Evidence

Date: 2026-10-08 (Asia/Bangkok)

## Gate status

- Managed backup: **HOLD** — the project is on the Free plan; scheduled project backups are not available on this plan.
- Manual logical backup: **NOT CREATED** — a secure Production database connection URL was not available to this run. No database credential was requested in chat or reset.
- Restore test: **NOT RUN** — there is no backup artifact to restore. Recovery readiness is **NOT ESTABLISHED**.
- Storage objects: **NOT BACKED UP** — a database dump does not include the object files. They require a separate Storage export and checksum inventory.
- Production migration: **NOT APPLIED**. No Production writes, ledger edits, merges, or deployments were made.
- Local Supabase tests: existing result remains **22/22 PASS**; not repeated for this preflight.

## Backup and restore plan

Once a secure database URL is provisioned locally, use the Supabase CLI logical dump workflow documented by Supabase. Keep role, schema, data, and required Auth data artifacts in a private encrypted location outside this repository. Record UTC/local completion time and SHA-256 checksums without including records, credentials, or dump contents in this report.

Supabase database dumps do not back up Storage object files. Export those files separately using the supported Storage interface, preserving bucket/object paths and validating an object manifest and checksums. Do not report recovery readiness until both database and required object files have been restored and verified in an isolated, version-compatible environment.

The isolated restore must verify the recoverable database scope (schema, grants/roles, RLS policies, functions/triggers, application data, and required Auth records), plus the separately exported Storage objects. Provider settings, API keys, Auth provider configuration, Edge Function secrets, and other project-level settings require separate secure inventory/reprovisioning and are not implied by a database restore.

## Production migration history mapping

Read-only Production migration history was mapped to the current source by migration name:

| Production version | Production name | Current source file |
| --- | --- | --- |
| `20261006104402` | `hr_v2_foundation` | `20261006174000_hr_v2_foundation.sql` |
| `20261006104528` | `hr_v2_hardening_bootstrap` | `20261006175500_hr_v2_hardening_bootstrap.sql` |
| `20261006132912` | `hr_line_employee_portal` | `20261006201500_hr_line_employee_portal.sql` |
| `20261006134110` | `hr_line_link_invoker` | `20261006202500_hr_line_link_invoker.sql` |

The Production versions differ from source filename timestamps. The mapping above is by name only; a complete live schema diff against the migration source remains unverified because direct database access is unavailable. Do not use broad `supabase db push`, rerun the four older migrations, or alter/repair the Production migration ledger.

## Proposed single-migration procedure — not executed

After a complete backup and isolated restore pass, a reviewer pass, schema/history reconciliation, and explicit Owner release approval:

1. Reconfirm the four existing Production history names and current schema state read-only.
2. Apply only `supabase/migrations/20261008053722_hr_attendance_service_role_only.sql` through the migration-aware single-migration operation, recording the migration as `hr_attendance_service_role_only` in the normal migration history.
3. Do not run `supabase db push`, any of the four older migrations, or a ledger repair.
4. Verify grants, RLS enablement, relevant policies, and RPC execution privileges using read-only catalog checks. Do not write test Attendance rows.
5. If verification fails, stop release and retain the existing access restrictions; do not restore direct INSERT permission as a workaround.

The exact Production schema precondition is still pending a credentialed, read-only schema comparison. Therefore this procedure is a proposal, not an authorization or a declaration that the migration is ready to run.

## Independent review

The source review of PR #1 and PR #2 previously passed with notes. The requested independent review of this backup/restore evidence and migration procedure is pending. Since backup and restore artifacts do not exist, this gate cannot receive a PASS.

## Owner action required

Provision a temporary, secure local database connection method (for example, a local environment variable or Keychain entry) without posting the secret in chat. Also provide an approved path for exporting Storage objects if the database URL does not grant access to the Storage API. After those prerequisites, complete the dump, isolated restore, checksums, schema reconciliation, and independent review before requesting Production release approval.

No additional plan or backup charges have been incurred. The temporary Local Test environment remains intact pending the completed Release.

## References

- [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups)
- [Supabase Backup and Restore with the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
- [Supabase platform-to-self-hosted restore scope](https://supabase.com/docs/guides/self-hosting/restore-from-platform)

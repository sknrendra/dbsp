/* ============================================================================
   TB_M_PERMISSION -- ADMIN_SUPER_TAM FULL GRANT
   Grants SP0ROLE 'ADMIN_SUPER_TAM' (the real role 10 dbsp users hold) all 7
   flags on every TB_M_FUNCTION row. Mirrors the bootstrap superuser grant in
   supplier-portal-be/shared/migrations/db_sp_sp/041-seed-bootstrap-users-
   permissions.js, targeted at the real prod role instead of the synthetic
   dev-only 'admin'/'superadmin' rows.

   Only ADMIN_SUPER_TAM -- every other role is left with zero permissions for
   now (out of scope here).

   Idempotent: skips any (ROLE_ID, FUNCTION_ID) pair that already has a row.
   Must run after new_tables.sql (creates TB_M_PERMISSION) and
   TB_M_FUNCTION-seed.sql (populates TB_M_FUNCTION).
   ============================================================================ */

SET NOCOUNT ON;
GO

INSERT INTO dbo.TB_M_PERMISSION (
    ROLE_ID, FUNCTION_ID, VIEW_FEATURE, CREATE_FEATURE, UPDATE_FEATURE,
    DELETE_FEATURE, SEARCH_FEATURE, DOWNLOAD_FEATURE, UPLOAD_FEATURE,
    CREATED_BY, UPDATED_BY, CREATED_DATE, UPDATED_DATE
)
SELECT
    r.Id, f.id, 1, 1, 1, 1, 1, 1, 1,
    'dbsp-seed', 'dbsp-seed', GETDATE(), GETDATE()
FROM dbo.SP0ROLE r
CROSS JOIN dbo.TB_M_FUNCTION f
WHERE r.SystemName = 'ADMIN_SUPER_TAM'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.TB_M_PERMISSION p
      WHERE p.ROLE_ID = r.Id AND p.FUNCTION_ID = f.id
  );
GO

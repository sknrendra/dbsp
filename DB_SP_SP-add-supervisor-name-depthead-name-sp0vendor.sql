/* ============================================================================
   DB_SP_SP -- SP0VENDOR.supervisor_name / .depthead_name

   Companion to supplier-portal-be/shared/migrations/db_sp_sp/
   146-add-supervisor-name-depthead-name-to-sp0vendor.js (dev DB). This file
   converges prod's schema the same way DB_SP_SP-migration-candidates.sql does.

   Source: FSD Table 116 #7/#8 (Plant Code Add/Edit > Supervisor, Dept. Head),
   both typed-in names. The existing SP0VENDOR.Supervisor and .DeptHead columns
   cannot hold them: direct INFORMATION_SCHEMA.COLUMNS introspection of
   DB_SP_SP.dbo.SP0VENDOR (2026-09-02, the restored prod snapshot) shows both as
   `int NULL`, with 10 non-NULL rows out of 2503 carrying what look like
   SP0USERPORTAL.Id values. Writing a name into either fails outright --
   confirmed against the restore:

       UPDATE SP0VENDOR SET Supervisor = 'Budi Santoso' WHERE Id = 4;
       Msg 245 ... Conversion failed when converting the varchar value
       'Budi Santoso' to data type int.

   So the name gets its own column and the legacy int pair is left exactly as
   prod has it -- no re-type, no data moved off those 10 rows. There is
   deliberately no ALTER of Supervisor/DeptHead here: prod is already `int
   NULL`, which is the shape the app now expects. The matching alignment for
   dev-built DBs (where migrations 054/098 made them nvarchar(255)) lives in
   supplier-portal-be db_sp_sp/147-align-sp0vendor-supervisor-depthead-int.js.

   Length 255 matches FSD Table 116 and the MAX_LEN validators on both sides
   (identity/src/vendors/controllers/vendors.js, VendorMasterPage.tsx).

   Idempotent, safe to re-run.
   ============================================================================ */

SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'supervisor_name') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD supervisor_name nvarchar(255) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'depthead_name') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD depthead_name nvarchar(255) NULL;
END
GO

/* ============================================================================
   DB_SP_SP -- GR Data Repair Approval: 5 level-gating functions

   The 5-level GR Data Repair Approval sign-off chain (FSD §2.10.3 Tables
   204/205: SH SPLD -> DpH SPLD -> Staff FAD -> SH FAD -> DpH FAD) used to gate
   each level on a fixed SP0ROLE.SystemName hardcoded in approvalEngine.js
   (SH_TAM/DH_TAM/STAFF_FAD/SH_FAD/DH_FAD), bypassing TB_M_PERMISSION
   entirely -- an admin could never assign an arbitrary role to a level
   without a code change. These 5 rows replace that: one TB_M_FUNCTION per
   level, grantable to any role via Role Maintenance / TB_M_PERMISSION like
   any other menu.

   Not tied to an FE nav entry (supplier-portal-fe/lib/nav.ts's
   `GRDataRepairApproval` still gates the menu itself), so no
   PascalCase-no-underscore naming constraint applies here -- named to match
   the FSD level codes / JUDGED_BY_* column suffixes 1:1 for readability.

   Source: supplier-portal-be/shared/migrations/db_sp_sp/166-seed-gr-data-
   repair-approval-level-functions.js. Grants into TB_M_PERMISSION are
   deliberately NOT included here -- roles are assigned by an admin via Role
   Maintenance, not hardcoded in a migration (see project memory
   proj-gr-repair-approval-role-legacy-check).

   Idempotent: guarded per-row on Name (TB_M_FUNCTION.Name is UNIQUE). Must
   run after new_tables.sql (creates TB_M_FUNCTION).
   ============================================================================ */

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'GRDataRepairApproval_SH_SPLD')
INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES
(NEWID(), N'GRDataRepairApproval_SH_SPLD', GETDATE(), GETDATE());
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'GRDataRepairApproval_DPH_SPLD')
INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES
(NEWID(), N'GRDataRepairApproval_DPH_SPLD', GETDATE(), GETDATE());
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'GRDataRepairApproval_STAFF_FAD')
INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES
(NEWID(), N'GRDataRepairApproval_STAFF_FAD', GETDATE(), GETDATE());
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'GRDataRepairApproval_SH_FAD')
INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES
(NEWID(), N'GRDataRepairApproval_SH_FAD', GETDATE(), GETDATE());
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'GRDataRepairApproval_DPH_FAD')
INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES
(NEWID(), N'GRDataRepairApproval_DPH_FAD', GETDATE(), GETDATE());
GO

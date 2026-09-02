/* ============================================================================
   DB_SP_INF -- NEW TABLES

   Third companion to new_tables.sql (DB_SP_SP) and new_tables_pro.sql
   (DB_SP_PRO): tables this app needs on DB_SP_INF that the restored backup
   doesn't have. Same sourcing rule as new_tables_pro.sql -- straight from the
   BE's own Sequelize migrations (shared/migrations/db_sp_inf/), folding in
   every later addColumn against the same table (there are none for these two,
   checked 2026-08-30).

   Scope right now is the GR Data Repair (H02_04) half of FSD 2.10.3. Both
   tables below are PORTAL-WRITTEN, which is why they need creating at all --
   the rest of DB_SP_INF is externally populated by GT-IF and arrives with the
   restore. In particular the source row they hang off,
   TB_I_H02_04_RECV_UPD_FILE, already exists and is NOT created here.

   All statements are idempotent (guarded on OBJECT_ID / sys.indexes), safe to
   re-run. Run against DB_SP_INF specifically.

   TYPE NOTE. The source table stores its key columns as char(N) -- blank
   padded -- e.g. DEPOT_CODE char(2), PO_NO char(8), PO_ITEM_NO char(4),
   SUPPLIER_CODE char(5), SUPPLIER_INVOICE_NO char(15), RECEIV_CASE_NO
   char(8). The two staging tables below use nvarchar(N) at the same widths,
   matching the BE migrations verbatim so dbsp does not diverge from any
   environment where the migrator runs. The mismatch is safe for the SQL the
   controller issues (= comparisons pad, LIKE is unaffected), but a JS-side
   equality or Set lookup that mixes a padded value read from the source table
   with an unpadded one read from here will silently miss. Trim in the SELECT
   if that ever comes up.
   ============================================================================ */

SET NOCOUNT ON;
GO

-- Source: shared/migrations/db_sp_inf/015-create-tb-i-h02-04-recv-upd-file-history.js
-- FSD 2.10.3 Table 197. Audit trail for the H02_04 half of GR Data Repair:
-- one row per edit submission, carrying the 3 fields the edit form writes back
-- to the source table plus Remark, which per the FSD targets this history
-- table only and never the source row. No natural key -- edits accumulate per
-- source row -- so an implicit `id` PK, same pattern as
-- TB_R_ASN_REUPLOAD_HISTORY in new_tables_pro.sql.
IF OBJECT_ID('dbo.TB_I_H02_04_RECV_UPD_FILE_HISTORY', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_I_H02_04_RECV_UPD_FILE_HISTORY (
    id int IDENTITY(1,1) NOT NULL,
    SUPPLIER_INVOICE_NO nvarchar(15) NOT NULL,
    RECEIV_CASE_NO nvarchar(8) NULL,
    SUPPLIER_CODE nvarchar(5) NULL,
    REMARK nvarchar(255) NULL,
    UPDATED_BY nvarchar(50) NULL,
    UPDATED_DATE datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_I_H02_04_RECV_UPD_FILE_HISTORY PRIMARY KEY (id)
    );
END
GO

-- Feeds the correlated subquery in the Submission grid's Remark column
-- (receiving/src/gr-repair/controllers/h02-04.js search()): TOP 1 per
-- (SUPPLIER_INVOICE_NO, RECEIV_CASE_NO) ordered by UPDATED_DATE DESC.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_h02_04_recv_upd_file_history_asn_case'
      AND object_id = OBJECT_ID('dbo.TB_I_H02_04_RECV_UPD_FILE_HISTORY')
)
BEGIN
    CREATE INDEX idx_h02_04_recv_upd_file_history_asn_case
        ON dbo.TB_I_H02_04_RECV_UPD_FILE_HISTORY (SUPPLIER_INVOICE_NO, RECEIV_CASE_NO);
END
GO

-- Source: shared/migrations/db_sp_inf/016-create-tb-i-h02-04-recv-upd-file-approval.js
-- FSD 2.10.3 Table 204. The real target for an H02_04 edit: the submission
-- stages here and only reaches TB_I_H02_04_RECV_UPD_FILE once the whole
-- 5-level sign-off chain clears (SH SPLD -> DpH SPLD -> Staff FAD -> SH FAD ->
-- DpH FAD, each a JUDGED_BY / JUDGED_TIME pair). Same shape and same reasoning
-- as TB_R_GR_APPROVAL in new_tables_pro.sql, which covers the TB_R_GR half of
-- the same screen.
--
-- DEPOT_CODE / PO_NO / PO_ITEM_NO identify the source row and are read-only on
-- the form; ASN No and Case No cannot serve as the key because the edit itself
-- may change them. ApprovalFlag: NULL = pending, 'Y' = approved and promoted,
-- 'N' = rejected. It exists so the "already in the approval process" guard
-- (FSD Figure 254) can find a pending row.
IF OBJECT_ID('dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL (
    id int IDENTITY(1,1) NOT NULL,
    DEPOT_CODE nvarchar(2) NULL,
    PO_NO nvarchar(8) NULL,
    PO_ITEM_NO nvarchar(4) NULL,
    SUPPLIER_CODE nvarchar(5) NULL,
    SUPPLIER_INVOICE_NO nvarchar(15) NULL,
    RECEIV_CASE_NO nvarchar(8) NULL,
    JUDGED_BY_SH_SPLD nvarchar(50) NULL,
    JUDGED_TIME_SH_SPLD datetimeoffset NULL,
    JUDGED_BY_DPH_SPLD nvarchar(50) NULL,
    JUDGED_TIME_DPH_SPLD datetimeoffset NULL,
    JUDGED_BY_STAFF_FAD nvarchar(50) NULL,
    JUDGED_TIME_STAFF_FAD datetimeoffset NULL,
    JUDGED_BY_SH_FAD nvarchar(50) NULL,
    JUDGED_TIME_SH_FAD datetimeoffset NULL,
    JUDGED_BY_DPH_FAD nvarchar(50) NULL,
    JUDGED_TIME_DPH_FAD datetimeoffset NULL,
    ApprovalFlag nvarchar(5) NULL,
    CREATED_BY nvarchar(50) NULL,
    CREATED_DATE datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_I_H02_04_RECV_UPD_FILE_APPROVAL PRIMARY KEY (id)
    );
END
GO

-- Serves findPendingApproval()'s resubmission guard, keyed on the read-only
-- source-row triple.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_h02_04_recv_upd_file_approval_key'
      AND object_id = OBJECT_ID('dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL')
)
BEGIN
    CREATE INDEX idx_h02_04_recv_upd_file_approval_key
        ON dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL (DEPOT_CODE, PO_NO, PO_ITEM_NO);
END
GO

-- Serves the Approval screen's pending queue (searchPending: ApprovalFlag IS
-- NULL) and the Inquiry screen's status split.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_h02_04_recv_upd_file_approval_flag'
      AND object_id = OBJECT_ID('dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL')
)
BEGIN
    CREATE INDEX idx_h02_04_recv_upd_file_approval_flag
        ON dbo.TB_I_H02_04_RECV_UPD_FILE_APPROVAL (ApprovalFlag);
END
GO

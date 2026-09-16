/* ============================================================================
   DB_SP_SP -- GR Data Repair approval/history relocation

   TB_I_H02_04_RECV_UPD_FILE_APPROVAL / _HISTORY move here from DB_SP_INF
   (new_tables_inf.sql), and TB_R_GR_APPROVAL / _HISTORY move here from
   DB_SP_PRO (new_tables_pro.sql). Reason: writes to DB_SP_INF are not allowed
   in production (externally-owned GT-IF interface DB), and DB_SP_PRO is meant
   for staging FROM OUTSIDE (external systems into TAM), not this app's own
   internal approval workflow -- both staging pairs are portal-owned GR Data
   Repair state (FSD §2.10.3) and belong in DB_SP_SP like the rest of the
   app's own tables. The SOURCE tables (TB_I_H02_04_RECV_UPD_FILE, TB_R_GR)
   are NOT moving -- read-only from here, still owned where they were.

   Source: shared/migrations/db_sp_sp/161-164 (BE repo). Schema is an exact
   copy of the old new_tables_inf.sql / new_tables_pro.sql definitions --
   TB_R_GR_APPROVAL folds in the same 034+036+037 column history those already
   captured. See project memory proj-gr-repair-approval-db-relocation.

   Table+index creation ONLY -- no data backfill and no SequelizeMeta
   bookkeeping in this file. The old tables in DB_SP_INF/DB_SP_PRO are left in
   place; removing them from new_tables_inf.sql/new_tables_pro.sql, and from
   the live databases, is a separate, deliberately-held step.

   Idempotent (guarded on OBJECT_ID / sys.indexes), safe to re-run. Run
   against DB_SP_SP specifically.
   ============================================================================ */

SET NOCOUNT ON;
GO

-- Source: shared/migrations/db_sp_sp/161-create-tb-i-h02-04-recv-upd-file-approval.js
-- FSD 2.10.3 Table 204. The real target for an H02_04 edit: the submission
-- stages here and only reaches TB_I_H02_04_RECV_UPD_FILE once the whole
-- 5-level sign-off chain clears (SH SPLD -> DpH SPLD -> Staff FAD -> SH FAD ->
-- DpH FAD, each a JUDGED_BY / JUDGED_TIME pair).
--
-- DEPOT_CODE / PO_NO / PO_ITEM_NO identify the source row and are read-only on
-- the form; ASN No and Case No cannot serve as the key because the edit itself
-- may change them. ApprovalFlag: NULL = pending, 'Y' = approved and promoted,
-- 'N' = rejected.
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

-- Source: shared/migrations/db_sp_sp/162-create-tb-i-h02-04-recv-upd-file-history.js
-- FSD 2.10.3 Table 197. Audit trail for the H02_04 half of GR Data Repair:
-- one row per edit submission, carrying the 3 fields the edit form writes back
-- to the source table plus Remark, which per the FSD targets this history
-- table only and never the source row. No natural key -- implicit `id` PK.
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

-- Source: shared/migrations/db_sp_sp/163-create-tb-r-gr-approval.js, merging
-- the old 034 (base columns) + 036 (REMARK) + 037 (5-level JUDGED_BY/TIME
-- pairs) history into one create. FSD §2.10.3 GR Data Repair -- Add/Edit
-- target + approval chain for the TB_R_GR half of the screen.
IF OBJECT_ID('dbo.TB_R_GR_APPROVAL', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_GR_APPROVAL (
    id int IDENTITY(1,1) NOT NULL,
    GR_NO nvarchar(100) NOT NULL,
    RECEIVING_DATE date NULL,
    ASN_NO nvarchar(100) NULL,
    PO_NO nvarchar(100) NULL,
    IS_SEND int NULL DEFAULT 0,
    PART_SOURCE int NULL,
    SUPP_CODE nvarchar(50) NULL,
    SUPP_NAME nvarchar(255) NULL,
    SUPP_PIC nvarchar(255) NULL,
    SUPP_INV_NO nvarchar(100) NULL,
    RECEIVING_CASE_NO nvarchar(100) NULL,
    PO_PNO nvarchar(100) NULL,
    PO_DATE date NULL,
    RECEIVED_QTY int NULL,
    ADJ_DELIVERY_QTY int NULL,
    RECEIVING_COST decimal(18,3) NULL,
    ApprovalFlag nvarchar(5) NULL,
    CreatedBy nvarchar(50) NULL,
    CreatedDate datetimeoffset NOT NULL,
    REMARK nvarchar(255) NULL,
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
    CONSTRAINT PK_TB_R_GR_APPROVAL PRIMARY KEY (id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_tb_r_gr_approval_gr_no'
      AND object_id = OBJECT_ID('dbo.TB_R_GR_APPROVAL')
)
BEGIN
    CREATE INDEX idx_tb_r_gr_approval_gr_no
        ON dbo.TB_R_GR_APPROVAL (GR_NO);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_tb_r_gr_approval_approval_flag'
      AND object_id = OBJECT_ID('dbo.TB_R_GR_APPROVAL')
)
BEGIN
    CREATE INDEX idx_tb_r_gr_approval_approval_flag
        ON dbo.TB_R_GR_APPROVAL (ApprovalFlag);
END
GO

-- Source: shared/migrations/db_sp_sp/164-create-tb-r-gr-history.js
-- FSD §2.10.3 Table 198. Audit trail for TB_R_GR repairs; search grid's
-- Remark column sources from here, not from TB_R_GR_APPROVAL.
IF OBJECT_ID('dbo.TB_R_GR_HISTORY', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_GR_HISTORY (
    id int IDENTITY(1,1) NOT NULL,
    GR_NO nvarchar(100) NOT NULL,
    RECEIVING_DATE date NULL,
    ASN_NO nvarchar(100) NULL,
    PO_NO nvarchar(100) NULL,
    SUPP_CODE nvarchar(50) NULL,
    SUPP_INV_NO nvarchar(100) NULL,
    RECEIVING_CASE_NO nvarchar(100) NULL,
    PO_PNO nvarchar(100) NULL,
    PO_DATE date NULL,
    RECEIVED_QTY int NULL,
    ADJ_DELIVERY_QTY int NULL,
    PART_SOURCE int NULL,
    REMARK nvarchar(255) NULL,
    CreatedBy nvarchar(50) NULL,
    CreatedDate datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_R_GR_HISTORY PRIMARY KEY (id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'idx_tb_r_gr_history_gr_no'
      AND object_id = OBJECT_ID('dbo.TB_R_GR_HISTORY')
)
BEGIN
    CREATE INDEX idx_tb_r_gr_history_gr_no
        ON dbo.TB_R_GR_HISTORY (GR_NO);
END
GO

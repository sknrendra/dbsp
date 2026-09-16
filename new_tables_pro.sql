/* ============================================================================
   DB_SP_PRO -- NEW TABLES

   Companion to new_tables.sql, same idea, different database: tables this app
   needs on DB_SP_PRO that the restored backup doesn't have. Not covered by
   Migration Plan.xlsx (scoped entirely to DB_SP_SP -- zero DB_SP_PRO rows
   across all 3 sheets, checked 2026-08-29), so these are sourced straight
   from the BE's own Sequelize migrations (shared/migrations/db_sp_pro/),
   folding in every later addColumn against the same table.

   All statements are idempotent (guarded on OBJECT_ID), safe to re-run.
   Run against DB_SP_PRO specifically -- these table names don't collide with
   anything in new_tables.sql (DB_SP_SP), but the two are not interchangeable.
   ============================================================================ */

SET NOCOUNT ON;
GO

-- Source: shared/migrations/db_sp_pro/016-create-tb-r-asn-reupload-history.js
-- FSD §2.6.2. Audit trail for ASN Re-Upload: one row per re-transmit to GT.
IF OBJECT_ID('dbo.TB_R_ASN_REUPLOAD_HISTORY', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_ASN_REUPLOAD_HISTORY (
    id int IDENTITY(1,1) NOT NULL,
    ASN_NO nvarchar(100) NOT NULL,
    RECEIVING_CASE_NO nvarchar(100) NULL,
    SUPP_CODE nvarchar(50) NULL,
    SUPP_INV_ISSUE_DATE date NULL,
    ADJ_DELIVERY_DATE date NULL,
    DELIVERY_DATE date NULL,
    PO_PNO nvarchar(100) NULL,
    PO_QTY int NULL,
    ADJ_DELIVERY_QTY int NULL,
    REUPLOAD_DATE datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_R_ASN_REUPLOAD_HISTORY PRIMARY KEY (id)
    );
END
GO

-- Source: shared/migrations/db_sp_pro/018-create-tb-r-asn-temp.js
-- FSD §2.6.8 (page 351). Staging snapshot for ASN Data Maintenance saves.
-- Column set has no FSD field table (migration's own note) -- inferred from
-- the Data Maintenance grid, confirm with BA before relying on it long-term.
IF OBJECT_ID('dbo.TB_R_ASN_TEMP', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_ASN_TEMP (
    id int IDENTITY(1,1) NOT NULL,
    PO_NO nvarchar(50) NOT NULL,
    PO_ITEM_NO nvarchar(50) NULL,
    PO_PNO nvarchar(50) NULL,
    SUPP_CODE nvarchar(50) NULL,
    PO_DATE date NULL,
    ASN_QTY int NULL,
    CROS_DOCK nvarchar(10) NULL,
    DELIVERY_DATE date NULL,
    LATEST_DLV_DATE date NULL,
    UPDATED_BY nvarchar(255) NULL,
    LATEST_UPDATE datetimeoffset NULL,
    CONSTRAINT PK_TB_R_ASN_TEMP PRIMARY KEY (id)
    );
END
GO

-- TB_R_GR_APPROVAL / TB_R_GR_HISTORY used to be here -- relocated to DB_SP_SP
-- (writes to DB_SP_PRO are for staging from outside, not this app's own
-- approval workflow). See DB_SP_SP-add-gr-repair-approval-history.sql.

-- Source: shared/migrations/db_sp_pro/023-create-tb-r-po-ddd-n.js
-- FSD §2.13.10 DDD Performance report source; also the Approve target for
-- DDD Revise Request (FSD §1.5bbbbbb / §1.5bbbbbbbbb: "update data Revised
-- DDD ke DB_SP_PRO.dbo.TB_R_PO_DDD_N" -- majority read against one
-- DB_SP_SP-labelled fragment elsewhere in the doc that looks like drift).
IF OBJECT_ID('dbo.TB_R_PO_DDD_N', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_PO_DDD_N (
    ID bigint IDENTITY(1,1) NOT NULL,
    VENDOR nvarchar(50) NULL,
    SUPPLIER_CODE nvarchar(50) NULL,
    VERSION_DDD_PERF nvarchar(20) NULL,
    SCHEDULED_DELIVERY_DATE date NULL,
    PLAN_QTY int NULL DEFAULT 0,
    ACTUAL_DELIVERY_QTY int NULL DEFAULT 0,
    CreatedDate datetimeoffset NULL DEFAULT GETDATE(),
    ModifiedDate datetimeoffset NULL,
    CONSTRAINT PK_TB_R_PO_DDD_N PRIMARY KEY (ID)
    );
END
GO

-- Source: shared/migrations/db_sp_pro/020-create-tb-r-truck-trip-trans.js
-- FSD §2.4.2 Actual Arrival Input. Id is app-generated (Sequelize model sets
-- defaultValue: DataTypes.UUIDV4, not a DB-side default) -- no DEFAULT here.
IF OBJECT_ID('dbo.TB_R_TRUCK_TRIP_TRANS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_TRUCK_TRIP_TRANS (
    Id uniqueidentifier NOT NULL,
    COMPANY_CODE nvarchar(20) NULL,
    SHIPMENT_DATE date NULL,
    ASN_NO nvarchar(50) NULL,
    DELIVERY_PLAN_DATE date NULL,
    START_TIME_SLOT nvarchar(20) NULL,
    END_TIME_SLOT nvarchar(20) NULL,
    TRUCK_POLICE_NO nvarchar(20) NULL,
    TRUCK_TYPE nvarchar(50) NULL,
    DRIVER_NAME nvarchar(100) NULL,
    DRIVER_LICENSE nvarchar(50) NULL,
    DRIVER_LICENSE_EXPIRY_DATE date NULL,
    DRIVER_LICENSE_PHOTO nvarchar(255) NULL,
    FORKLIFT_LICENSE nvarchar(50) NULL,
    FORKLIFT_LICENSE_EXPIRY_DATE date NULL,
    FORKLIFT_LICENSE_PHOTO nvarchar(255) NULL,
    FORKLIFT_GOVERN_LICENSE nvarchar(50) NULL,
    GATE_NO nvarchar(20) NULL,
    ACTUAL_ARRIVAL_DATE date NULL,
    ACTUAL_ARRIVAL_TIME nvarchar(10) NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_R_TRUCK_TRIP_TRANS PRIMARY KEY (Id)
    );
END
GO

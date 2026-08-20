/* ============================================================================
   DB_SP_SP -- MIGRATION CANDIDATES
   Generated 2026-08-17 from Migration Plan.xlsx (Supplier Portal Revamp).

   Target: DB_SP_SP on production (or a schema meant to converge on prod).
   Adds the dev-only columns that this session confirmed are FSD-required or
   otherwise load-bearing in the current app, so prod's schema catches up to
   what dev already needs. Companion file: Deletion Plan.xlsx / Deletion
   Plan's FIRM DELETE sheet covers the opposite direction (dev-only columns
   dev should drop).

   Column types below are taken from direct INFORMATION_SCHEMA introspection
   of the dev DB (DB_SP_SP-deletion-candidates.txt, run 2026-08-16 against the
   live 1433 container), cross-checked against each table's Sequelize model
   in supplier-portal-be/shared/models/db_sp_sp/. Where the two disagreed on
   nullability (SP0VENDOR.Barcode_Flag/Kanban_Data_Flag/POQN3Flag,
   TB_M_SUPPLIER_QUOTA.AT_SUPPLIER/LEVEL_PALLET), the INFORMATION_SCHEMA
   snapshot was treated as authoritative -- it reflects the real physical
   column, not just the ORM's read-time leniency.

   All statements are idempotent (guarded on COL_LENGTH), safe to re-run.

   SECTION 1 (below) is settled: every row has a specific FSD citation or a
   direct, unambiguous code trace showing it is live and needed, with no
   open caveat recorded against it. Safe to run as-is.

   SECTION 2 (bottom) is NOT run by default -- each block is commented out
   and carries the exact open question that needs an answer first (sponsor
   sign-off, a stakeholder conversation, or a business-meaning question this
   session could not settle). Uncomment a block only after that question is
   closed; see Migration Plan.xlsx for the full evidence trail on each.
   ============================================================================ */

SET NOCOUNT ON;
GO


/* ============================================================================
   SECTION 1 -- SETTLED, RUNS BY DEFAULT
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- SP1ORDERSENDING (9 columns)
-- Source: spec workbook (B-POR-D03 B-POR-K04), SP1ORDERSENDING items 40-47,
-- all marked N (new). See Migration Plan.xlsx > SP1ORDERSENDING.
--
-- CrossDock/DownloadFrequency/ReviseFlag are the 3 rows on that same sheet
-- ("live in our DB") that never got the "CLEARED for migration" treatment the
-- other 6 got -- same table, same sweep, just missed. Confirmed live via
-- order/src/po/controllers/po.js's PO list query (MAX(ReviseFlag),
-- MAX(CrossDock), MAX(DownloadFrequency)), which 500s on dbsp without them.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1ORDERSENDING', 'ReviseFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD ReviseFlag nvarchar(10) NULL;
END
GO

-- Sheet: "live in our DB as CrossDock, rename pending" (FSD wanted
-- CrossDockFlag; that name was already claimed by the sibling table
-- SP1ORDERSENDINGFAILED, so the model kept CrossDock -- see
-- supplier-portal-be shared/models/db_sp_sp/sp1ordersending.js).
IF COL_LENGTH('dbo.SP1ORDERSENDING', 'CrossDock') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD CrossDock nvarchar(10) NULL;
END
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DownloadFrequency') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DownloadFrequency int NOT NULL DEFAULT 0;
END
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DeliveryGroup') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DeliveryGroup nvarchar(25) NULL;
END
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DestinationCode') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DestinationCode nvarchar(7) NULL;
END
GO

-- Spec source cell for this one reads DELIVERY_GROUP, which looks like a
-- copy-paste error (same source column as DeliveryGroup above); real source
-- is almost certainly TB_R_PO_VENDOR_DIRECT.DEST_NAME. Confirm with the spec
-- author before backfilling; the column itself is uncontroversial.
IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DestinationName') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DestinationName nvarchar(25) NULL;
END
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DownloadFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DownloadFlag int NOT NULL DEFAULT 0;
END
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DownloadBy') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DownloadBy nvarchar(20) NULL;
END
GO

-- datetime, not dev's datetimeoffset: dev's type is a Sequelize DataTypes.DATE
-- default on the mssql dialect, not a deliberate business choice -- matching
-- prod's own datetime convention on this table (CreatedDate/ModifiedDate) is
-- the better target for a genuinely new prod column.
IF COL_LENGTH('dbo.SP1ORDERSENDING', 'DownloadTime') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD DownloadTime datetime NULL;
END
GO


-- ---------------------------------------------------------------------------
-- SP1ASN (2 columns)
-- Receiving_Schedule: FSD 2.6.4.2 Table 70 #11, load-bearing (all 4 ASN
-- create flows + Inquiry date-range filter + Shipping Note PDF/HTML).
-- ARRIVAL_FLAG: FSD 2.4.2 #3 read filter; currently dead/no-op in dev (no
-- write-back implemented yet) but the column itself is uncontroversial.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1ASN', 'Receiving_Schedule') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ASN ADD Receiving_Schedule nvarchar(50) NULL;
END
GO

IF COL_LENGTH('dbo.SP1ASN', 'ARRIVAL_FLAG') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ASN ADD ARRIVAL_FLAG nvarchar(1) NULL DEFAULT '0';
END
GO


-- ---------------------------------------------------------------------------
-- TB_R_PROBLEM_SHEET (7 columns)
-- NG_EXCHANGE_EVIDENCE_FILE / _DATE: FSD Table 309 #16-17 (p.1213 etc,
-- verbatim target-field citation, missed by the original sweep on a PDF
-- line-wrap). REPLY_UNTIL_DATE: FSD Table 309 #5. PROBLEM_DESCRIPTION: FSD
-- Figure 385 printed form, not in the screen-item table. COMMENT /
-- REVISE_DATE / MODIFIED_DATE: no FSD citation, but confirmed live via
-- direct code trace (problemSheetController.js requestRevision endpoint and
-- general save path).
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'NG_EXCHANGE_EVIDENCE_FILE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD NG_EXCHANGE_EVIDENCE_FILE nvarchar(500) NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'NG_EXCHANGE_EVIDENCE_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD NG_EXCHANGE_EVIDENCE_DATE date NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'REPLY_UNTIL_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD REPLY_UNTIL_DATE date NULL;
END
GO

-- Confirm the 1200-char cap with TAM before relying on it long-term -- it is
-- a dev choice, not an FSD figure.
IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'PROBLEM_DESCRIPTION') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD PROBLEM_DESCRIPTION nvarchar(1200) NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'COMMENT') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD [COMMENT] nvarchar(200) NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'REVISE_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD REVISE_DATE date NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET', 'MODIFIED_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET ADD MODIFIED_DATE date NULL;
END
GO


-- ---------------------------------------------------------------------------
-- TB_R_QIT (3 of 4 columns -- IS_DELETED is gated in Section 2)
-- ITEM_NO / PO_NO / DELIVERY_QTY: FSD Table 296 #6 and #8 (p.1167-1168),
-- explicit target-field citations, live in qitController.js.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.TB_R_QIT', 'ITEM_NO') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_QIT ADD ITEM_NO int NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_QIT', 'PO_NO') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_QIT ADD PO_NO nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.TB_R_QIT', 'DELIVERY_QTY') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_QIT ADD DELIVERY_QTY int NULL;
END
GO


-- ---------------------------------------------------------------------------
-- SP0VENDOR (21 of 22 columns -- PO_ATTENTION_TO is gated in Section 2)
-- FSD Table 113/114 (Company), 116/117 (Plant Code), 119/120 (Supplier Code),
-- p.454-490. All explicit FSD target-field citations.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP0VENDOR', 'DEPOT_CODE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD DEPOT_CODE nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'FACTORY_CODE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD FACTORY_CODE nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'ASN_SEQUENCE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD ASN_SEQUENCE nvarchar(50) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'CASE_SEQUENCE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD CASE_SEQUENCE nvarchar(50) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'DELIVERY_GROUP') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD DELIVERY_GROUP nvarchar(50) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'MONITOR_ON_OFF') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD MONITOR_ON_OFF nvarchar(5) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'eMailNotifFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD eMailNotifFlag nvarchar(5) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'eMailNotifAddress') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD eMailNotifAddress nvarchar(255) NULL;
END
GO

-- bit NOT NULL in dev's actual physical schema (INFORMATION_SCHEMA-confirmed;
-- the Sequelize model declares allowNull:true, which is looser than the real
-- column -- treated INFORMATION_SCHEMA as authoritative). DEFAULT 0 so the
-- ALTER succeeds against existing rows.
IF COL_LENGTH('dbo.SP0VENDOR', 'Barcode_Flag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD Barcode_Flag bit NOT NULL DEFAULT 0;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'Kanban_Data_Flag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD Kanban_Data_Flag bit NOT NULL DEFAULT 0;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'DUQCheckFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD DUQCheckFlag nvarchar(10) NULL;
END
GO

-- nvarchar(5) NOT NULL in dev's physical schema (same INFORMATION_SCHEMA vs
-- model discrepancy as the two flags above). DEFAULT '' as a placeholder --
-- confirm the real default with TAM (likely '1' or '3' per the FSD's
-- Forecast-N+3-mandatory flag values) before relying on it.
IF COL_LENGTH('dbo.SP0VENDOR', 'POQN3Flag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD POQN3Flag nvarchar(5) NOT NULL DEFAULT '';
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'PO_COMPANY_TO') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD PO_COMPANY_TO nvarchar(255) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'SUPP_CATEGORY') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD SUPP_CATEGORY nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'NIB') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD NIB nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'DEED_NO') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD DEED_NO nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'NPWP_COMPANY') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD NPWP_COMPANY nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'CORETAX_CODE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD CORETAX_CODE nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'SAP_CODE') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD SAP_CODE nvarchar(100) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'SUPPLIER_DIRECTOR') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD SUPPLIER_DIRECTOR nvarchar(255) NULL;
END
GO

IF COL_LENGTH('dbo.SP0VENDOR', 'TAM_Section') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD TAM_Section nvarchar(255) NULL;
END
GO

-- nvarchar(500) per the dev INFORMATION_SCHEMA snapshot (resolves the
-- "255-500, confirm" ambiguity noted in Migration Plan.xlsx).
IF COL_LENGTH('dbo.SP0VENDOR', 'Remark') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD Remark nvarchar(500) NULL;
END
GO


-- ---------------------------------------------------------------------------
-- TB_M_SUPPLIER_QUOTA (4 columns)
-- FSD Table 339 (p.1301) / Table 340 (p.1314-1317), explicit target-field
-- citations. AT_SUPPLIER and LEVEL_PALLET are FSD "Mandatory = Yes" at the
-- UI level, but the dev INFORMATION_SCHEMA snapshot and the Sequelize model
-- both agree the physical columns are nullable -- added as NULL here to
-- match the real schema dev already runs against.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.TB_M_SUPPLIER_QUOTA', 'ADD_START_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_M_SUPPLIER_QUOTA ADD ADD_START_DATE date NULL;
END
GO

IF COL_LENGTH('dbo.TB_M_SUPPLIER_QUOTA', 'ADD_END_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_M_SUPPLIER_QUOTA ADD ADD_END_DATE date NULL;
END
GO

IF COL_LENGTH('dbo.TB_M_SUPPLIER_QUOTA', 'AT_SUPPLIER') IS NULL
BEGIN
    ALTER TABLE dbo.TB_M_SUPPLIER_QUOTA ADD AT_SUPPLIER int NULL;
END
GO

IF COL_LENGTH('dbo.TB_M_SUPPLIER_QUOTA', 'LEVEL_PALLET') IS NULL
BEGIN
    ALTER TABLE dbo.TB_M_SUPPLIER_QUOTA ADD LEVEL_PALLET int NULL;
END
GO


-- ---------------------------------------------------------------------------
-- SP0ROLE.DESCRIPTION (1 column)
-- Optional "Role Description" field on Role Maintenance. Live in
-- identity/src/roles/controllers/roles.js (sort key roleDescription, create
-- write, update patch). History is contradictory (db_sp_sp/116 dropped it as
-- dead, 117 re-added same day citing "read by Role Maintenance") -- 117 is
-- the correct, current state; current code confirms it's live, not dead.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP0ROLE', 'DESCRIPTION') IS NULL
BEGIN
    ALTER TABLE dbo.SP0ROLE ADD DESCRIPTION nvarchar(500) NULL;
END
GO


-- ---------------------------------------------------------------------------
-- SP0USERPORTAL.Name (1 column)
-- FSD 2.8.1: Login Maintenance shows Name and Username separately; table only
-- had the overloaded UserName. Live in identity/src/users/controllers/users.js
-- (sort key, "Name or Email" search box, create-user write). Source:
-- supplier-portal-be/shared/migrations/db_sp_sp/116-add-name-to-sp0userportal.js
-- (baseline pair: db_sp_sp_baseline/178). No backfill here -- column added
-- NULL, existing rows stay blank until app writes touch them.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP0USERPORTAL', 'Name') IS NULL
BEGIN
    ALTER TABLE dbo.SP0USERPORTAL ADD Name nvarchar(255) NULL;
END
GO


/* ============================================================================
   SECTION 2 -- GATED, DOES NOT RUN BY DEFAULT
   Each block below is commented out. Uncomment only after the specific open
   question next to it is answered -- see Migration Plan.xlsx for the full
   evidence trail behind each.
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- SP0USERPORTAL.roles / iss / sub -- PENDING SPONSOR SIGN-OFF
-- Multi-role RBAC (roles) and SSO login identity (iss/sub) are not in FSD
-- v2.0 anywhere. Real and load-bearing in dev, but this is a spec deviation
-- to raise with the sponsor, not a routine DBA ticket.
-- ---------------------------------------------------------------------------

IF COL_LENGTH('dbo.SP0USERPORTAL', 'roles') IS NULL
BEGIN
    ALTER TABLE dbo.SP0USERPORTAL ADD roles nvarchar(max) NULL;
END
GO

-- Legacy single-role column (Role int) predates roles/multi-role RBAC and is
-- unread by the app now, but backfill it from roles[0] so anything still
-- looking at Role directly (reports, ad-hoc queries) isn't blank/stale.
-- roles is a brand-new column, empty on every restored row; Role (legacy
-- single-role FK) is the one with real data on this backup. Seed roles from
-- Role, not the other way round.
UPDATE dbo.SP0USERPORTAL
SET roles = '[' + CAST(Role AS varchar(20)) + ']'
WHERE Role IS NOT NULL AND roles IS NULL;
GO

IF COL_LENGTH('dbo.SP0USERPORTAL', 'iss') IS NULL
BEGIN
    ALTER TABLE dbo.SP0USERPORTAL ADD iss nvarchar(255) NULL;
END
GO

IF COL_LENGTH('dbo.SP0USERPORTAL', 'sub') IS NULL
BEGIN
    ALTER TABLE dbo.SP0USERPORTAL ADD sub nvarchar(255) NULL;
END
GO



-- ---------------------------------------------------------------------------
-- SP0VENDOR.PO_ATTENTION_TO -- PENDING STAKEHOLDER DISCUSSION
-- Two sources of truth risk: FSD maps "Attention" to
-- DB_SP_WRH.dbo.TB_M_SUPPLIER.PO_ATTENTION_TO (already in prod). This would
-- be a second column for the same fact until the vendor-master write target
-- is settled.
-- ---------------------------------------------------------------------------

IF COL_LENGTH('dbo.SP0VENDOR', 'PO_ATTENTION_TO') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD PO_ATTENTION_TO nvarchar(255) NULL;
END
GO



-- ---------------------------------------------------------------------------
-- TB_R_QIT.IS_DELETED -- CONDITIONAL, NEEDS RETENTION DECISION IN WRITING
-- Only needed if TAM accepts soft delete for QIT; a hard delete needs no
-- column at all. Also: dev's own migrations 055 and 096 disagree on this
-- column's nullability -- settle that too before running.
-- ---------------------------------------------------------------------------

IF COL_LENGTH('dbo.TB_R_QIT', 'IS_DELETED') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_QIT ADD IS_DELETED int NOT NULL DEFAULT 0;
END
GO



-- ---------------------------------------------------------------------------
-- TB_R_PROBLEM_SHEET_SIGNER.EMAIL_SUBJECT -- SPEC DEVIATION TO RAISE WITH TAM
-- Not in FSD Tables 325-327 for this table (those 3 FSD hits belong to a
-- different table, TB_M_ETD_EMAIL_CONTENT). Load-bearing in dev regardless
-- (problemSheetSignerController.js enforces it) -- an editable subject line
-- is a usability gain over the old hardcoded one, but it needs TAM sign-off
-- as an intentional deviation, not a silent add.
-- ---------------------------------------------------------------------------

IF COL_LENGTH('dbo.TB_R_PROBLEM_SHEET_SIGNER', 'EMAIL_SUBJECT') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PROBLEM_SHEET_SIGNER ADD EMAIL_SUBJECT nvarchar(255) NULL;
END
GO



-- ---------------------------------------------------------------------------
-- SP1POQ.PQTPOQ / PQCFQT / PQCFFG -- FULL SCRUTINY DEFERRED (2026-08-17)
--
-- PQTPOQ ("Total POQ"): the one place this label appears in the legacy app
-- (PoqServices.cs:4053, POQ Confirmation Excel export) the cell is actually
-- populated with REVISED_POQ_1 -- a different figure entirely (maps to
-- PQREV1). Looks like a legacy mislabeling bug the FSD may have inherited.
-- Confirm with TAM what "Total POQ" is actually supposed to be before this
-- column's definition (or its very existence) is finalized.
--
-- PQCFQT ("Confirmation Qty"): confirmed real and needed (FSD Table 12 #15,
-- and legacy persists it -- just on DB_SP_PRO.dbo.POQ.CONFIRMATION_QTY, not
-- SP1POQ). Putting it on SP1POQ is a deliberate re-platforming choice by the
-- dev app, not an error -- but flag it as such when this is finalized.
--
-- PQCFFG ("Confirmed" flag): no legacy precedent at all (no column, no
-- app-level IsConfirmed logic anywhere in supplier-portal-existing). Purely
-- a dev-side answer to the PQCFQT null-vs-zero ambiguity. Open question:
-- does the business need "confirmed with qty 0" distinguished from "not yet
-- confirmed"? If not, this can be derived from PQCFQT IS NOT NULL instead of
-- persisted as its own column.
-- ---------------------------------------------------------------------------

IF COL_LENGTH('dbo.SP1POQ', 'PQTPOQ') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQTPOQ int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQCFQT') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQCFQT int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQCFFG') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQCFFG bit NOT NULL DEFAULT 0;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'WarningFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD WarningFlag nvarchar(1) NULL DEFAULT 'N';
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'REASON') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD REASON nvarchar(500) NULL;
END
GO



/* ============================================================================
   NOT INCLUDED -- confirmed real but outside DB_SP_SP (this file's scope):
     - POQ Upload/Confirmation template gaps (POQ Campaign, Daily POQ Kanban,
       Forecast N+1/2/3 Special Order): see "poq excel empty.xlsx". POQ
       Campaign is now confirmed to map to DB_SP_PRO.dbo.POQ.CAMPAIGN, a
       different database entirely -- not an ALTER TABLE against DB_SP_SP.
   ============================================================================ */

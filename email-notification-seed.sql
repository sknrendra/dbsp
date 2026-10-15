/* ===========================================================================
   E-mail Notification — SEED DATA (combined)
   Database: DB_SP_SP
   Source migrations: shared/migrations/db_sp_sp/149, 150, 153, 154

   RUN AFTER email-notification-schema.sql.

   IDS ARE RESOLVED BY NAME, NEVER HARDCODED.
     TB_M_FUNCTION.id is a randomUUID() generated per environment, so this
     script joins on TB_M_FUNCTION.Name and SP0ROLE.SystemName throughout. Never
     copy ids between environments.

   IDEMPOTENT. Every section inserts-if-missing and updates-if-changed, so the
   script is safe to re-run. It never overwrites rows an admin created through
   Role Maintenance or the E-mail Master screen.


   TABLE ORIGINS  (verified against the live databases)
   ---------------------------------------------------------------------------
     NEW — created by this change, all in DB_SP_SP:
       TB_M_TEMPLATE_KEYS               declared {{variables}} per function
       TB_M_EMAIL_RECIPIENT             routing row = one e-mail (fan-out unit)
       TB_M_EMAIL_RECIPIENT_ADDRESS     its addresses (TO/CC/BCC), child
       TB_M_EMAIL_RECIPIENT_FUNCTION    functions it serves, child

     EXISTING in DB_SP_SP — read or written, never altered:
       TB_M_ETD_EMAIL_CONTENT   the e-mail TEMPLATE master (subject/body). See
                                the warning below: same NAME as a legacy table,
                                different DATABASE and different SHAPE.
       TB_M_FUNCTION            RBAC function catalogue. `id` is a randomUUID()
                                generated PER ENVIRONMENT -- always join by Name.
       TB_M_PERMISSION          role x function grants
       SP0ROLE                  roles; match on SystemName, not the bootstrap
                                names 'admin'/'superadmin'
       SP0USERPORTAL            portal users; supplies Email for derived
                                recipients (referenced by the app, not by this
                                script)
       TB_M_USER_PROC_ID        procurement code -> Windows id -> user; the
                                lookup behind PROC_CODE_ID (app-side)

     EXISTING in OTHER databases — referenced only in comments here, by the
     application at runtime:
       TB_R_PO_T                DB_SP_SUP   source of DEST_CODE values that
                                            DESTINATION_CD is matched against
       TB_R_ASN                 DB_SP_PRO   named in some key descriptions
       SP1ASN                   DB_SP_SP    named in some key descriptions
       TB_I_H01_25_DESTINATION  DB_SP_INF   destination master, joined for the
                                            readable name in the picker

   WARNING — TB_M_ETD_EMAIL_CONTENT EXISTS TWICE, DIFFERENTLY
     ours (DB_SP_SP)   : FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE,
                         EMAIL_TO / EMAIL_CC / EMAIL_BCC, EMAIL_SUBJECT,
                         EMAIL_MESSAGE
     legacy (DB_SP_SUP): SID, EMAIL_CODE, EMAIL_FROM, EMAIL_CC, EMAIL_SUBJECT,
                         EMAIL_MESSAGE, FUNCTION_ID
                         -- no EMAIL_TO, no EMAIL_BCC, no PLANT_CODE
     The two are NOT interchangeable. This script only ever touches the DB_SP_SP
     one. Legacy recipients live in DB_SP_SUP.TB_M_ETD_EMAIL_NOTIFICATION and its
     _EMAILADDRESS / _FUNCTION children, which this change does not read or write.


   DIFF vs THE ORIGINAL (LEGACY) TABLES
   ---------------------------------------------------------------------------
   A. EXISTING TABLES CHANGED BY THIS SCRIPT:  NONE.
      No ADD / ALTER / DROP COLUMN, no index or constraint change, on any table
      that already existed. TB_M_ETD_EMAIL_CONTENT keeps every column and keeps
      IX_ETD_EMAIL_CONTENT_KEY (FUNCTION_ID, PLANT_CODE) exactly as it was --
      that index stays CORRECT because the TEMPLATE is still one row per
      function+plant. Only RECIPIENTS became many, and they moved to a new table.
      Prove it after running:
        SELECT name, is_unique FROM sys.indexes
         WHERE object_id = OBJECT_ID(N'dbo.TB_M_ETD_EMAIL_CONTENT');

   B. THE NEW TABLES vs THE LEGACY ONES THEY MIRROR
      Legacy lives in DB_SP_SUP and is NOT touched, read or migrated by this
      script. These tables reproduce it COLUMN FOR COLUMN so a later merge with
      real legacy data is a straight mapping rather than a translation.

      legacy DB_SP_SUP.TB_M_ETD_EMAIL_NOTIFICATION  ->  new DB_SP_SP.TB_M_EMAIL_RECIPIENT
        SID uniqueidentifier          ->  SID char(36)          name KEPT, type per DB_SP_SP
        GROUP_CD varchar(20)          ->  GROUP_CD nvarchar(20)         KEPT (unused here)
        DESTINATION_CD varchar(7)     ->  DESTINATION_CD nvarchar(20)   KEPT, widened
        DEPOT_CD varchar(3)           ->  DEPOT_CD nvarchar(3)          KEPT (unused here)
        USERNAME varchar(50)          ->  USERNAME nvarchar(50)         KEPT (unused here)
        PROC_OPERATOR_ID char(2)      ->  PROC_OPERATOR_ID nvarchar(50) KEPT, widened to match
                                          DB_SP_SP.TB_M_USER_PROC_ID.PROC_CODE_ID
        EMAIL_ADDRESS varchar(MAX)    ->  EMAIL_ADDRESS nvarchar(MAX)   KEPT (see note below)
        FUNCTION_ID varchar(MAX)      ->  FUNCTION_ID nvarchar(MAX)     KEPT (see note below)
        (none)                        ->  PLANT_CODE nvarchar(50)   ADDED, legacy has no
                                                                    plant dimension
        (none)                        ->  IS_ACTIVE bit             ADDED, park a row instead
                                                                    of deleting it
        (none)                        ->  REMARK nvarchar(255)      ADDED

      legacy ..._EMAILADDRESS  ->  new TB_M_EMAIL_RECIPIENT_ADDRESS
        SID                           ->  SID char(36)
        EMAIL_NOTIFICATION_SID        ->  EMAIL_NOTIFICATION_SID char(36)   name KEPT
        EMAIL_ADDRESS varchar(MAX)    ->  EMAIL_ADDRESS nvarchar(255)       name KEPT
        (none)                        ->  KIND 'TO'|'CC'|'BCC'  ADDED. Legacy had no
                                          per-address kind: its TO came from this child and
                                          its CC from a single column on the CONTENT row.

      legacy ..._FUNCTION  ->  new TB_M_EMAIL_RECIPIENT_FUNCTION
        SID                           ->  SID char(36)
        EMAIL_NOTIFICATION_SID        ->  EMAIL_NOTIFICATION_SID char(36)   name KEPT
        FUNCTION_ID varchar(20)       ->  FUNCTION_ID char(36), a REAL FK to
                                          DB_SP_SP.TB_M_FUNCTION.id (char(36) there)

      NOTHING FROM LEGACY IS DROPPED OR RENAMED. Where the two differ:
        * TYPE, not name: legacy uses uniqueidentifier and varchar; DB_SP_SP has
          ZERO uniqueidentifier columns and stores uuids as char(36), so SID and
          the FKs follow the target database. nvarchar over varchar is a
          widening, safe in both directions for ASCII data.
        * The parent's EMAIL_ADDRESS and FUNCTION_ID are REDUNDANT with the child
          tables -- exactly as they are in legacy, which kept both after its
          2024-02-02 single-to-multi migration. This application reads and writes
          ONLY the children; the two parent columns exist for parity and stay
          NULL here. If anything ever populates them, decide which side wins
          first, or the two will disagree.
        * Legacy declares NO primary keys and NO foreign keys on this family --
          integrity was application-only. Ours adds PKs, FKs, cascading deletes
          and a UNIQUE constraint per child (legacy allowed duplicate addresses
          and duplicate function links).
        * IS_ACTIVE, PLANT_CODE, REMARK and KIND are additions with no legacy
          counterpart.

   C. TEMPLATE MASTERS: SAME NAME, DIFFERENT TABLE
      legacy DB_SP_SUP.TB_M_ETD_EMAIL_CONTENT   ours DB_SP_SP.TB_M_ETD_EMAIL_CONTENT
        SID uniqueidentifier                      ID int
        EMAIL_CODE varchar(15)                    (none)    -- we key on FUNCTION_ID + PLANT_CODE
        EMAIL_FROM varchar(100)                   (none)    -- from the MAIL_FROM env var
        FUNCTION_ID varchar(20)                   FUNCTION_ID nvarchar(50)
        (none)                                    FUNC_DESCRIPTION nvarchar(255)
        (none)                                    PLANT_CODE nvarchar(50)
        (none)                                    EMAIL_TO nvarchar(500)
        EMAIL_CC varchar(350)                     EMAIL_CC nvarchar(500)
        (none)                                    EMAIL_BCC nvarchar(500)
        EMAIL_SUBJECT varchar(100)                EMAIL_SUBJECT nvarchar(500)
        EMAIL_MESSAGE varchar(MAX)                EMAIL_MESSAGE nvarchar(MAX)
      Do not point this script at the DB_SP_SUP table: the shapes are not
      compatible, and legacy templates use [BRACKET] placeholders while ours use
      Mustache {{variables}} validated against TB_M_TEMPLATE_KEYS.

   SECTIONS
     1. TB_M_FUNCTION       EmailRecipient RBAC function          (migration 153)
     2. TB_M_PERMISSION     grants for the superadmin bucket      (migration 154)
     3. TB_M_TEMPLATE_KEYS  1191 declared variables, 88 functions (migration 149)
     4. TB_M_ETD_EMAIL_CONTENT  Body Builder template row         (migration 150)
     5. TB_M_EMAIL_RECIPIENT    intentionally EMPTY — see the note there
   =========================================================================== */

USE [DB_SP_SP];
GO

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   1. TB_M_FUNCTION  —  EXISTING TABLE, DB_SP_SP  (migration 153)
      Adds one row: the EmailRecipient function.

   Insert-if-missing. Deliberately NOT an edit to the main function seed, which
   is a delete-then-insert of the whole catalogue and would orphan every
   TB_M_PERMISSION row keyed to the ids it recreates.

   Target: EXISTING DB_SP_SP.TB_M_FUNCTION.
   The name must match `permissionKey` in supplier-portal-fe/lib/nav.ts, or the
   menu can never be granted and the sidebar drops it.
   --------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'EmailRecipient')
BEGIN
    INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt)
    VALUES (NEWID(), N'EmailRecipient', SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET());
END
GO


/* ---------------------------------------------------------------------------
   2. TB_M_PERMISSION  —  EXISTING TABLE, DB_SP_SP  (migration 154)
      Joins EXISTING DB_SP_SP.SP0ROLE. Grants EmailRecipient.

   Target: EXISTING DB_SP_SP.TB_M_PERMISSION, joined to EXISTING DB_SP_SP.SP0ROLE.
   ONLY the superadmin-bucket roles need a row. identity's introspect has a
   `roles.includes('admin')` catch-all that already grants every TB_M_FUNCTION to
   the admin bucket, so an admin grant here would be dead code.

   DOWNLOAD/UPLOAD are 0: this master has no Excel template or upload yet.

   NOTE the role names. 'admin'/'superadmin' are bootstrap names, NOT
   SP0ROLE.SystemName values — the real ones are below. If a name does not
   match, this silently grants nothing, so VERIFY with the SELECT at the end
   rather than trusting a clean run.
   THIS SECTION FIXES A REAL GAP, measured on a freshly rebuilt database.
   Migration 154 runs during `npm run migrate`, but 'Super Admin' is created
   later, by `npm run seed`. At migration time it does not exist, so that
   migration's `if (!role) continue` skips it silently and only 'System Support'
   ends up granted -- verified: 1 grant after a fresh migrate+seed, 2 after
   running this script. Every superadmin-bucket grant migration (082, 088, 154)
   shares this ordering gap, so running this AFTER the seed is corrective, not
   redundant.
   --------------------------------------------------------------------------- */
INSERT INTO dbo.TB_M_PERMISSION
    (ROLE_ID, FUNCTION_ID, VIEW_FEATURE, CREATE_FEATURE, UPDATE_FEATURE,
     DELETE_FEATURE, SEARCH_FEATURE, DOWNLOAD_FEATURE, UPLOAD_FEATURE,
     CREATED_BY, UPDATED_BY, CREATED_DATE, UPDATED_DATE)
SELECT r.id, f.id, 1, 1, 1, 1, 1, 0, 0,
       'seed', 'seed', SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET()
  FROM dbo.SP0ROLE r
 CROSS JOIN dbo.TB_M_FUNCTION f
 WHERE f.Name = N'EmailRecipient'
   AND r.SystemName IN (N'System Support', N'Super Admin')
   AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_PERMISSION p
                    WHERE p.ROLE_ID = r.id AND p.FUNCTION_ID = f.id);
GO


/* ---------------------------------------------------------------------------
   3. TB_M_TEMPLATE_KEYS  —  NEW TABLE, DB_SP_SP  (migration 149)
      Loaded via #KEYS, a session temp table (tempdb), joined to
      EXISTING DB_SP_SP.TB_M_FUNCTION by Name.

   This table is a PROJECTION of shared/email/mapperRegistry.js. The values
   below were GENERATED from that registry, so do not hand-edit them: change the
   registry and regenerate, or the code and the table drift and the send-time
   check throws MAPPER_KEY_MISMATCH.

   Sync semantics, matching the migration exactly:
     missing key            -> INSERT
     description/sample changed -> UPDATE (and reactivate)
     key no longer declared -> IS_ACTIVE = 0, never deleted, because a saved
                               template may still reference the name and a hard
                               delete would make that row unsaveable
     keys owned by someone else -> claimed, so the retirement pass can reach them

   A function name with no TB_M_FUNCTION row is skipped silently — correct on a
   database that has not seeded that RBAC function.
   --------------------------------------------------------------------------- */
-- NOTE: sections 3, 3a, 3b and 3c are deliberately ONE BATCH with no GO between
-- them. #KEYS is a LOCAL temp table, so it lives on a single connection; a
-- pooled client (anything other than sqlcmd) would send each GO-separated batch
-- on a different connection and lose it. Do not add GO inside this block.
IF OBJECT_ID('tempdb..#KEYS') IS NOT NULL DROP TABLE #KEYS;
CREATE TABLE #KEYS (
    FUNCTION_NAME nvarchar(100) NOT NULL,
    KEY_NAME      nvarchar(100) NOT NULL,
    DESCRIPTION   nvarchar(255) NULL,
    SAMPLE_VALUE  nvarchar(255) NULL,
    ALLOW_HTML    bit           NOT NULL DEFAULT ((0))
);

INSERT INTO #KEYS (FUNCTION_NAME, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML) VALUES
  (N'BodyBuilder', N'orderType', N'Order type (always "Conversion" for this flow)', N'Conversion', 0),
  (N'BodyBuilder', N'poNo', N'PO number', N'A4303519', 0),
  (N'BodyBuilder', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'BodyBuilder', N'destCode', N'Customer / destination code', N'DST-SNT', 0),
  (N'BodyBuilder', N'destName', N'Customer / destination name', N'Dealer Sunter', 0),
  (N'BodyBuilder', N'customer', N'Destination code and name combined', N'DST-SNT Dealer Sunter', 0),
  (N'BodyBuilder', N'partNo', N'Part number', N'11110-BZ060', 0),
  (N'BodyBuilder', N'partName', N'Part name', N'Bracket, Head Lamp', 0),
  (N'BodyBuilder', N'frameNo', N'Frame number', N'MHF8W3EM4K0001234', 0),
  (N'BodyBuilder', N'supplierCode', N'Body builder / supplier code', N'AII1', 0),
  (N'BodyBuilder', N'supplierName', N'Body builder / supplier name', N'PT. AISIN INDONESIA', 0),
  (N'BodyBuilder', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'BodyBuilder', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'BodyBuilder', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PurchaseOrder', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PurchaseOrder', N'poDate', N'PO / order date', N'06-02-2026', 0),
  (N'PurchaseOrder', N'orderType', N'Order type', N'3', 0),
  (N'PurchaseOrder', N'docNo', N'Document number', N'DOC-0001', 0),
  (N'PurchaseOrder', N'partNo', N'Part number', N'312100D180', 0),
  (N'PurchaseOrder', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PurchaseOrder', N'qty', N'Ordered quantity', N'6', 0),
  (N'PurchaseOrder', N'deliveryDate', N'Kanban delivery date', N'02-10-2026', 0),
  (N'PurchaseOrder', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PurchaseOrder', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'PurchaseOrder', N'supplierName', N'Supplier name (needs a vendor lookup)', N'PT. AISIN INDONESIA', 0),
  (N'PurchaseOrder', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PurchaseOrder', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PurchaseOrder', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PurchaseOrder', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PurchaseOrderUpload', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PurchaseOrderUpload', N'poDate', N'PO / order date', N'06-02-2026', 0),
  (N'PurchaseOrderUpload', N'orderType', N'Order type', N'3', 0),
  (N'PurchaseOrderUpload', N'docNo', N'Document number', N'DOC-0001', 0),
  (N'PurchaseOrderUpload', N'partNo', N'Part number', N'312100D180', 0),
  (N'PurchaseOrderUpload', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PurchaseOrderUpload', N'qty', N'Ordered quantity', N'6', 0),
  (N'PurchaseOrderUpload', N'deliveryDate', N'Kanban delivery date', N'02-10-2026', 0),
  (N'PurchaseOrderUpload', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PurchaseOrderUpload', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'PurchaseOrderUpload', N'supplierName', N'Supplier name (needs a vendor lookup)', N'PT. AISIN INDONESIA', 0),
  (N'PurchaseOrderUpload', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PurchaseOrderUpload', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PurchaseOrderUpload', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PurchaseOrderUpload', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ASN', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'ASN', N'asnDate', N'ASN date', N'06-02-2026', 0),
  (N'ASN', N'poNumber', N'PO number', N'A4303519', 0),
  (N'ASN', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'ASN', N'partNo', N'Part number', N'312100D180', 0),
  (N'ASN', N'deliveryQty', N'Delivery quantity', N'6', 0),
  (N'ASN', N'shipmentDate', N'Shipment date', N'06-02-2026', 0),
  (N'ASN', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'ASN', N'plantCode', N'Plant code', N'SGK', 0),
  (N'ASN', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'ASN', N'supplierName', N'Supplier name (from TB_R_ASN, not SP1ASN)', N'PT. AISIN INDONESIA', 0),
  (N'ASN', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'ASN', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ASN', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ASN', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnUpload', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnUpload', N'asnDate', N'ASN date', N'06-02-2026', 0),
  (N'AsnUpload', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnUpload', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'AsnUpload', N'partNo', N'Part number', N'312100D180', 0),
  (N'AsnUpload', N'deliveryQty', N'Delivery quantity', N'6', 0),
  (N'AsnUpload', N'shipmentDate', N'Shipment date', N'06-02-2026', 0),
  (N'AsnUpload', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnUpload', N'plantCode', N'Plant code', N'SGK', 0),
  (N'AsnUpload', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'AsnUpload', N'supplierName', N'Supplier name (from TB_R_ASN, not SP1ASN)', N'PT. AISIN INDONESIA', 0),
  (N'AsnUpload', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'AsnUpload', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnUpload', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnUpload', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnManualInput', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnManualInput', N'asnDate', N'ASN date', N'06-02-2026', 0),
  (N'AsnManualInput', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnManualInput', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'AsnManualInput', N'partNo', N'Part number', N'312100D180', 0),
  (N'AsnManualInput', N'deliveryQty', N'Delivery quantity', N'6', 0),
  (N'AsnManualInput', N'shipmentDate', N'Shipment date', N'06-02-2026', 0),
  (N'AsnManualInput', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnManualInput', N'plantCode', N'Plant code', N'SGK', 0),
  (N'AsnManualInput', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'AsnManualInput', N'supplierName', N'Supplier name (from TB_R_ASN, not SP1ASN)', N'PT. AISIN INDONESIA', 0),
  (N'AsnManualInput', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'AsnManualInput', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnManualInput', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnManualInput', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnManualInputTamWh', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnManualInputTamWh', N'asnDate', N'ASN date', N'06-02-2026', 0),
  (N'AsnManualInputTamWh', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnManualInputTamWh', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'AsnManualInputTamWh', N'partNo', N'Part number', N'312100D180', 0),
  (N'AsnManualInputTamWh', N'deliveryQty', N'Delivery quantity', N'6', 0),
  (N'AsnManualInputTamWh', N'shipmentDate', N'Shipment date', N'06-02-2026', 0),
  (N'AsnManualInputTamWh', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnManualInputTamWh', N'plantCode', N'Plant code', N'SGK', 0),
  (N'AsnManualInputTamWh', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'AsnManualInputTamWh', N'supplierName', N'Supplier name (from TB_R_ASN, not SP1ASN)', N'PT. AISIN INDONESIA', 0),
  (N'AsnManualInputTamWh', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'AsnManualInputTamWh', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnManualInputTamWh', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnManualInputTamWh', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnPoSheet', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnPoSheet', N'asnDate', N'ASN date', N'06-02-2026', 0),
  (N'AsnPoSheet', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnPoSheet', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'AsnPoSheet', N'partNo', N'Part number', N'312100D180', 0),
  (N'AsnPoSheet', N'deliveryQty', N'Delivery quantity', N'6', 0),
  (N'AsnPoSheet', N'shipmentDate', N'Shipment date', N'06-02-2026', 0),
  (N'AsnPoSheet', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnPoSheet', N'plantCode', N'Plant code', N'SGK', 0),
  (N'AsnPoSheet', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'AsnPoSheet', N'supplierName', N'Supplier name (from TB_R_ASN, not SP1ASN)', N'PT. AISIN INDONESIA', 0),
  (N'AsnPoSheet', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'AsnPoSheet', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnPoSheet', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnPoSheet', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnDataMaintenance', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnDataMaintenance', N'poItemNo', N'PO item number', N'1', 0),
  (N'AsnDataMaintenance', N'partNo', N'PO part number', N'312100D180', 0),
  (N'AsnDataMaintenance', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'AsnDataMaintenance', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'AsnDataMaintenance', N'poQty', N'PO quantity', N'100', 0),
  (N'AsnDataMaintenance', N'asnQty', N'ASN quantity', N'60', 0),
  (N'AsnDataMaintenance', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'AsnDataMaintenance', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnDataMaintenance', N'latestDlvDate', N'Latest delivery date', N'10-02-2026', 0),
  (N'AsnDataMaintenance', N'crossDock', N'Cross dock flag', N'Y', 0),
  (N'AsnDataMaintenance', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'AsnDataMaintenance', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'AsnDataMaintenance', N'updatedBy', N'Updated by', N'admin.tam', 0),
  (N'AsnDataMaintenance', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnDataMaintenance', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnDataMaintenance', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnReupload', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnReupload', N'caseNo', N'Receiving case number', N'CASE-0001', 0),
  (N'AsnReupload', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'AsnReupload', N'poPartNo', N'PO part number', N'312100D180', 0),
  (N'AsnReupload', N'poQty', N'PO quantity', N'100', 0),
  (N'AsnReupload', N'adjQty', N'Adjusted delivery quantity', N'98', 0),
  (N'AsnReupload', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnReupload', N'adjDeliveryDate', N'Adjusted delivery date', N'09-02-2026', 0),
  (N'AsnReupload', N'invoiceDate', N'Supplier invoice issue date', N'06-02-2026', 0),
  (N'AsnReupload', N'reuploadDate', N'Re-upload date', N'10-02-2026', 0),
  (N'AsnReupload', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnReupload', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnReupload', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnTire', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'AsnTire', N'poNumber', N'PO number', N'A4303519', 0),
  (N'AsnTire', N'depotCode', N'Depot code', N'DPT-01', 0),
  (N'AsnTire', N'partNo', N'PO part number', N'90919-01253', 0),
  (N'AsnTire', N'partName', N'Part name', N'PLUG, SPARK', 0),
  (N'AsnTire', N'poQty', N'PO quantity', N'100', 0),
  (N'AsnTire', N'adjQty', N'Adjusted delivery quantity', N'98', 0),
  (N'AsnTire', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'AsnTire', N'invoiceNo', N'Supplier invoice number', N'INV-0001', 0),
  (N'AsnTire', N'invoiceDate', N'Supplier invoice issue date', N'06-02-2026', 0),
  (N'AsnTire', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'AsnTire', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'AsnTire', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'AsnTire', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnTire', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnTire', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'QIT', N'qitNumber', N'QIT code', N'QIT-0001', 0),
  (N'QIT', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'QIT', N'problemCategory', N'Problem category', N'Wrong Part', 0),
  (N'QIT', N'problemQty', N'Problem quantity', N'3', 0),
  (N'QIT', N'poNumber', N'PO number', N'A4303519', 0),
  (N'QIT', N'partNo', N'Part number (ASN side)', N'312100D180', 0),
  (N'QIT', N'partName', N'Part name (from the ASN join)', N'COVER ASSY, CLUTCH', 0),
  (N'QIT', N'status', N'QIT status', N'Registered', 0),
  (N'QIT', N'createdDate', N'Created date', N'06-02-2026', 0),
  (N'QIT', N'deliveryDate', N'Delivery date (from the ASN join)', N'08-02-2026', 0),
  (N'QIT', N'supplierCode', N'Supplier code (from the ASN join)', N'AII1', 0),
  (N'QIT', N'supplierName', N'Supplier name (from the ASN join)', N'PT. AISIN INDONESIA', 0),
  (N'QIT', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'QIT', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'QIT', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'QIT', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'QitConfirmation', N'qitNumber', N'QIT code', N'QIT-0001', 0),
  (N'QitConfirmation', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'QitConfirmation', N'problemCategory', N'Problem category', N'Wrong Part', 0),
  (N'QitConfirmation', N'problemQty', N'Problem quantity', N'3', 0),
  (N'QitConfirmation', N'poNumber', N'PO number', N'A4303519', 0),
  (N'QitConfirmation', N'partNo', N'Part number (ASN side)', N'312100D180', 0),
  (N'QitConfirmation', N'partName', N'Part name (from the ASN join)', N'COVER ASSY, CLUTCH', 0),
  (N'QitConfirmation', N'status', N'QIT status', N'Registered', 0),
  (N'QitConfirmation', N'createdDate', N'Created date', N'06-02-2026', 0),
  (N'QitConfirmation', N'deliveryDate', N'Delivery date (from the ASN join)', N'08-02-2026', 0),
  (N'QitConfirmation', N'supplierCode', N'Supplier code (from the ASN join)', N'AII1', 0),
  (N'QitConfirmation', N'supplierName', N'Supplier name (from the ASN join)', N'PT. AISIN INDONESIA', 0),
  (N'QitConfirmation', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'QitConfirmation', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'QitConfirmation', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'QitConfirmation', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'Ticketing', N'ticketId', N'Ticket number', N'TKT-0001', 0),
  (N'Ticketing', N'category', N'Ticket category', N'Delivery', 0),
  (N'Ticketing', N'question', N'Supplier question', N'When is the PO released?', 0),
  (N'Ticketing', N'answer', N'TAM answer', N'Released on 06-02.', 0),
  (N'Ticketing', N'status', N'Ticket status (Outstanding / Answered)', N'Answered', 0),
  (N'Ticketing', N'submitDate', N'Submitted date', N'06-02-2026', 0),
  (N'Ticketing', N'leadTime', N'Days between submit and answer', N'2', 0),
  (N'Ticketing', N'companyGroup', N'Company group', N'SGC', 0),
  (N'Ticketing', N'plantCode', N'Plant code', N'SGK', 0),
  (N'Ticketing', N'poNumber', N'Related PO number', N'A4303519', 0),
  (N'Ticketing', N'partNo', N'Related part number', N'312100D180', 0),
  (N'Ticketing', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'Ticketing', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'Ticketing', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TicketInbox', N'ticketId', N'Ticket number', N'TKT-0001', 0),
  (N'TicketInbox', N'category', N'Ticket category', N'Delivery', 0),
  (N'TicketInbox', N'question', N'Supplier question', N'When is the PO released?', 0),
  (N'TicketInbox', N'answer', N'TAM answer', N'Released on 06-02.', 0),
  (N'TicketInbox', N'status', N'Ticket status (Outstanding / Answered)', N'Answered', 0),
  (N'TicketInbox', N'submitDate', N'Submitted date', N'06-02-2026', 0),
  (N'TicketInbox', N'leadTime', N'Days between submit and answer', N'2', 0),
  (N'TicketInbox', N'companyGroup', N'Company group', N'SGC', 0),
  (N'TicketInbox', N'plantCode', N'Plant code', N'SGK', 0),
  (N'TicketInbox', N'poNumber', N'Related PO number', N'A4303519', 0),
  (N'TicketInbox', N'partNo', N'Related part number', N'312100D180', 0),
  (N'TicketInbox', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TicketInbox', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TicketInbox', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TicketSubmit', N'ticketId', N'Ticket number', N'TKT-0001', 0),
  (N'TicketSubmit', N'category', N'Ticket category', N'Delivery', 0),
  (N'TicketSubmit', N'question', N'Supplier question', N'When is the PO released?', 0),
  (N'TicketSubmit', N'answer', N'TAM answer', N'Released on 06-02.', 0),
  (N'TicketSubmit', N'status', N'Ticket status (Outstanding / Answered)', N'Answered', 0),
  (N'TicketSubmit', N'submitDate', N'Submitted date', N'06-02-2026', 0),
  (N'TicketSubmit', N'leadTime', N'Days between submit and answer', N'2', 0),
  (N'TicketSubmit', N'companyGroup', N'Company group', N'SGC', 0),
  (N'TicketSubmit', N'plantCode', N'Plant code', N'SGK', 0),
  (N'TicketSubmit', N'poNumber', N'Related PO number', N'A4303519', 0),
  (N'TicketSubmit', N'partNo', N'Related part number', N'312100D180', 0),
  (N'TicketSubmit', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TicketSubmit', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TicketSubmit', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TruckDockBooking', N'deliveryDate', N'Delivery plan date', N'08-02-2026', 0),
  (N'TruckDockBooking', N'slot', N'Date plus booked time slot', N'08-02-2026 08:00-09:00', 0),
  (N'TruckDockBooking', N'timeSlot', N'Time slot', N'08:00-09:00', 0),
  (N'TruckDockBooking', N'gateNo', N'Gate number', N'G-02', 0),
  (N'TruckDockBooking', N'truckNo', N'Truck police number', N'B 1234 ABC', 0),
  (N'TruckDockBooking', N'truckType', N'Truck type', N'CDD', 0),
  (N'TruckDockBooking', N'driverName', N'Driver name', N'Budi Santoso', 0),
  (N'TruckDockBooking', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'TruckDockBooking', N'supplierCode', N'Booking company / supplier code', N'AII1', 0),
  (N'TruckDockBooking', N'status', N'Booking availability flag', N'Filled', 0),
  (N'TruckDockBooking', N'actualArrivalDate', N'Actual arrival date', N'08-02-2026', 0),
  (N'TruckDockBooking', N'actualArrivalTime', N'Actual arrival time', N'08:15', 0),
  (N'TruckDockBooking', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TruckDockBooking', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TruckDockBooking', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TdbActualArrival', N'deliveryDate', N'Delivery plan date', N'08-02-2026', 0),
  (N'TdbActualArrival', N'slot', N'Date plus booked time slot', N'08-02-2026 08:00-09:00', 0),
  (N'TdbActualArrival', N'timeSlot', N'Time slot', N'08:00-09:00', 0),
  (N'TdbActualArrival', N'gateNo', N'Gate number', N'G-02', 0),
  (N'TdbActualArrival', N'truckNo', N'Truck police number', N'B 1234 ABC', 0),
  (N'TdbActualArrival', N'truckType', N'Truck type', N'CDD', 0),
  (N'TdbActualArrival', N'driverName', N'Driver name', N'Budi Santoso', 0),
  (N'TdbActualArrival', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'TdbActualArrival', N'supplierCode', N'Booking company / supplier code', N'AII1', 0),
  (N'TdbActualArrival', N'status', N'Booking availability flag', N'Filled', 0),
  (N'TdbActualArrival', N'actualArrivalDate', N'Actual arrival date', N'08-02-2026', 0),
  (N'TdbActualArrival', N'actualArrivalTime', N'Actual arrival time', N'08:15', 0),
  (N'TdbActualArrival', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TdbActualArrival', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TdbActualArrival', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TireClaim', N'cnNumber', N'Credit note number', N'FCN/SP/260001', 0),
  (N'TireClaim', N'docNo', N'Tire claim document number', N'TRC-0001', 0),
  (N'TireClaim', N'claimDate', N'Claim date', N'06-02-2026', 0),
  (N'TireClaim', N'status', N'Claim status', N'Approved', 0),
  (N'TireClaim', N'dealerNote', N'Dealer note', N'Return accepted', 0),
  (N'TireClaim', N'lineCount', N'Number of claim lines', N'3', 0),
  (N'TireClaim', N'claimTotal', N'Sum of claim qty x supplier net price', N'1500000', 0),
  (N'TireClaim', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TireClaim', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TireClaim', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TireClaimFinance', N'cnNumber', N'Credit note number', N'FCN/SP/260001', 0),
  (N'TireClaimFinance', N'docNo', N'Tire claim document number', N'TRC-0001', 0),
  (N'TireClaimFinance', N'claimDate', N'Claim date', N'06-02-2026', 0),
  (N'TireClaimFinance', N'status', N'Claim status', N'Approved', 0),
  (N'TireClaimFinance', N'taxInvoice', N'Tax invoice number', N'TAX-0001', 0),
  (N'TireClaimFinance', N'supplierInvoiceNo', N'Supplier invoice number', N'INV-0001', 0),
  (N'TireClaimFinance', N'supplierInvoiceDate', N'Supplier invoice date', N'06-02-2026', 0),
  (N'TireClaimFinance', N'pbcNo', N'PBC number', N'PBC-0001', 0),
  (N'TireClaimFinance', N'lineCount', N'Number of claim lines', N'3', 0),
  (N'TireClaimFinance', N'claimTotal', N'Sum of claim qty x supplier net price', N'1500000', 0),
  (N'TireClaimFinance', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TireClaimFinance', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TireClaimFinance', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoTire', N'poNo', N'PO number', N'A4303519', 0),
  (N'PoTire', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoTire', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoTire', N'partNo', N'Part number', N'90919-01253', 0),
  (N'PoTire', N'partName', N'Part name', N'PLUG, SPARK', 0),
  (N'PoTire', N'poQty', N'PO quantity', N'100', 0),
  (N'PoTire', N'asnQty', N'ASN quantity', N'60', 0),
  (N'PoTire', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PoTire', N'cancelledQty', N'Cancelled quantity', N'0', 0),
  (N'PoTire', N'orderStatus', N'Order status', N'PO APPROVED', 0),
  (N'PoTire', N'approvedDate', N'Approved date', N'07-02-2026', 0),
  (N'PoTire', N'destCode', N'Destination code', N'DST-SNT', 0),
  (N'PoTire', N'destName', N'Destination name', N'Dealer Sunter', 0),
  (N'PoTire', N'customer', N'Destination code and name combined', N'DST-SNT Dealer Sunter', 0),
  (N'PoTire', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoTire', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'PoTire', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PoTire', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoTire', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoTire', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoTireApproved', N'poNo', N'PO number', N'A4303519', 0),
  (N'PoTireApproved', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoTireApproved', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoTireApproved', N'partNo', N'Part number', N'90919-01253', 0),
  (N'PoTireApproved', N'partName', N'Part name', N'PLUG, SPARK', 0),
  (N'PoTireApproved', N'poQty', N'PO quantity', N'100', 0),
  (N'PoTireApproved', N'asnQty', N'ASN quantity', N'60', 0),
  (N'PoTireApproved', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PoTireApproved', N'cancelledQty', N'Cancelled quantity', N'0', 0),
  (N'PoTireApproved', N'orderStatus', N'Order status', N'PO APPROVED', 0),
  (N'PoTireApproved', N'approvedDate', N'Approved date', N'07-02-2026', 0),
  (N'PoTireApproved', N'destCode', N'Destination code', N'DST-SNT', 0),
  (N'PoTireApproved', N'destName', N'Destination name', N'Dealer Sunter', 0),
  (N'PoTireApproved', N'customer', N'Destination code and name combined', N'DST-SNT Dealer Sunter', 0),
  (N'PoTireApproved', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoTireApproved', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'PoTireApproved', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PoTireApproved', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoTireApproved', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoTireApproved', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoTireCancelled', N'poNo', N'PO number', N'A4303519', 0),
  (N'PoTireCancelled', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoTireCancelled', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoTireCancelled', N'partNo', N'Part number', N'90919-01253', 0),
  (N'PoTireCancelled', N'partName', N'Part name', N'PLUG, SPARK', 0),
  (N'PoTireCancelled', N'poQty', N'PO quantity', N'100', 0),
  (N'PoTireCancelled', N'asnQty', N'ASN quantity', N'60', 0),
  (N'PoTireCancelled', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PoTireCancelled', N'cancelledQty', N'Cancelled quantity', N'0', 0),
  (N'PoTireCancelled', N'orderStatus', N'Order status', N'PO APPROVED', 0),
  (N'PoTireCancelled', N'approvedDate', N'Approved date', N'07-02-2026', 0),
  (N'PoTireCancelled', N'destCode', N'Destination code', N'DST-SNT', 0),
  (N'PoTireCancelled', N'destName', N'Destination name', N'Dealer Sunter', 0),
  (N'PoTireCancelled', N'customer', N'Destination code and name combined', N'DST-SNT Dealer Sunter', 0),
  (N'PoTireCancelled', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoTireCancelled', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'PoTireCancelled', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PoTireCancelled', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoTireCancelled', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoTireCancelled', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoTireRejected', N'poNo', N'PO number', N'A4303519', 0),
  (N'PoTireRejected', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoTireRejected', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoTireRejected', N'partNo', N'Part number', N'90919-01253', 0),
  (N'PoTireRejected', N'partName', N'Part name', N'PLUG, SPARK', 0),
  (N'PoTireRejected', N'poQty', N'PO quantity', N'100', 0),
  (N'PoTireRejected', N'asnQty', N'ASN quantity', N'60', 0),
  (N'PoTireRejected', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PoTireRejected', N'cancelledQty', N'Cancelled quantity', N'0', 0),
  (N'PoTireRejected', N'orderStatus', N'Order status', N'PO APPROVED', 0),
  (N'PoTireRejected', N'approvedDate', N'Approved date', N'07-02-2026', 0),
  (N'PoTireRejected', N'destCode', N'Destination code', N'DST-SNT', 0),
  (N'PoTireRejected', N'destName', N'Destination name', N'Dealer Sunter', 0),
  (N'PoTireRejected', N'customer', N'Destination code and name combined', N'DST-SNT Dealer Sunter', 0),
  (N'PoTireRejected', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoTireRejected', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'PoTireRejected', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PoTireRejected', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoTireRejected', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoTireRejected', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PartNumberLabel', N'requestNo', N'Print request number', N'PNL-0001', 0),
  (N'PartNumberLabel', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PartNumberLabel', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PartNumberLabel', N'partNo', N'Part number', N'312100D180', 0),
  (N'PartNumberLabel', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PartNumberLabel', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PartNumberLabel', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PartNumberLabel', N'poQty', N'PO quantity', N'100', 0),
  (N'PartNumberLabel', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PartNumberLabel', N'poqPeriod', N'POQ period', N'202602', 0),
  (N'PartNumberLabel', N'printReqQty', N'Requested print quantity', N'50', 0),
  (N'PartNumberLabel', N'printReqDate', N'Print request date', N'06-02-2026', 0),
  (N'PartNumberLabel', N'pickupDate', N'Pickup date', N'08-02-2026', 0),
  (N'PartNumberLabel', N'printAppQty', N'Approved print quantity', N'50', 0),
  (N'PartNumberLabel', N'printAppDate', N'Print approval date', N'07-02-2026', 0),
  (N'PartNumberLabel', N'status', N'Print approval flag (0 = pending)', N'1', 0),
  (N'PartNumberLabel', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PartNumberLabel', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PartNumberLabel', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PnlApproval', N'requestNo', N'Print request number', N'PNL-0001', 0),
  (N'PnlApproval', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PnlApproval', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PnlApproval', N'partNo', N'Part number', N'312100D180', 0),
  (N'PnlApproval', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PnlApproval', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PnlApproval', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PnlApproval', N'poQty', N'PO quantity', N'100', 0),
  (N'PnlApproval', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PnlApproval', N'poqPeriod', N'POQ period', N'202602', 0),
  (N'PnlApproval', N'printReqQty', N'Requested print quantity', N'50', 0),
  (N'PnlApproval', N'printReqDate', N'Print request date', N'06-02-2026', 0),
  (N'PnlApproval', N'pickupDate', N'Pickup date', N'08-02-2026', 0),
  (N'PnlApproval', N'printAppQty', N'Approved print quantity', N'50', 0),
  (N'PnlApproval', N'printAppDate', N'Print approval date', N'07-02-2026', 0),
  (N'PnlApproval', N'status', N'Print approval flag (0 = pending)', N'1', 0),
  (N'PnlApproval', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PnlApproval', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PnlApproval', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PnlByPartNo', N'requestNo', N'Print request number', N'PNL-0001', 0),
  (N'PnlByPartNo', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PnlByPartNo', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PnlByPartNo', N'partNo', N'Part number', N'312100D180', 0),
  (N'PnlByPartNo', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PnlByPartNo', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PnlByPartNo', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PnlByPartNo', N'poQty', N'PO quantity', N'100', 0),
  (N'PnlByPartNo', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PnlByPartNo', N'poqPeriod', N'POQ period', N'202602', 0),
  (N'PnlByPartNo', N'printReqQty', N'Requested print quantity', N'50', 0),
  (N'PnlByPartNo', N'printReqDate', N'Print request date', N'06-02-2026', 0),
  (N'PnlByPartNo', N'pickupDate', N'Pickup date', N'08-02-2026', 0),
  (N'PnlByPartNo', N'printAppQty', N'Approved print quantity', N'50', 0),
  (N'PnlByPartNo', N'printAppDate', N'Print approval date', N'07-02-2026', 0),
  (N'PnlByPartNo', N'status', N'Print approval flag (0 = pending)', N'1', 0),
  (N'PnlByPartNo', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PnlByPartNo', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PnlByPartNo', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PnlByPoqQty', N'requestNo', N'Print request number', N'PNL-0001', 0),
  (N'PnlByPoqQty', N'plantCode', N'Plant code', N'SGK', 0),
  (N'PnlByPoqQty', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PnlByPoqQty', N'partNo', N'Part number', N'312100D180', 0),
  (N'PnlByPoqQty', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PnlByPoqQty', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PnlByPoqQty', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PnlByPoqQty', N'poQty', N'PO quantity', N'100', 0),
  (N'PnlByPoqQty', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'PnlByPoqQty', N'poqPeriod', N'POQ period', N'202602', 0),
  (N'PnlByPoqQty', N'printReqQty', N'Requested print quantity', N'50', 0),
  (N'PnlByPoqQty', N'printReqDate', N'Print request date', N'06-02-2026', 0),
  (N'PnlByPoqQty', N'pickupDate', N'Pickup date', N'08-02-2026', 0),
  (N'PnlByPoqQty', N'printAppQty', N'Approved print quantity', N'50', 0),
  (N'PnlByPoqQty', N'printAppDate', N'Print approval date', N'07-02-2026', 0),
  (N'PnlByPoqQty', N'status', N'Print approval flag (0 = pending)', N'1', 0),
  (N'PnlByPoqQty', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PnlByPoqQty', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PnlByPoqQty', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ProblemSheet', N'problemNo', N'Problem sheet number', N'PS-0001', 0),
  (N'ProblemSheet', N'qitCode', N'Source QIT code', N'QIT-0001', 0),
  (N'ProblemSheet', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'ProblemSheet', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'ProblemSheet', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'ProblemSheet', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'ProblemSheet', N'partNo', N'Part number', N'312100D180', 0),
  (N'ProblemSheet', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'ProblemSheet', N'problemCategory', N'Problem category', N'Wrong Part', 0),
  (N'ProblemSheet', N'status', N'Problem sheet status', N'Drafting', 0),
  (N'ProblemSheet', N'ngQty', N'NG quantity', N'3', 0),
  (N'ProblemSheet', N'deliveryQty', N'Delivery quantity', N'100', 0),
  (N'ProblemSheet', N'poNumber', N'PO number', N'A4303519', 0),
  (N'ProblemSheet', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'ProblemSheet', N'createdDate', N'Created date', N'06-02-2026', 0),
  (N'ProblemSheet', N'repliedDate', N'Replied date', N'09-02-2026', 0),
  (N'ProblemSheet', N'replyUntilDate', N'Reply deadline', N'12-02-2026', 0),
  (N'ProblemSheetReply', N'problemNo', N'Problem sheet number', N'PS-0001', 0),
  (N'ProblemSheetReply', N'qitCode', N'Source QIT code', N'QIT-0001', 0),
  (N'ProblemSheetReply', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'ProblemSheetReply', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'ProblemSheetReply', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'ProblemSheetReply', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'ProblemSheetReply', N'partNo', N'Part number', N'312100D180', 0),
  (N'ProblemSheetReply', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'ProblemSheetReply', N'problemCategory', N'Problem category', N'Wrong Part', 0),
  (N'ProblemSheetReply', N'status', N'Problem sheet status', N'Drafting', 0),
  (N'ProblemSheetReply', N'ngQty', N'NG quantity', N'3', 0),
  (N'ProblemSheetReply', N'deliveryQty', N'Delivery quantity', N'100', 0),
  (N'ProblemSheetReply', N'poNumber', N'PO number', N'A4303519', 0),
  (N'ProblemSheetReply', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'ProblemSheetReply', N'createdDate', N'Created date', N'06-02-2026', 0),
  (N'ProblemSheetReply', N'repliedDate', N'Replied date', N'09-02-2026', 0),
  (N'ProblemSheetReply', N'replyUntilDate', N'Reply deadline', N'12-02-2026', 0),
  (N'GRDataRepair', N'grNumber', N'GR number', N'GR-0001', 0),
  (N'GRDataRepair', N'receivingDate', N'Receiving date', N'06-02-2026', 0),
  (N'GRDataRepair', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'GRDataRepair', N'poNumber', N'PO number', N'A4303519', 0),
  (N'GRDataRepair', N'partNo', N'PO part number', N'312100D180', 0),
  (N'GRDataRepair', N'receivedQty', N'Received quantity', N'100', 0),
  (N'GRDataRepair', N'adjQty', N'Adjusted delivery quantity', N'98', 0),
  (N'GRDataRepair', N'caseNo', N'Receiving case number', N'CASE-0001', 0),
  (N'GRDataRepair', N'invoiceNo', N'Supplier invoice number', N'INV-0001', 0),
  (N'GRDataRepair', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'GRDataRepair', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'GRDataRepair', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'GRDataRepair', N'remark', N'Repair remark', N'Qty corrected', 0),
  (N'GRDataRepair', N'approvalFlag', N'Approval flag (empty = pending)', N'1', 0),
  (N'GRDataRepairApproval', N'grNumber', N'GR number', N'GR-0001', 0),
  (N'GRDataRepairApproval', N'receivingDate', N'Receiving date', N'06-02-2026', 0),
  (N'GRDataRepairApproval', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'GRDataRepairApproval', N'poNumber', N'PO number', N'A4303519', 0),
  (N'GRDataRepairApproval', N'partNo', N'PO part number', N'312100D180', 0),
  (N'GRDataRepairApproval', N'receivedQty', N'Received quantity', N'100', 0),
  (N'GRDataRepairApproval', N'adjQty', N'Adjusted delivery quantity', N'98', 0),
  (N'GRDataRepairApproval', N'caseNo', N'Receiving case number', N'CASE-0001', 0),
  (N'GRDataRepairApproval', N'invoiceNo', N'Supplier invoice number', N'INV-0001', 0),
  (N'GRDataRepairApproval', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'GRDataRepairApproval', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'GRDataRepairApproval', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'GRDataRepairApproval', N'remark', N'Repair remark', N'Qty corrected', 0),
  (N'GRDataRepairApproval', N'approvalFlag', N'Approval flag (empty = pending)', N'1', 0),
  (N'GRReportUpload', N'grNumber', N'GR number', N'GR-0001', 0),
  (N'GRReportUpload', N'receivingDate', N'Receiving date', N'06-02-2026', 0),
  (N'GRReportUpload', N'plantCode', N'Plant code', N'SGK', 0),
  (N'GRReportUpload', N'vendorGroup', N'Vendor group', N'SGC', 0),
  (N'GRReportUpload', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'GRReportUpload', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'GRReportUpload', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'GRReportUpload', N'attention', N'Attention', N'Mr. Adrian', 0),
  (N'GRReportUpload', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'GRReportUpload', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'GRReportUpload', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'GRTire', N'grNumber', N'GR number', N'GR-0001', 0),
  (N'GRTire', N'receivingDate', N'Receiving date', N'06-02-2026', 0),
  (N'GRTire', N'plantCode', N'Plant code', N'SGK', 0),
  (N'GRTire', N'poNumber', N'PO number', N'A4303519', 0),
  (N'GRTire', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'GRTire', N'partNo', N'PO part number', N'90919-01253', 0),
  (N'GRTire', N'receivedQty', N'Received quantity', N'100', 0),
  (N'GRTire', N'invoiceNo', N'Supplier invoice number', N'INV-0001', 0),
  (N'GRTire', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'GRTire', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'GRTire', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'GRTire', N'lineItemCount', N'Number of GR lines', N'12', 0),
  (N'GRTire', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'GRTire', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'GRTire', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AdditionalPallet', N'requestNo', N'Pallet request number', N'APR-0001', 0),
  (N'AdditionalPallet', N'plantCode', N'Plant code', N'SGK', 0),
  (N'AdditionalPallet', N'palletType', N'Pallet type', N'STEEL', 0),
  (N'AdditionalPallet', N'requestQty', N'Requested quantity', N'20', 0),
  (N'AdditionalPallet', N'addQuota', N'Additional quota granted', N'20', 0),
  (N'AdditionalPallet', N'addStartDate', N'Additional quota start date', N'06-02-2026', 0),
  (N'AdditionalPallet', N'addEndDate', N'Additional quota end date', N'28-02-2026', 0),
  (N'AdditionalPallet', N'requestDate', N'Request date', N'05-02-2026', 0),
  (N'AdditionalPallet', N'reasonRequest', N'Reason for the request', N'Peak season volume', 0),
  (N'AdditionalPallet', N'reasonReject', N'Reason for rejection', N'Quota exhausted', 0),
  (N'AdditionalPallet', N'status', N'Request status', N'Approved', 0),
  (N'AdditionalPallet', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AdditionalPallet', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AdditionalPallet', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'CaseNumber', N'caseNo', N'Case number', N'CASE-0001', 0),
  (N'CaseNumber', N'plantCode', N'Plant code', N'SGK', 0),
  (N'CaseNumber', N'palletizeMark', N'Palletize mark', N'PM-01', 0),
  (N'CaseNumber', N'status', N'Status (0 = generated, 1 = printed)', N'1', 0),
  (N'CaseNumber', N'createdBy', N'Created by', N'admin.tam', 0),
  (N'CaseNumber', N'createdDate', N'Created date', N'06-02-2026', 0),
  (N'CaseNumber', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'CaseNumber', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'CaseNumber', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ContainerDelivery', N'invoiceNo', N'Shipment invoice number', N'INV-0001', 0),
  (N'ContainerDelivery', N'invoiceDate', N'Invoice date', N'06-02-2026', 0),
  (N'ContainerDelivery', N'containerNo', N'Container number', N'TCLU1234567', 0),
  (N'ContainerDelivery', N'sealNo', N'Seal number', N'SL-0001', 0),
  (N'ContainerDelivery', N'shipmentStatus', N'Shipment status', N'On Ship', 0),
  (N'ContainerDelivery', N'etd', N'ETD', N'06-02-2026', 0),
  (N'ContainerDelivery', N'etaSpld', N'ETA SPLD', N'20-02-2026', 0),
  (N'ContainerDelivery', N'lines', N'Number of invoice lines', N'12', 0),
  (N'ContainerDelivery', N'shipQty', N'Shipped quantity', N'480', 0),
  (N'ContainerDelivery', N'totalCase', N'Number of cases', N'24', 0),
  (N'ContainerDelivery', N'remark', N'Remark', N'Delayed at port', 0),
  (N'ContainerDelivery', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ContainerDelivery', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ContainerDelivery', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ContainerInbox', N'invoiceNo', N'Shipment invoice number', N'INV-0001', 0),
  (N'ContainerInbox', N'invoiceDate', N'Invoice date', N'06-02-2026', 0),
  (N'ContainerInbox', N'containerNo', N'Container number', N'TCLU1234567', 0),
  (N'ContainerInbox', N'sealNo', N'Seal number', N'SL-0001', 0),
  (N'ContainerInbox', N'shipmentStatus', N'Shipment status', N'On Ship', 0),
  (N'ContainerInbox', N'etd', N'ETD', N'06-02-2026', 0),
  (N'ContainerInbox', N'etaSpld', N'ETA SPLD', N'20-02-2026', 0),
  (N'ContainerInbox', N'lines', N'Number of invoice lines', N'12', 0),
  (N'ContainerInbox', N'shipQty', N'Shipped quantity', N'480', 0),
  (N'ContainerInbox', N'totalCase', N'Number of cases', N'24', 0),
  (N'ContainerInbox', N'remark', N'Remark', N'Delayed at port', 0),
  (N'ContainerInbox', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ContainerInbox', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ContainerInbox', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ContainerInvoice', N'invoiceNo', N'Shipment invoice number', N'INV-0001', 0),
  (N'ContainerInvoice', N'invoiceDate', N'Invoice date', N'06-02-2026', 0),
  (N'ContainerInvoice', N'containerNo', N'Container number', N'TCLU1234567', 0),
  (N'ContainerInvoice', N'sealNo', N'Seal number', N'SL-0001', 0),
  (N'ContainerInvoice', N'shipmentStatus', N'Shipment status', N'On Ship', 0),
  (N'ContainerInvoice', N'etd', N'ETD', N'06-02-2026', 0),
  (N'ContainerInvoice', N'etaSpld', N'ETA SPLD', N'20-02-2026', 0),
  (N'ContainerInvoice', N'lines', N'Number of invoice lines', N'12', 0),
  (N'ContainerInvoice', N'shipQty', N'Shipped quantity', N'480', 0),
  (N'ContainerInvoice', N'totalCase', N'Number of cases', N'24', 0),
  (N'ContainerInvoice', N'remark', N'Remark', N'Delayed at port', 0),
  (N'ContainerInvoice', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ContainerInvoice', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ContainerInvoice', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'DDDRevisedRequest', N'requestNo', N'Revise request number', N'DDD-0001', 0),
  (N'DDDRevisedRequest', N'plantCode', N'Plant code', N'SGK', 0),
  (N'DDDRevisedRequest', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'DDDRevisedRequest', N'poNumber', N'PO number', N'A4303519', 0),
  (N'DDDRevisedRequest', N'partNo', N'PO part number', N'312100D180', 0),
  (N'DDDRevisedRequest', N'poQty', N'PO quantity', N'100', 0),
  (N'DDDRevisedRequest', N'asnQty', N'ASN quantity', N'60', 0),
  (N'DDDRevisedRequest', N'remainQty', N'Remaining quantity', N'40', 0),
  (N'DDDRevisedRequest', N'planDeliveryDate', N'Planned delivery date', N'08-02-2026', 0),
  (N'DDDRevisedRequest', N'reviseReqDate', N'Requested revised date', N'10-02-2026', 0),
  (N'DDDRevisedRequest', N'requestType', N'Request type', N'Supplier', 0),
  (N'DDDRevisedRequest', N'approvalFlag', N'Approval flag (empty = pending)', N'1', 0),
  (N'DDDRevisedRequest', N'remark', N'Remark', N'Production delay', 0),
  (N'DDDRevisedRequest', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'DDDRevisedRequest', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'DDDRevisedRequest', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'DirectDelivery', N'asnNumber', N'ASN number', N'ASN-0000123', 0),
  (N'DirectDelivery', N'caseNo', N'Receiving case number', N'CASE-0001', 0),
  (N'DirectDelivery', N'cpdArrivalDate', N'CPD arrival date', N'08-02-2026', 0),
  (N'DirectDelivery', N'existFlag', N'Exist flag', N'Y', 0),
  (N'DirectDelivery', N'checkedBy', N'Checked by', N'admin.tam', 0),
  (N'DirectDelivery', N'checkedDate', N'Checked date', N'08-02-2026', 0),
  (N'DirectDelivery', N'remark', N'Remark', N'Case confirmed', 0),
  (N'DirectDelivery', N'supplierCode', N'Supplier code (from the ASN)', N'AII1', 0),
  (N'DirectDelivery', N'supplierName', N'Supplier name (from the ASN)', N'PT. AISIN INDONESIA', 0),
  (N'DirectDelivery', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'DirectDelivery', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'DirectDelivery', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'DirectDelivery', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoAdm', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PoAdm', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoAdm', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoAdm', N'partNo', N'PO part number', N'312100D180', 0),
  (N'PoAdm', N'poQty', N'PO quantity', N'100', 0),
  (N'PoAdm', N'deliveryDate', N'Delivery date', N'08-02-2026', 0),
  (N'PoAdm', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoAdm', N'palletizeCode', N'Palletize code', N'PM-01', 0),
  (N'PoAdm', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoAdm', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoAdm', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PoDenso', N'deliveryNoteNo', N'Delivery note number', N'DN-0001', 0),
  (N'PoDenso', N'poNumber', N'PO number', N'A4303519', 0),
  (N'PoDenso', N'poItemNo', N'PO item number', N'1', 0),
  (N'PoDenso', N'partNo', N'PO part number', N'312100D180', 0),
  (N'PoDenso', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'PoDenso', N'poQty', N'PO quantity', N'100', 0),
  (N'PoDenso', N'poDate', N'PO date', N'06-02-2026', 0),
  (N'PoDenso', N'depotCode', N'Depot code', N'DPT-01', 0),
  (N'PoDenso', N'cycleCode', N'Cycle code', N'C1', 0),
  (N'PoDenso', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'PoDenso', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'PoDenso', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'PoDenso', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PoDenso', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PoDenso', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'POQ', N'period', N'POQ period', N'202602', 0),
  (N'POQ', N'docNo', N'Document number', N'DOC-0001', 0),
  (N'POQ', N'partNo', N'Part number', N'312100D180', 0),
  (N'POQ', N'partName', N'Part name', N'COVER ASSY, CLUTCH', 0),
  (N'POQ', N'plantCode', N'Plant code', N'SGK', 0),
  (N'POQ', N'vendorGroup', N'Vendor group', N'SGC', 0),
  (N'POQ', N'supplierCode', N'Supplier / vendor code', N'AII1', 0),
  (N'POQ', N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA', 0),
  (N'POQ', N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA', 0),
  (N'POQ', N'confirmFlag', N'Confirmation flag', N'1', 0),
  (N'POQ', N'reason', N'Reason for revision', N'Capacity limit', 0),
  (N'POQ', N'pic', N'PIC', N'Adrian', 0),
  (N'POQ', N'confirmedDate', N'Confirmed date', N'06-02-2026', 0),
  (N'POQ', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'POQ', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'POQ', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'Tire', N'partNo', N'Supplier part number', N'90919-01253', 0),
  (N'Tire', N'supplierCode', N'Supplier code', N'AII1', 0),
  (N'Tire', N'poQty', N'PO quantity', N'100', 0),
  (N'Tire', N'onHandQty', N'On-hand quantity', N'60', 0),
  (N'Tire', N'stockQty', N'Stock quantity', N'40', 0),
  (N'Tire', N'updatedBy', N'Updated by', N'admin.tam', 0),
  (N'Tire', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'Tire', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'Tire', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'Announcement', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'Announcement', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'Announcement', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'Announcement', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'Announcement', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'Announcement', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'Announcement', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'Announcement', N'recordCount', N'Number of records involved', N'128', 0),
  (N'Announcement', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'Announcement', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'Announcement', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'Announcement', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'AsnOnOffSetting', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'AsnOnOffSetting', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'AsnOnOffSetting', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'AsnOnOffSetting', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'AsnOnOffSetting', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'AsnOnOffSetting', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'AsnOnOffSetting', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'AsnOnOffSetting', N'recordCount', N'Number of records involved', N'128', 0),
  (N'AsnOnOffSetting', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'AsnOnOffSetting', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'AsnOnOffSetting', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'AsnOnOffSetting', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'BookingSchedule', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'BookingSchedule', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'BookingSchedule', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'BookingSchedule', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'BookingSchedule', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'BookingSchedule', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'BookingSchedule', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'BookingSchedule', N'recordCount', N'Number of records involved', N'128', 0),
  (N'BookingSchedule', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'BookingSchedule', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'BookingSchedule', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'BookingSchedule', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'BusinessRoute', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'BusinessRoute', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'BusinessRoute', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'BusinessRoute', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'BusinessRoute', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'BusinessRoute', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'BusinessRoute', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'BusinessRoute', N'recordCount', N'Number of records involved', N'128', 0),
  (N'BusinessRoute', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'BusinessRoute', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'BusinessRoute', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'BusinessRoute', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'CompanyList', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'CompanyList', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'CompanyList', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'CompanyList', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'CompanyList', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'CompanyList', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'CompanyList', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'CompanyList', N'recordCount', N'Number of records involved', N'128', 0),
  (N'CompanyList', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'CompanyList', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'CompanyList', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'CompanyList', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'Dashboard', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'Dashboard', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'Dashboard', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'Dashboard', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'Dashboard', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'Dashboard', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'Dashboard', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'Dashboard', N'recordCount', N'Number of records involved', N'128', 0),
  (N'Dashboard', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'Dashboard', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'Dashboard', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'Dashboard', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'DriverMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'DriverMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'DriverMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'DriverMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'DriverMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'DriverMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'DriverMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'DriverMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'DriverMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'DriverMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'DriverMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'DriverMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'EmailNotification', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'EmailNotification', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'EmailNotification', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'EmailNotification', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'EmailNotification', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'EmailNotification', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'EmailNotification', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'EmailNotification', N'recordCount', N'Number of records involved', N'128', 0),
  (N'EmailNotification', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'EmailNotification', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'EmailNotification', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'EmailNotification', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'GateMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'GateMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'GateMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'GateMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'GateMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'GateMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'GateMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'GateMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'GateMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'GateMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'GateMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'GateMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'GRDataRepairInquiry', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'GRDataRepairInquiry', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'GRDataRepairInquiry', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'GRDataRepairInquiry', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'GRDataRepairInquiry', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'GRDataRepairInquiry', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'GRDataRepairInquiry', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'GRDataRepairInquiry', N'recordCount', N'Number of records involved', N'128', 0),
  (N'GRDataRepairInquiry', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'GRDataRepairInquiry', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'GRDataRepairInquiry', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'GRDataRepairInquiry', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'GRReport', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'GRReport', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'GRReport', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'GRReport', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'GRReport', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'GRReport', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'GRReport', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'GRReport', N'recordCount', N'Number of records involved', N'128', 0),
  (N'GRReport', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'GRReport', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'GRReport', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'GRReport', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'LearningCenter', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'LearningCenter', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'LearningCenter', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'LearningCenter', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'LearningCenter', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'LearningCenter', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'LearningCenter', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'LearningCenter', N'recordCount', N'Number of records involved', N'128', 0),
  (N'LearningCenter', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'LearningCenter', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'LearningCenter', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'LearningCenter', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ModuleSettings', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ModuleSettings', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ModuleSettings', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ModuleSettings', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ModuleSettings', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ModuleSettings', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ModuleSettings', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ModuleSettings', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ModuleSettings', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ModuleSettings', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ModuleSettings', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ModuleSettings', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'MonthlyReport', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'MonthlyReport', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'MonthlyReport', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'MonthlyReport', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'MonthlyReport', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'MonthlyReport', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'MonthlyReport', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'MonthlyReport', N'recordCount', N'Number of records involved', N'128', 0),
  (N'MonthlyReport', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'MonthlyReport', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'MonthlyReport', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'MonthlyReport', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'NoteConfiguration', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'NoteConfiguration', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'NoteConfiguration', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'NoteConfiguration', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'NoteConfiguration', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'NoteConfiguration', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'NoteConfiguration', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'NoteConfiguration', N'recordCount', N'Number of records involved', N'128', 0),
  (N'NoteConfiguration', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'NoteConfiguration', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'NoteConfiguration', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'NoteConfiguration', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'PalletizeMark', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'PalletizeMark', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'PalletizeMark', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'PalletizeMark', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'PalletizeMark', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'PalletizeMark', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'PalletizeMark', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'PalletizeMark', N'recordCount', N'Number of records involved', N'128', 0),
  (N'PalletizeMark', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'PalletizeMark', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'PalletizeMark', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'PalletizeMark', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ProblemSheetEmailRoute', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ProblemSheetEmailRoute', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ProblemSheetEmailRoute', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ProblemSheetEmailRoute', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ProblemSheetEmailRoute', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ProblemSheetEmailRoute', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ProblemSheetEmailRoute', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ProblemSheetEmailRoute', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ProblemSheetEmailRoute', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ProblemSheetSigner', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ProblemSheetSigner', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ProblemSheetSigner', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ProblemSheetSigner', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ProblemSheetSigner', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ProblemSheetSigner', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ProblemSheetSigner', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ProblemSheetSigner', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ProblemSheetSigner', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ProcurementCode', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ProcurementCode', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ProcurementCode', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ProcurementCode', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ProcurementCode', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ProcurementCode', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ProcurementCode', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ProcurementCode', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ProcurementCode', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0);


INSERT INTO #KEYS (FUNCTION_NAME, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML) VALUES
  (N'ProcurementCode', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ProcurementCode', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ProcurementCode', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'QitDashboard', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'QitDashboard', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'QitDashboard', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'QitDashboard', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'QitDashboard', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'QitDashboard', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'QitDashboard', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'QitDashboard', N'recordCount', N'Number of records involved', N'128', 0),
  (N'QitDashboard', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'QitDashboard', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'QitDashboard', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'QitDashboard', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'Report', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'Report', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'Report', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'Report', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'Report', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'Report', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'Report', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'Report', N'recordCount', N'Number of records involved', N'128', 0),
  (N'Report', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'Report', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'Report', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'Report', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportDddPerformance', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportDddPerformance', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportDddPerformance', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportDddPerformance', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportDddPerformance', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportDddPerformance', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportDddPerformance', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportDddPerformance', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportDddPerformance', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportDddPerformance', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportDddPerformance', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportDddPerformance', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportGrOutstanding', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportGrOutstanding', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportGrOutstanding', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportGrOutstanding', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportGrOutstanding', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportGrOutstanding', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportGrOutstanding', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportGrOutstanding', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportGrOutstanding', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportGrOutstanding', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportGrOutstanding', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportGrOutstanding', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportMonthlySupplier', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportMonthlySupplier', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportMonthlySupplier', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportMonthlySupplier', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportMonthlySupplier', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportMonthlySupplier', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportMonthlySupplier', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportMonthlySupplier', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportMonthlySupplier', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportMonthlySupplier', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportMonthlySupplier', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportMonthlySupplier', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportMonthlyTam', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportMonthlyTam', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportMonthlyTam', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportMonthlyTam', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportMonthlyTam', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportMonthlyTam', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportMonthlyTam', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportMonthlyTam', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportMonthlyTam', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportMonthlyTam', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportMonthlyTam', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportMonthlyTam', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportOutstandingPo', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportOutstandingPo', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportOutstandingPo', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportOutstandingPo', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportOutstandingPo', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportOutstandingPo', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportOutstandingPo', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportOutstandingPo', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportOutstandingPo', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportOutstandingPo', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportOutstandingPo', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportOutstandingPo', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportPsDashboard', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportPsDashboard', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportPsDashboard', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportPsDashboard', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportPsDashboard', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportPsDashboard', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportPsDashboard', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportPsDashboard', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportPsDashboard', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportPsDashboard', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportPsDashboard', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportPsDashboard', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportSheDelivery', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportSheDelivery', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportSheDelivery', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportSheDelivery', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportSheDelivery', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportSheDelivery', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportSheDelivery', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportSheDelivery', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportSheDelivery', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportSheDelivery', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportSheDelivery', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportSheDelivery', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportStaggeredDelivery', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportStaggeredDelivery', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportStaggeredDelivery', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportStaggeredDelivery', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportStaggeredDelivery', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportStaggeredDelivery', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportStaggeredDelivery', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportStaggeredDelivery', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportStaggeredDelivery', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportStaggeredDelivery', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportStaggeredDelivery', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportStaggeredDelivery', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportWeeklySupplier', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportWeeklySupplier', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportWeeklySupplier', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportWeeklySupplier', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportWeeklySupplier', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportWeeklySupplier', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportWeeklySupplier', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportWeeklySupplier', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportWeeklySupplier', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportWeeklySupplier', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportWeeklySupplier', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportWeeklySupplier', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'ReportWeeklyTam', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'ReportWeeklyTam', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'ReportWeeklyTam', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'ReportWeeklyTam', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'ReportWeeklyTam', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'ReportWeeklyTam', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'ReportWeeklyTam', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'ReportWeeklyTam', N'recordCount', N'Number of records involved', N'128', 0),
  (N'ReportWeeklyTam', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'ReportWeeklyTam', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'ReportWeeklyTam', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'ReportWeeklyTam', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'RoleMaintenance', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'RoleMaintenance', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'RoleMaintenance', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'RoleMaintenance', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'RoleMaintenance', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'RoleMaintenance', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'RoleMaintenance', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'RoleMaintenance', N'recordCount', N'Number of records involved', N'128', 0),
  (N'RoleMaintenance', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'RoleMaintenance', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'RoleMaintenance', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'RoleMaintenance', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'SupplierUsers', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'SupplierUsers', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'SupplierUsers', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'SupplierUsers', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'SupplierUsers', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'SupplierUsers', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'SupplierUsers', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'SupplierUsers', N'recordCount', N'Number of records involved', N'128', 0),
  (N'SupplierUsers', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'SupplierUsers', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'SupplierUsers', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'SupplierUsers', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TAMCompanyMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TAMCompanyMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TAMCompanyMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TAMCompanyMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TAMCompanyMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TAMCompanyMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TAMCompanyMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TAMCompanyMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TAMCompanyMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TAMCompanyMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TAMCompanyMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TAMCompanyMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TdbInquirySupplier', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TdbInquirySupplier', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TdbInquirySupplier', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TdbInquirySupplier', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TdbInquirySupplier', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TdbInquirySupplier', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TdbInquirySupplier', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TdbInquirySupplier', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TdbInquirySupplier', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TdbInquirySupplier', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TdbInquirySupplier', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TdbInquirySupplier', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TdbInquiryTam', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TdbInquiryTam', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TdbInquiryTam', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TdbInquiryTam', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TdbInquiryTam', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TdbInquiryTam', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TdbInquiryTam', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TdbInquiryTam', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TdbInquiryTam', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TdbInquiryTam', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TdbInquiryTam', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TdbInquiryTam', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TirePoFulfillment', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TirePoFulfillment', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TirePoFulfillment', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TirePoFulfillment', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TirePoFulfillment', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TirePoFulfillment', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TirePoFulfillment', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TirePoFulfillment', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TirePoFulfillment', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TirePoFulfillment', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TirePoFulfillment', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TirePoFulfillment', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TireSalesReport', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TireSalesReport', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TireSalesReport', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TireSalesReport', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TireSalesReport', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TireSalesReport', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TireSalesReport', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TireSalesReport', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TireSalesReport', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TireSalesReport', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TireSalesReport', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TireSalesReport', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TireSupplierPerformance', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TireSupplierPerformance', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TireSupplierPerformance', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TireSupplierPerformance', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TireSupplierPerformance', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TireSupplierPerformance', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TireSupplierPerformance', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TireSupplierPerformance', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TireSupplierPerformance', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TireSupplierPerformance', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TireSupplierPerformance', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TireSupplierPerformance', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TruckMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TruckMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TruckMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TruckMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TruckMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TruckMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TruckMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TruckMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TruckMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TruckMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TruckMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TruckMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'TypeTMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'TypeTMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'TypeTMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'TypeTMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'TypeTMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'TypeTMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'TypeTMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'TypeTMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'TypeTMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'TypeTMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'TypeTMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'TypeTMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'UserManagement', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'UserManagement', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'UserManagement', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'UserManagement', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'UserManagement', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'UserManagement', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'UserManagement', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'UserManagement', N'recordCount', N'Number of records involved', N'128', 0),
  (N'UserManagement', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'UserManagement', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'UserManagement', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'UserManagement', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0),
  (N'VendorMaster', N'functionName', N'Name of the feature that raised this e-mail', N'ReportWeeklyTam', 0),
  (N'VendorMaster', N'generatedAt', N'When the e-mail was raised', N'06-02-2026 08:30', 0),
  (N'VendorMaster', N'requestedBy', N'User who triggered it', N'admin.tam@toyota.astra.co.id', 0),
  (N'VendorMaster', N'companyCode', N'Company / vendor group code, when applicable', N'SGC', 0),
  (N'VendorMaster', N'plantCode', N'Plant code, when applicable', N'SGK', 0),
  (N'VendorMaster', N'periodFrom', N'Start of the reporting period, when applicable', N'01-02-2026', 0),
  (N'VendorMaster', N'periodTo', N'End of the reporting period, when applicable', N'28-02-2026', 0),
  (N'VendorMaster', N'recordCount', N'Number of records involved', N'128', 0),
  (N'VendorMaster', N'remark', N'Free-text note supplied by the caller', N'Generated automatically', 0),
  (N'VendorMaster', N'destinationCode', N'Destination code this copy of the e-mail is routed to', N'DST-SNT', 0),
  (N'VendorMaster', N'destinationName', N'Destination name, from the destination master', N'Dealer Sunter', 0),
  (N'VendorMaster', N'recipientGroup', N'Human label for the recipient row (destination, or procurement code)', N'DST-SNT', 0);

/* -- 3a. insert keys that do not exist yet ---------------------------------- */
INSERT INTO dbo.TB_M_TEMPLATE_KEYS
    (FUNCTION_ID, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML, IS_ACTIVE,
     CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
SELECT CAST(f.id AS nvarchar(50)), k.KEY_NAME, k.DESCRIPTION, k.SAMPLE_VALUE,
       k.ALLOW_HTML, 1, 'migration', SYSDATETIMEOFFSET(), 'migration', SYSDATETIMEOFFSET()
  FROM #KEYS k
  JOIN dbo.TB_M_FUNCTION f ON f.Name = k.FUNCTION_NAME
 WHERE NOT EXISTS (SELECT 1 FROM dbo.TB_M_TEMPLATE_KEYS t
                    WHERE t.FUNCTION_ID = CAST(f.id AS nvarchar(50))
                      AND t.KEY_NAME = k.KEY_NAME);

/* -- 3b. re-sync text, reactivate, and claim ownership ---------------------- */
UPDATE t
   SET t.DESCRIPTION  = k.DESCRIPTION,
       t.SAMPLE_VALUE = k.SAMPLE_VALUE,
       t.ALLOW_HTML   = k.ALLOW_HTML,
       t.IS_ACTIVE    = 1,
       t.CREATED_BY   = 'migration',   -- claim it, so 3c can retire it later
       t.CHANGED_BY   = 'migration',
       t.CHANGED_DT   = SYSDATETIMEOFFSET()
  FROM dbo.TB_M_TEMPLATE_KEYS t
  JOIN dbo.TB_M_FUNCTION f ON CAST(f.id AS nvarchar(50)) = t.FUNCTION_ID
  JOIN #KEYS k ON k.FUNCTION_NAME = f.Name AND k.KEY_NAME = t.KEY_NAME
 WHERE ISNULL(t.DESCRIPTION, N'')  <> ISNULL(k.DESCRIPTION, N'')
    OR ISNULL(t.SAMPLE_VALUE, N'') <> ISNULL(k.SAMPLE_VALUE, N'')
    OR t.ALLOW_HTML <> k.ALLOW_HTML
    OR t.IS_ACTIVE  <> 1
    OR t.CREATED_BY <> 'migration';

/* -- 3c. retire keys the registry no longer declares ------------------------
   Only rows this sync owns. Keys an admin added by hand are left alone.       */
UPDATE t
   SET t.IS_ACTIVE  = 0,
       t.CHANGED_BY = 'migration',
       t.CHANGED_DT = SYSDATETIMEOFFSET()
  FROM dbo.TB_M_TEMPLATE_KEYS t
  JOIN dbo.TB_M_FUNCTION f ON CAST(f.id AS nvarchar(50)) = t.FUNCTION_ID
 WHERE t.CREATED_BY = 'migration'
   AND t.IS_ACTIVE = 1
   AND EXISTS (SELECT 1 FROM #KEYS k WHERE k.FUNCTION_NAME = f.Name)   -- registry knows this function
   AND NOT EXISTS (SELECT 1 FROM #KEYS k
                    WHERE k.FUNCTION_NAME = f.Name AND k.KEY_NAME = t.KEY_NAME);

DROP TABLE #KEYS;
GO


/* ---------------------------------------------------------------------------
   4. TB_M_ETD_EMAIL_CONTENT  —  EXISTING TABLE, DB_SP_SP  (migration 150)
      NOT the legacy DB_SP_SUP table of the same name (see WARNING above).

   Target: EXISTING DB_SP_SP.TB_M_ETD_EMAIL_CONTENT (NOT the legacy DB_SP_SUP
   table of the same name).

   PLANT_CODE '*' is the all-plants row. It is required, not cosmetic:
   DB_SP_SUP.TB_R_PO_T
   has no plant column at all, so Body Builder cannot supply one.

   Guarded on the NATURAL KEY (function + plant) only. A whole-table "skip if any
   row exists" guard would skip this seed the moment an admin creates one
   unrelated row.

   Recipients here are the FALLBACK path, used only while the function has no
   row in TB_M_EMAIL_RECIPIENT. They are never templated.

   ONE TEMPLATE PER FUNCTION. The unique index on (FUNCTION_ID, PLANT_CODE) is
   the rule, and the UI now matches it: the E-mail Content form takes a single
   Function ID. A template may only use the variables ITS function declares, so
   one body shared across several functions could only ever offer the
   intersection of their variable sets.
   --------------------------------------------------------------------------- */

/* Body Builder template text, lifted verbatim from migration 150. */
DECLARE @EMAIL_TO      nvarchar(500) = N'';
DECLARE @EMAIL_SUBJECT nvarchar(500) = N'UNIT HAS BEEN SENT TO VLD';
DECLARE @EMAIL_MESSAGE nvarchar(MAX) = N'<p>Dengan info sebagai berikut:</p>
<table border="1" cellspacing="0" style="border-collapse:collapse">
  <tr><td style="padding:4px 10px">Tipe Order</td><td style="padding:4px 10px">{{orderType}}</td></tr>
  <tr><td style="padding:4px 10px">PO No</td><td style="padding:4px 10px">{{poNo}}</td></tr>
  <tr><td style="padding:4px 10px">Customer</td><td style="padding:4px 10px">{{customer}}</td></tr>
  <tr><td style="padding:4px 10px">Part Number</td><td style="padding:4px 10px">{{partNo}}</td></tr>
  <tr><td style="padding:4px 10px">Part Name</td><td style="padding:4px 10px">{{partName}}</td></tr>
  <tr><td style="padding:4px 10px">Frame Number</td><td style="padding:4px 10px">{{frameNo}}</td></tr>
</table>';

INSERT INTO dbo.TB_M_ETD_EMAIL_CONTENT
    (FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE, EMAIL_TO, EMAIL_CC, EMAIL_BCC,
     EMAIL_SUBJECT, EMAIL_MESSAGE, CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
SELECT f.id, N'BodyBuilder', N'*',
       @EMAIL_TO, NULL, NULL, @EMAIL_SUBJECT, @EMAIL_MESSAGE,
       'migration', SYSDATETIMEOFFSET(), 'migration', SYSDATETIMEOFFSET()
  FROM dbo.TB_M_FUNCTION f
 WHERE f.Name = N'BodyBuilder'
   AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_ETD_EMAIL_CONTENT c
                    WHERE c.FUNCTION_ID = f.id AND c.PLANT_CODE = N'*');
GO


/* ---------------------------------------------------------------------------
   5. TB_M_EMAIL_RECIPIENT  —  NEW TABLE, DB_SP_SP  — intentionally NOT seeded

   A fresh install starts with ZERO routing rows, and that is correct: with no
   rows, every function falls back to its TB_M_ETD_EMAIL_CONTENT recipients and
   sends exactly one e-mail, i.e. behaviour is unchanged from before this feature.

   Cut functions over one at a time, through the E-mail Recipient screen. The
   moment a function gets its first row here, the fallback stops applying TO THAT
   FUNCTION — and if it also opts into destination routing, a record whose
   destination has no row sends NOTHING (by design; the notifier logs an error
   naming the code).

   Example, kept commented — one mail per matching row:

   -- DECLARE @sid char(36) = NEWID();
   --
   -- INSERT INTO dbo.TB_M_EMAIL_RECIPIENT
   --     (SID, PLANT_CODE, DESTINATION_CD, PROC_OPERATOR_ID, IS_ACTIVE, REMARK,
   --      CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
   -- VALUES (@sid, N'*', N'DST-SNT', NULL, 1, N'Sunter logistics',
   --         'seed', SYSDATETIMEOFFSET(), 'seed', SYSDATETIMEOFFSET());
   --
   -- INSERT INTO dbo.TB_M_EMAIL_RECIPIENT_ADDRESS
   --     (EMAIL_NOTIFICATION_SID, EMAIL_ADDRESS, KIND, CREATED_BY, CREATED_DT)
   -- VALUES (@sid, N'sunter-logistics@tam.co.id', N'TO', 'seed', SYSDATETIMEOFFSET());
   --
   -- INSERT INTO dbo.TB_M_EMAIL_RECIPIENT_FUNCTION
   --     (EMAIL_NOTIFICATION_SID, FUNCTION_ID, CREATED_BY, CREATED_DT)
   -- SELECT @sid, f.id, 'seed', SYSDATETIMEOFFSET()
   --   FROM dbo.TB_M_FUNCTION f WHERE f.Name = N'BodyBuilder';
   --------------------------------------------------------------------------- */


/* ---------------------------------------------------------------------------
   VERIFY
   --------------------------------------------------------------------------- */
SELECT 'TB_M_FUNCTION EmailRecipient' AS item, COUNT(*) AS n
  FROM dbo.TB_M_FUNCTION WHERE Name = N'EmailRecipient'
UNION ALL
SELECT 'TB_M_PERMISSION grants', COUNT(*)
  FROM dbo.TB_M_PERMISSION p JOIN dbo.TB_M_FUNCTION f ON f.id = p.FUNCTION_ID
 WHERE f.Name = N'EmailRecipient'
UNION ALL
SELECT 'TEMPLATE_KEYS active (migration-owned)', COUNT(*)
  FROM dbo.TB_M_TEMPLATE_KEYS WHERE CREATED_BY = 'migration' AND IS_ACTIVE = 1
UNION ALL
SELECT 'TEMPLATE_KEYS distinct functions', COUNT(DISTINCT FUNCTION_ID)
  FROM dbo.TB_M_TEMPLATE_KEYS WHERE CREATED_BY = 'migration' AND IS_ACTIVE = 1
UNION ALL
SELECT 'ETD_EMAIL_CONTENT BodyBuilder', COUNT(*)
  FROM dbo.TB_M_ETD_EMAIL_CONTENT c JOIN dbo.TB_M_FUNCTION f ON f.id = c.FUNCTION_ID
 WHERE f.Name = N'BodyBuilder'
UNION ALL
SELECT 'EMAIL_RECIPIENT rows (0 expected on a fresh install)', COUNT(*)
  FROM dbo.TB_M_EMAIL_RECIPIENT;
GO

/*  MEASURED on a database rebuilt from scratch (every migration + seed, then
    this script):

      TB_M_FUNCTION EmailRecipient ............ 1
      TB_M_PERMISSION grants .................. 2   (1 before this script runs --
                                                     see the ordering gap in 2.)
      TEMPLATE_KEYS active (migration-owned) .. 1191
      TEMPLATE_KEYS distinct functions ........ 88
      ETD_EMAIL_CONTENT BodyBuilder ........... 1
      EMAIL_RECIPIENT rows .................... 0   (nothing seeds it, by design)

    Grants of 0 means SP0ROLE.SystemName does not match the names in section 2 on
    this environment -- check SP0ROLE and re-run that section.

    A database missing some RBAC functions gets proportionally fewer keys, which
    is correct: keys are only ever attached to functions that exist. Expect LOWER
    numbers on a clean install than on a long-lived dev box -- a dev database
    also carries seed residue (PO / GR / TKT / EMAIL_* function names that no
    migration creates), which inflates both the key count and
    TB_M_ETD_EMAIL_CONTENT.                                                     */

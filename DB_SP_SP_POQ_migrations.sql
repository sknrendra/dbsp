/* ============================================================================
   DB_SP_SP -- POQ REVAMP (SP1POQ + SP0VENDOR.POQN3Flag)

   Companion to supplier-portal-be/shared/migrations/db_sp_sp/
   140-allow-null-poqn3flag.js, 141-add-poq-confirm-rates.js,
   142-add-campaign-poq-to-sp1poq.js, 143-drop-pqcfqt-from-sp1poq.js,
   144-drop-pqtpoq-from-sp1poq.js and 145-add-confirm-audit-to-sp1poq.js.
   This file converges prod's schema the same way
   DB_SP_SP-migration-candidates.sql does.

   WHAT CHANGED, AND WHY IT IS ITS OWN FILE
   ----------------------------------------
   The POQ Confirmation flow was rebuilt around the columns legacy actually
   uses. Legacy's own SP1POQ entity
   (supplier-portal-existing/TAMSupplier.Data/SP1POQ.cs) carries PQORG1-4 and
   PQREV1-4: the TAM original and the supplier's REVISION of it, one pair per
   period N, N+1, N+2, N+3. Those eight columns already exist on prod and are
   NOT touched here. What follows is everything built on top of them.

   Three blocks in DB_SP_SP-migration-candidates.sql are SUPERSEDED by this
   file and have been removed or amended there:
     - SP1POQ.PQCFQT   dropped entirely (see below)
     - SP1POQ.PQTPOQ   dropped entirely (see below)
     - SP1POQ.WarningFlag  now bit, not nvarchar(1) 'Y'/'N'
     - SP0VENDOR.POQN3Flag now NULL-able with no default, which answers the
       open "confirm the real default with TAM" question that file recorded

   WHY PQCFQT AND PQTPOQ ARE GONE RATHER THAN MIGRATED
   ---------------------------------------------------
   PQCFQT ("Confirmation Qty") was a dev-side invention. The concept is real
   (FSD Table 12 #15) but its home is not: the supplier's confirmed quantity
   for period N is PQREV1, the revision counterpart of PQORG1, which legacy
   has always had. The app was repointed onto PQREV1-4 and nothing writes or
   reads PQCFQT any more, so prod never needs the column.

   PQTPOQ ("Total POQ") is dropped because it carries no business meaning.
   Nothing in the app reads it, and legacy's own "Total POQ" cell
   (PoqServices.cs:4053 header, :4218 value) is filled with REVISED_POQ_1 --
   a figure the workbook already shows in its own column.

   Idempotent, safe to re-run. Each block also repairs a column already
   created with the pre-revamp definition, so running this after an earlier
   DB_SP_SP-migration-candidates.sql pass converges to the same result.
   ============================================================================ */

SET NOCOUNT ON;
GO


/* ============================================================================
   SECTION 1 -- SP0VENDOR.POQN3Flag (confirmation horizon)
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- POQN3Flag says how far past the current period a supplier must confirm:
--
--     NULL -> period N only
--     '1'  -> through N+1
--     '2'  -> through N+2
--     '3'  -> through N+3
--
-- Cumulative, and Vendor_Type 25 (Supplier Code) only. One flag governs BOTH
-- the Regular and the Special Order series; there is deliberately no campaign
-- variant, because the horizon is a property of the supplier rather than of
-- the kind of quantity.
--
-- NULLABLE WITH NO DEFAULT, which supersedes the
-- `nvarchar(5) NOT NULL DEFAULT ''` placeholder in
-- DB_SP_SP-migration-candidates.sql and closes the open question recorded
-- beside it. NULL is a real, meaningful value here -- it is the
-- least-demanding horizon -- so NOT NULL makes it unrepresentable. And a
-- default of '3' (the previous dev behaviour) silently put every newly
-- created supplier on the STRICTEST setting, obliging them to confirm three
-- extra periods nobody asked for. No default means an unset flag reads as
-- "N only" and a longer horizon is opted into.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP0VENDOR', 'POQN3Flag') IS NULL
BEGIN
    ALTER TABLE dbo.SP0VENDOR ADD POQN3Flag nvarchar(5) NULL;
END
GO

-- Repair path: the column may already exist as NOT NULL from an earlier
-- candidates run. Drop whatever default it carries (auto-named, so it has to
-- be looked up) and relax it to NULL.
IF COL_LENGTH('dbo.SP0VENDOR', 'POQN3Flag') IS NOT NULL
BEGIN
    DECLARE @poqn3Default sysname;
    SELECT TOP 1 @poqn3Default = dc.name
      FROM sys.default_constraints dc
      JOIN sys.columns c ON c.object_id = dc.parent_object_id
                        AND c.column_id = dc.parent_column_id
     WHERE dc.parent_object_id = OBJECT_ID('dbo.SP0VENDOR') AND c.name = 'POQN3Flag';
    IF @poqn3Default IS NOT NULL
        EXEC('ALTER TABLE dbo.SP0VENDOR DROP CONSTRAINT [' + @poqn3Default + ']');

    IF EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.SP0VENDOR')
                  AND name = 'POQN3Flag' AND is_nullable = 0)
        ALTER TABLE dbo.SP0VENDOR ALTER COLUMN POQN3Flag nvarchar(5) NULL;
END
GO


/* ============================================================================
   SECTION 2 -- SP1POQ, REGULAR SERIES (derived fields)
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- The supplier's confirmation horizon, snapshotted from SP0VENDOR onto the POQ
-- row when it is written. Kept on the row rather than joined at read time so a
-- later edit to the vendor master cannot retroactively change which periods a
-- confirmation that already happened was judged against.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1POQ', 'POQN3Flag') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD POQN3Flag nvarchar(5) NULL;
END
GO

-- ---------------------------------------------------------------------------
-- PQREVnRate = PQREVn / PQORGn: what the supplier confirmed over what TAM
-- originally asked for, one per period.
--
-- decimal(9,4). Four places is finer than the +/-20% band the warning is
-- derived from, and the integer side leaves room for the outliers a small
-- PQORG produces (PQREV 500 against PQORG 1 is a rate of 500, not an error).
-- Not float: the app rounds to this precision BEFORE testing the band, so the
-- stored number and the flag can never disagree at the boundary.
--
-- NULL means "not measurable" -- an unconfirmed period, or an original of
-- 0/NULL -- which is a different statement from a rate of zero.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1POQ', 'PQREV1Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREV1Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREV2Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREV2Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREV3Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREV3Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREV4Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREV4Rate decimal(9,4) NULL;
END
GO

-- ---------------------------------------------------------------------------
-- WarningFlag: TRUE when any IN-HORIZON PQREVnRate falls outside 0.8..1.2.
--
-- bit, NOT the nvarchar(1) 'Y'/'N' that DB_SP_SP-migration-candidates.sql
-- proposed -- that entry is superseded and has been removed there.
--
-- Nullable, and the NULL carries meaning rather than just permitting one: it
-- reads "not computed", which is what a row is before anyone confirms it and
-- what it becomes again after a TAM re-upload moves the PQORG baseline out
-- from under an earlier verdict. FALSE is the stronger claim, "measured, no
-- deviation".
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1POQ', 'WarningFlag') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD WarningFlag bit NULL;
END
GO

-- Repair path: convert an existing nvarchar(1) 'Y'/'N' column in place.
-- 'Y'/'N' will not CAST to bit but '1'/'0' will, and SQL Server refuses to
-- ALTER a column out from under its own (auto-named) default, so the default
-- goes first, then the values, then the type.
IF COL_LENGTH('dbo.SP1POQ', 'WarningFlag') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns c
                 JOIN sys.types t ON t.user_type_id = c.user_type_id
                WHERE c.object_id = OBJECT_ID('dbo.SP1POQ')
                  AND c.name = 'WarningFlag' AND t.name <> 'bit')
BEGIN
    DECLARE @warnDefault sysname;
    SELECT TOP 1 @warnDefault = dc.name
      FROM sys.default_constraints dc
      JOIN sys.columns c ON c.object_id = dc.parent_object_id
                        AND c.column_id = dc.parent_column_id
     WHERE dc.parent_object_id = OBJECT_ID('dbo.SP1POQ') AND c.name = 'WarningFlag';
    IF @warnDefault IS NOT NULL
        EXEC('ALTER TABLE dbo.SP1POQ DROP CONSTRAINT [' + @warnDefault + ']');

    UPDATE dbo.SP1POQ
       SET WarningFlag = CASE WHEN UPPER(LTRIM(RTRIM(WarningFlag))) IN ('Y', '1') THEN '1' ELSE '0' END
     WHERE WarningFlag IS NOT NULL;

    ALTER TABLE dbo.SP1POQ ALTER COLUMN WarningFlag bit NULL;
END
GO


/* ============================================================================
   SECTION 3 -- SP1POQ, CAMPAIGN (SPECIAL ORDER) SERIES
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- Campaign POQ is a second quantity series running parallel to the regular
-- one, at every index. Regular POQ carries the supplier's common, repeating
-- supply requirement; campaign is irregular by nature, so the two are planned,
-- confirmed and judged SEPARATELY rather than summed into one number.
--
--     PQORGCMP1-4       TAM's campaign original for N, N+1, N+2, N+3
--     PQREVCMP1-4       the supplier's confirmation of each
--     PQREVCMP1-4Rate   PQREVCMPn / PQORGCMPn
--     WarningFlagCMP    judged independently of WarningFlag
--
-- These columns are NEW, not ported. Legacy's SP1POQ has no campaign
-- counterpart at any index, and DB_SP_PRO.dbo.POQ carries only a single flat
-- CAMPAIGN for period N. That single column is why
-- DB_SP_SP-migration-candidates.sql closes with a note saying POQ Campaign
-- "maps to DB_SP_PRO.dbo.POQ.CAMPAIGN, a different database entirely -- not
-- an ALTER TABLE against DB_SP_SP". That note is now SUPERSEDED: the upload
-- template's POQ Campaign and its three Special Order forecast columns are
-- the four campaign originals, and they land here.
--
-- The rates and the flag repeat the regular series' reasoning exactly; see
-- Section 2 for why decimal(9,4) and why the flag is a nullable bit.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1POQ', 'PQORGCMP1') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQORGCMP1 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQORGCMP2') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQORGCMP2 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQORGCMP3') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQORGCMP3 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQORGCMP4') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQORGCMP4 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP1') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP1 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP2') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP2 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP3') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP3 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP4') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP4 int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP1Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP1Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP2Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP2Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP3Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP3Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'PQREVCMP4Rate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD PQREVCMP4Rate decimal(9,4) NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'WarningFlagCMP') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD WarningFlagCMP bit NULL;
END
GO


/* ============================================================================
   SECTION 4 -- SP1POQ, SUPPLIER-SIDE AUDIT
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- SP1POQ already carries CreatedBy/CreatedDate and ModifiedBy/ModifiedDate,
-- and both sides of the process were writing them: the TAM upload AND the
-- supplier's confirmation. So the grid's "Confirm Date"/"Confirm By" and the
-- confirmation workbook's "Prepared By" reported whoever touched the row last
-- -- including the TAM user who uploaded it, and including a supplier DEL that
-- REMOVED a confirmation. Two events, two different actors, one audit trail.
--
-- The existing pair is now the TAM upload's alone. These four are the
-- supplier's:
--
--     ConfirmedBy / ConfirmedDate                 the FIRST confirmation
--     ConfirmModifiedBy / ConfirmModifiedDate     the LATEST confirmation
--
-- Both pairs are stamped on a first confirmation, so ConfirmModified* is never
-- NULL while Confirmed* is set. A supplier DEL clears all four, restoring the
-- row to its unconfirmed state. A TAM re-upload leaves them alone: it leaves
-- PQREV1-4 alone too, and erasing the record of a confirmation that really
-- happened while keeping the numbers it produced would be worse than stale.
--
-- int for the user ids, matching the existing CreatedBy/ModifiedBy: they hold
-- an SP0USERPORTAL.Id, not a name or an email. datetime for the timestamps,
-- matching ModifiedDate.
--
-- NO BACKFILL. All four start NULL, including on rows already confirmed: an
-- existing ModifiedBy cannot be attributed to the supplier or to TAM after the
-- fact. Those rows render blank in the grid's Confirm columns until they are
-- confirmed again.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.SP1POQ', 'ConfirmedBy') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD ConfirmedBy int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'ConfirmedDate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD ConfirmedDate datetime NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'ConfirmModifiedBy') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD ConfirmModifiedBy int NULL;
END
GO

IF COL_LENGTH('dbo.SP1POQ', 'ConfirmModifiedDate') IS NULL
BEGIN
    ALTER TABLE dbo.SP1POQ ADD ConfirmModifiedDate datetime NULL;
END
GO


/* ============================================================================
   STILL OPEN -- not actioned by this file
     - PQCFFG ("Confirmed" flag) stays in DB_SP_SP-migration-candidates.sql as
       bit NOT NULL DEFAULT 0. The open question recorded there suggested it
       could be derived from `PQCFQT IS NOT NULL` instead of persisted; with
       PQCFQT gone that derivation would now read `PQREV1 IS NOT NULL`. Left
       as a real column pending confirmation that "confirmed with qty 0" must
       be distinguishable from "not yet confirmed".
     - REASON nvarchar(500) likewise stays in the candidates file, unchanged.
   ============================================================================ */

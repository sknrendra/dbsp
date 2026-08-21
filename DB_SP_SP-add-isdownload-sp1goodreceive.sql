/* ============================================================================
   DB_SP_SP -- SP1GOODRECEIVE.IsDownload

   Companion to supplier-portal-be/shared/migrations/db_sp_sp/
   135-add-isdownload-to-sp1goodreceive.js (dev DB). This file converges
   prod's schema the same way DB_SP_SP-migration-candidates.sql does.

   Source: FSD Table 4/6 (Main Dashboard "Today GR Data" > Downloaded counter:
   COUNT of SP1GOODRECEIVE.DocNo WHERE IsDownload = 1) and Table 192 (GR
   Report - Download process description: rows not yet downloaded render bold
   in the grid; downloading already-downloaded data pops a Re-download
   Confirmation). Confirmed missing via direct INFORMATION_SCHEMA.COLUMNS
   introspection of DB_SP_SP.dbo.SP1GOODRECEIVE (2026-08-21) -- no such column
   on the real table.

   Single flag, not per-format (PDF/Excel/CSV) tracking: Table 192's "format
   yang sama" wording isn't backed by any documented per-format column
   anywhere in this FSD, so the re-download confirmation in the app fires on
   any repeat download regardless of format. See receiving/src/gr/controllers/
   download.js.

   Idempotent, safe to re-run.
   ============================================================================ */

SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.SP1GOODRECEIVE', 'IsDownload') IS NULL
BEGIN
    ALTER TABLE dbo.SP1GOODRECEIVE ADD IsDownload int NOT NULL DEFAULT 0;
END
GO

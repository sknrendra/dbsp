/* ============================================================================
   DB_SP_PRO -- MIGRATION CANDIDATES

   Companion to DB_SP_SP-migration-candidates.sql, same idea, different
   database: adds dev-only columns on DB_SP_PRO that this app needs but the
   restored backup doesn't have. Not covered by Migration Plan.xlsx (that
   workbook is scoped entirely to DB_SP_SP, checked 2026-08-20 -- zero hits
   for DB_SP_PRO across all 3 sheets), so these are sourced straight from the
   BE's own Sequelize migrations instead.

   All statements are idempotent (guarded on COL_LENGTH), safe to re-run.
   ============================================================================ */

SET NOCOUNT ON;
GO

-- ---------------------------------------------------------------------------
-- TB_R_PO_ALL.LATEST_DLV_DATE (1 column)
-- Source: supplier-portal-be/shared/migrations/db_sp_pro/
-- 014-add-upload-columns-to-tb-r-po-all.js. Live: order/src/po/controllers/
-- poUpload.js (search grid + preview DeliveryDate), report/controllers/
-- report.js (deliveryDatePlan, deliveryOverdue), dashboard-metrics/
-- controllers/dashboardMetrics.js (overdue filter), delivery/src/asn/
-- controllers/dataMaintenance.js. IS_SEND (added by the same migration) is
-- deliberately NOT included here -- replaced with a live EXISTS check against
-- SP1ORDERSENDING instead of a physical column, see poUpload.js.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.TB_R_PO_ALL', 'LATEST_DLV_DATE') IS NULL
BEGIN
    ALTER TABLE dbo.TB_R_PO_ALL ADD LATEST_DLV_DATE date NULL;
END
GO

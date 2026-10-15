/* ============================================================================
   DB_SP_SP -- SP1ORDERSENDING.POType

   Companion to supplier-portal-be/shared/migrations/db_sp_sp/
   157-add-potype-to-sp1ordersending.js (dev DB, and its db_sp_sp_baseline
   counterpart 184). This file converges prod's schema the same way
   DB_SP_SP-migration-candidates.sql does.

   Raw ORD_TYPE_TO_SUPP code off TB_R_PO_ALL (PO Upload), or the scheduler's
   literal 'DD' for Direct Delivery -- kept alongside the existing OrderType
   label column, never relabeled. Sibling table SP1ORDERSENDINGFAILED already
   has the same column, same name (POType, nvarchar(20)).

   Idempotent, safe to re-run.
   ============================================================================ */

SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.SP1ORDERSENDING', 'POType') IS NULL
BEGIN
    ALTER TABLE dbo.SP1ORDERSENDING ADD POType nvarchar(20) NULL;
END
GO

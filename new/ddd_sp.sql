USE DB_SP_PRO;
GO

DROP PROCEDURE IF EXISTS dbo.USP_DDD_PERFORMANCE_SUMMARY_REFRESH;
GO
CREATE PROCEDURE dbo.USP_DDD_PERFORMANCE_SUMMARY_REFRESH
  @DateFrom date,
  @DateTo date,
  @IsValid bit = NULL OUTPUT,
  @MsgError nvarchar(4000) = NULL OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  DECLARE @t0 datetime2 = SYSDATETIME(), @lock int, @deleted int = 0, @inserted int = 0;
  SET @IsValid = 0; SET @MsgError = '';

  IF @DateFrom IS NULL OR @DateTo IS NULL OR @DateFrom > @DateTo
  BEGIN
    SET @MsgError = N'@DateFrom and @DateTo are required and @DateFrom must be <= @DateTo.';
    RAISERROR('%s', 16, 1, @MsgError);
    RETURN;
  END

  EXEC @lock = sp_getapplock @Resource = 'DDD_PERF_SUMMARY', @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
  IF @lock < 0
  BEGIN
    SET @MsgError = N'Skipped: another USP_DDD_PERFORMANCE_SUMMARY_REFRESH run is in progress.';
    RAISERROR('%s', 16, 1, @MsgError);
    RETURN;
  END

  BEGIN TRY
    DECLARE @from char(8) = CONVERT(char(8), @DateFrom, 112), @to char(8) = CONVERT(char(8), @DateTo, 112);

    IF NOT EXISTS (SELECT 1 FROM DB_SP_INF.dbo.TB_I_H02_60_DDD_INFO_DTL WITH (NOLOCK))
    BEGIN
      -- Empty source (failed GT-IF load): keep the existing summary untouched.
      SET @MsgError = N'Skipped: TB_I_H02_60_DDD_INFO_DTL is empty.';
      EXEC sp_releaseapplock @Resource = 'DDD_PERF_SUMMARY', @LockOwner = 'Session';
      SET @IsValid = 1;
      SELECT @DateFrom AS DateFrom, @DateTo AS DateTo, 0 AS RowsDeleted, 0 AS RowsInserted,
             DATEDIFF(millisecond, @t0, SYSDATETIME()) AS ElapsedMs, @MsgError AS Note;
      RETURN;
    END

    SELECT DISTINCT
      LTRIM(RTRIM(s.VendorCode)) AS SUP, LTRIM(RTRIM(p.VendorCode)) AS PLANT, LTRIM(RTRIM(g.VendorCode)) AS VGRP
    INTO #grp
    FROM DB_SP_SP.dbo.SP0VENDOR s WITH (NOLOCK)
    JOIN DB_SP_SP.dbo.SP0VENDOR p WITH (NOLOCK) ON p.Id = s.Vendor_Parent_Id AND p.Vendor_Type = '22'
    JOIN DB_SP_SP.dbo.SP0VENDOR g WITH (NOLOCK) ON g.Id = p.Vendor_Parent_Id AND g.Vendor_Type = '21'
    WHERE s.Vendor_Type = '25' AND LTRIM(RTRIM(ISNULL(g.VendorCode, ''))) <> '';

    -- Legacy innermost DISTINCT: one row per PO line, arrival and remarks included.
    SELECT DISTINCT
      gr.VGRP, gr.PLANT, b.DELIVERED_PNO, b.PO_NO, b.PO_ITEM_NO, b.PO_TYPE, b.DEPOT_CODE, b.CROSS_DOCK_FLAG,
      b.SCHEDULED_DELIVERY_DATE_ AS SCHED, b.DDD_ADJUSTMENT_DATE_ AS ADJ, x.ARR,
      LTRIM(RTRIM(b.SUPPLIER_CODE)) AS SUPP_CODE, b.ACTUAL_DELIVERY_QTY AS ACT_QTY,
      CASE WHEN RIGHT(b.DIVISION_NO, 2) = '00' THEN b.ADJUSTED_DELIVERY_QTY ELSE 0 END AS PLAN_QTY,
      CASE WHEN b.DIVISION_NO = '0000000000' AND b.ACTUAL_DELIVERY_DATE_ = '' THEN 'NR'
           WHEN b.DIVISION_NO <> '0000000000' AND b.ACTUAL_DELIVERY_DATE_ = '' THEN 'Delay'
           WHEN b.ADJUSTED_DELIVERY_QTY = 0 THEN 'PO Delete'
           WHEN b.SCHEDULED_DELIVERY_DATE_ = x.ARR THEN 'Ontime'
           WHEN DATEDIFF(day, TRY_CAST(x.ARR AS date), TRY_CAST(b.SCHEDULED_DELIVERY_DATE_ AS date)) < 0 THEN 'Delay'
           ELSE 'Advance' END AS ORI_REMARK,
      CASE WHEN b.DIVISION_NO = '0000000000' AND b.ACTUAL_DELIVERY_DATE_ = '' THEN 'NR'
           WHEN b.DIVISION_NO <> '0000000000' AND b.ACTUAL_DELIVERY_DATE_ = '' THEN 'Delay'
           WHEN b.ADJUSTED_DELIVERY_QTY = 0 THEN 'PO Delete'
           WHEN b.DDD_ADJUSTMENT_DATE_ = x.ARR THEN 'Ontime'
           WHEN DATEDIFF(day, TRY_CAST(b.DDD_ADJUSTMENT_DATE_ AS date), TRY_CAST(x.ARR AS date)) > 0 THEN 'Delay'
           ELSE 'Advance' END AS ADJ_REMARK,
      CASE WHEN LEFT(b.SCHEDULED_DELIVERY_DATE_, 6) >= LEFT(x.ARR, 6) THEN 'Ontime' ELSE 'Delay' END AS ORI_MONTH_REMARK,
      CASE WHEN LEFT(b.DDD_ADJUSTMENT_DATE_, 6) >= LEFT(x.ARR, 6) THEN 'Ontime' ELSE 'Delay' END AS ADJ_MONTH_REMARK
    INTO #l3
    FROM DB_SP_INF.dbo.TB_I_H02_60_DDD_INFO_DTL b WITH (NOLOCK)
    JOIN #grp gr ON gr.SUP = LTRIM(RTRIM(b.SUPPLIER_CODE)) COLLATE DATABASE_DEFAULT
    LEFT JOIN DB_SP_PRO.dbo.VW_ASN_ARRIVAL_MAX_FREQUENCY d WITH (NOLOCK) ON b.SUPP_INVOICE_NO = d.ASN_NO
    CROSS APPLY (SELECT CASE WHEN d.ASN_NO IS NULL THEN b.ACTUAL_DELIVERY_DATE_ ELSE d.ARRIVAL_DATE END AS ARR) x
    WHERE b.SCHEDULED_DELIVERY_DATE_ BETWEEN @from AND @to
      AND TRY_CAST(b.SCHEDULED_DELIVERY_DATE_ AS date) IS NOT NULL;

    -- Legacy middle DISTINCT: projects the eight derived quantities.
    SELECT DISTINCT
      VGRP, PLANT, DELIVERED_PNO, PO_NO, PO_ITEM_NO, PO_TYPE, DEPOT_CODE, CROSS_DOCK_FLAG, SCHED, ADJ, ARR, SUPP_CODE, PLAN_QTY,
      CASE WHEN ORI_REMARK IN ('Ontime', 'Advance') THEN ACT_QTY ELSE 0 END AS DELIV_ORI,
      CASE WHEN ADJ_REMARK IN ('Ontime', 'Advance') THEN ACT_QTY ELSE 0 END AS DELIV_ADJ,
      CASE WHEN ORI_REMARK IN ('Ontime', 'Advance') THEN ACT_QTY ELSE 0 END AS ACC_ORI,
      CASE WHEN ADJ_REMARK IN ('Ontime', 'Advance') THEN ACT_QTY ELSE 0 END AS ACC_ADJ,
      CASE WHEN ORI_REMARK = 'Delay' THEN ACT_QTY ELSE 0 END AS DELAY_ORI,
      CASE WHEN ADJ_REMARK = 'Delay' THEN ACT_QTY ELSE 0 END AS DELAY_ADJ,
      CASE WHEN ORI_MONTH_REMARK = 'Ontime' THEN ACT_QTY ELSE 0 END AS CQ_ORI,
      CASE WHEN ADJ_MONTH_REMARK = 'Ontime' THEN ACT_QTY ELSE 0 END AS CQ_ADJ
    INTO #l2
    FROM #l3;

    SELECT VGRP, SUPP_CODE, CAST(SCHED AS date) AS SCHED_DATE,
           CAST(SUM(PLAN_QTY) AS int) AS PLAN_QTY, CAST(SUM(ACC_ORI) AS int) AS ACC_ORI, CAST(SUM(ACC_ADJ) AS int) AS ACC_ADJ
    INTO #sum
    FROM #l2
    GROUP BY VGRP, SUPP_CODE, SCHED;

    BEGIN TRAN;
      DELETE FROM dbo.TB_R_PO_DDD_N
       WHERE SCHEDULED_DELIVERY_DATE BETWEEN @DateFrom AND @DateTo;
      SET @deleted = @@ROWCOUNT;

      INSERT INTO dbo.TB_R_PO_DDD_N
        (VENDOR, SUPPLIER_CODE, VERSION_DDD_PERF, SCHEDULED_DELIVERY_DATE, PLAN_QTY, ACTUAL_DELIVERY_QTY, CreatedDate, ModifiedDate)
      SELECT VGRP, SUPP_CODE, v.VER, SCHED_DATE, PLAN_QTY,
             CASE v.VER WHEN 'ORIGINAL' THEN ACC_ORI ELSE ACC_ADJ END,
             SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET()
        FROM #sum
        CROSS JOIN (SELECT 'ORIGINAL' AS VER UNION ALL SELECT 'ADJUSTED') v;
      SET @inserted = @@ROWCOUNT;
    COMMIT;

    EXEC sp_releaseapplock @Resource = 'DDD_PERF_SUMMARY', @LockOwner = 'Session';
    SET @IsValid = 1;
    SELECT @DateFrom AS DateFrom, @DateTo AS DateTo, @deleted AS RowsDeleted, @inserted AS RowsInserted,
           DATEDIFF(millisecond, @t0, SYSDATETIME()) AS ElapsedMs, CAST(N'' AS nvarchar(4000)) AS Note;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    SET @MsgError = ERROR_MESSAGE();
    EXEC sp_releaseapplock @Resource = 'DDD_PERF_SUMMARY', @LockOwner = 'Session';
    SET @IsValid = 0;
    RAISERROR('%s', 16, 1, @MsgError);
  END CATCH
END
GO

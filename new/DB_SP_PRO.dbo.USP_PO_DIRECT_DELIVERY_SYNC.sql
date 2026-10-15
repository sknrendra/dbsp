USE [DB_SP_SP]
GO

CREATE OR ALTER PROCEDURE [dbo].[USP_PO_DIRECT_DELIVERY_SYNC]
    @UserName VARCHAR(20),
    @PoDate VARCHAR(100),
    @IsValid BIT OUTPUT,
    @MsgError VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserId varchar(20),
            @currentDateTime DATETIME = GETDATE()

    SELECT @UserId = Id FROM DB_SP_SP..SP0USERPORTAL WITH (NOLOCK) WHERE UserName = @UserName

    DECLARE @AppName VARCHAR(50) = 'SUPPLIER_PORTAL',
            @LogCategory VARCHAR(50) = 'PO DIRECT DELIVERY Synchronization',
            @Activity VARCHAR(50) = 'Execute Procedure USP_PO_DIRECT_DELIVERY_SYNC',
            @AppModule VARCHAR(50) = 'Hangfire Job - PO DIRECT DELIVERY Synchronize',
            @CreatedDateTime DATETIME = GETDATE(),
            @Hostname VARCHAR(50) = @@SERVERNAME,
            @Status VARCHAR(50) = '',
            @AdditionalInformation VARCHAR(MAX) = '',
            @TotalRow VARCHAR(20)

    SET @IsValid = 0
    SET @MsgError = ''

    BEGIN TRY
        SET @Status = 'Start'
        SET @AdditionalInformation = 'Execute Procedure USP_PO_DIRECT_DELIVERY_SYNC'
        EXEC DB_SP_SUP..USP_CREATE_LOG @AppName, @LogCategory, @Activity, @AppModule, @UserName, @CreatedDateTime, @Hostname, @Status, @AdditionalInformation, @IsValid OUTPUT, @MsgError OUTPUT

        IF OBJECT_ID('tempdb..#DD_DATA') IS NOT NULL
            DROP TABLE #DD_DATA

        SELECT
            PO_NO, PO_ITEM_NO, PO_PNO, PART_NAME, TOP_6_DIGITS_OF_KATASHIKI, PO_DATE,
            PO_QTY, SUPP_CODE, PLANT_CODE, VENDOR_GROUP, MAKER_CODE, PALLETIZE_MARK_CODE
        INTO #DD_DATA
        FROM (
            SELECT
                LTRIM(RTRIM(pdd.PO_NO))                                AS PO_NO,
                TRY_CAST(LTRIM(RTRIM(pdd.PO_ITEM_NO)) AS INT)          AS PO_ITEM_NO,
                LTRIM(RTRIM(pdd.PO_PNO))                               AS PO_PNO,
                ISNULL(LTRIM(RTRIM(pdd.PART_NAME)), '')                AS PART_NAME,
                LTRIM(RTRIM(pdd.TOP_6_DIGITS_OF_KATASHIKI))            AS TOP_6_DIGITS_OF_KATASHIKI,
                LTRIM(RTRIM(pdd.PO_DATE))                              AS PO_DATE,
                pdd.PO_QTY,
                LTRIM(RTRIM(pdd.SUPP_CODE))                            AS SUPP_CODE,
                LTRIM(RTRIM(pdd.PLANT_CODE))                           AS PLANT_CODE,
                LTRIM(RTRIM(pdd.VENDOR_GROUP))                         AS VENDOR_GROUP,
                LTRIM(RTRIM(pdd.MAKER_CODE))                           AS MAKER_CODE,
                LTRIM(RTRIM(pdd.PALLETIZE_MARK_CODE))                  AS PALLETIZE_MARK_CODE,
                ROW_NUMBER() OVER (
                    PARTITION BY LTRIM(RTRIM(pdd.PO_NO)), TRY_CAST(LTRIM(RTRIM(pdd.PO_ITEM_NO)) AS INT)
                    ORDER BY pdd.PALLETIZE_MARK_CODE) AS rn
            FROM DB_SP_PRO.dbo.VPODIRECTDELIVERY pdd WITH (NOLOCK)
            JOIN (
                SELECT DISTINCT VendorCode
                FROM DB_SP_SP..SP0VENDOR WITH (NOLOCK)
                WHERE Vendor_Type = (SELECT Id FROM DB_SP_SP..SP0APPLICATIONPARAM WITH (NOLOCK) WHERE Code = 'VendorCode')
            ) v ON pdd.SUPP_CODE = v.VendorCode
            WHERE LTRIM(RTRIM(pdd.PO_DATE)) = @PoDate
        ) x
        WHERE x.rn = 1
          AND x.PO_ITEM_NO IS NOT NULL
          AND x.PLANT_CODE IS NOT NULL
          AND x.VENDOR_GROUP IS NOT NULL

        -- Lines not yet sent, with their DocNo. SP1ORDERSENDING.DocNo has a foreign
        -- key to SP0DOCUMENT, so the document row must exist first.
        IF OBJECT_ID('tempdb..#DD_NEW') IS NOT NULL
            DROP TABLE #DD_NEW

        SELECT d.*,
               CONVERT(VARCHAR(100), CONCAT(d.PO_NO, ' DIRECTDELIVERY | ', @UserId, ' ', d.PLANT_CODE, ' ', d.VENDOR_GROUP)) AS DocNo
        INTO #DD_NEW
        FROM #DD_DATA d
        WHERE NOT EXISTS (
            SELECT 1 FROM DB_SP_SP..SP1ORDERSENDING t WITH (NOLOCK)
            WHERE t.PoNum = d.PO_NO AND t.ItemNo = d.PO_ITEM_NO
        )

        BEGIN TRANSACTION DD_SYNC

        -- Same shape as the Kanban proc's new-document insert (Status 'UPLOAD',
        -- Flag '', version 1); legacy uploadPODD does the same. Insert-only: a
        -- document that already exists (another line of the same PO) is left alone.
        INSERT INTO DB_SP_SP..SP0DOCUMENT (
            Module, PlantCode, VendorGroup, [Status], Flag, CreatedBy,
            CreatedDate, UploadedBy, UploadDate, DocNo, ApprovalVersion, DownloadVersion
        )
        SELECT DISTINCT
            (SELECT TOP 1 [Id] FROM DB_SP_SP..SP0MODULE WITH (NOLOCK) WHERE ModuleCode = 'PO'),
            n.PLANT_CODE,
            n.VENDOR_GROUP,
            'UPLOAD',
            '',
            @UserId,
            @currentDateTime,
            @UserId,
            @currentDateTime,
            n.DocNo,
            1,
            1
        FROM #DD_NEW n
        WHERE NOT EXISTS (
            SELECT 1 FROM DB_SP_SP..SP0DOCUMENT d WITH (NOLOCK) WHERE d.DocNo = n.DocNo
        )
        OPTION (OPTIMIZE FOR UNKNOWN)

        SELECT @TotalRow = CONVERT(VARCHAR, @@ROWCOUNT)

        SET @Status = 'Success'
        SET @Activity = 'INSERT INTO SP0DOCUMENT'
        SET @AdditionalInformation = @TotalRow + ' row was inserted to SP0DOCUMENT'
        EXEC DB_SP_SUP..USP_CREATE_LOG @AppName, @LogCategory, @Activity, @AppModule, @UserName, @CreatedDateTime, @Hostname, @Status, @AdditionalInformation, @IsValid OUTPUT, @MsgError OUTPUT

        INSERT INTO DB_SP_SP..SP1ORDERSENDING (
            DocNo, VendorGroup, VendorCode, PlantCode, PoNum, ItemNo,
            OrderDate, OrderType, POType, PartsNo, PmpNme, ModelCode, OrderedQty,
            PalletizeMark, Forc1, Forc2, Forc3, DownloadFlag, DownloadFrequency,
            Fran, PIC, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate
        )
        SELECT
            d.DocNo,
            d.VENDOR_GROUP,
            d.SUPP_CODE,
            d.PLANT_CODE,
            d.PO_NO,
            d.PO_ITEM_NO,
            CONVERT(DATETIME, d.PO_DATE, 112),
            'DIRECTDELIVERY',
            'DD',
            d.PO_PNO,
            d.PART_NAME,
            d.TOP_6_DIGITS_OF_KATASHIKI,
            CONVERT(INT, d.PO_QTY),
            d.PALLETIZE_MARK_CODE,
            0, 0, 0, 0, 0,
            d.MAKER_CODE,
            @UserName, @UserName, @currentDateTime, @UserName, @currentDateTime
        FROM #DD_NEW d
        OPTION (OPTIMIZE FOR UNKNOWN)

        SELECT @TotalRow = CONVERT(VARCHAR, @@ROWCOUNT)

        COMMIT TRANSACTION DD_SYNC

        SET @Status = 'Success'
        SET @Activity = 'INSERT INTO SP1ORDERSENDING'
        SET @AdditionalInformation = @TotalRow + ' row was inserted to SP1ORDERSENDING'
        EXEC DB_SP_SUP..USP_CREATE_LOG @AppName, @LogCategory, @Activity, @AppModule, @UserName, @CreatedDateTime, @Hostname, @Status, @AdditionalInformation, @IsValid OUTPUT, @MsgError OUTPUT

        SET @IsValid = 1
        SET @MsgError = ''
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION DD_SYNC

        SET @Status = 'Failed'
        SET @Activity = 'Error in USP_PO_DIRECT_DELIVERY_SYNC'
        SET @AdditionalInformation = ERROR_MESSAGE()
        EXEC DB_SP_SUP..USP_CREATE_LOG @AppName, @LogCategory, @Activity, @AppModule, @UserName, @CreatedDateTime, @Hostname, @Status, @AdditionalInformation, @IsValid OUTPUT, @MsgError OUTPUT

        SET @IsValid = 0
        SET @MsgError = ERROR_MESSAGE()
    END CATCH
END
GO

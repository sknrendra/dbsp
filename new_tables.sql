
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.SP1ORDERSENDINGFAILED', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SP1ORDERSENDINGFAILED (
    Id nvarchar(36) NOT NULL,
    OrderDate datetimeoffset NULL,
    VendorGroup nvarchar(50) NULL,
    PlantCode nvarchar(50) NULL,
    VendorCode nvarchar(50) NULL,
    PoNum nvarchar(100) NOT NULL,
    ItemNo nvarchar(10) NULL,
    PartsNo nvarchar(100) NULL,
    PmpNme nvarchar(255) NULL,
    ModelCode nvarchar(255) NULL,
    OrderedQty int NULL,
    ICC nvarchar(50) NULL,
    StockQty int NULL,
    MAD datetimeoffset NULL,
    POType nvarchar(10) NULL,
    OrderType nvarchar(10) NULL,
    CrossDockFlag nvarchar(10) NULL,
    DeliveryDate datetimeoffset NULL,
    Remark nvarchar(255) NULL,
    GTPOStatus nvarchar(50) NULL,
    CreatedDate datetimeoffset NOT NULL,
    ModifiedDate datetimeoffset NOT NULL,
    CONSTRAINT PK_SP1ORDERSENDINGFAILED PRIMARY KEY (Id)
    );
END
GO

IF OBJECT_ID('dbo.SP1TICKET', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SP1TICKET (
    NO int IDENTITY(1,1) NOT NULL,
    TICKET_NO nvarchar(255) NOT NULL,
    SUBMIT_DATE date NOT NULL,
    CATEGORY nvarchar(255) NOT NULL,
    CREATED_BY nvarchar(255) NOT NULL,
    COMPANY_GROUP nvarchar(255) NOT NULL,
    PLANT_CODE nvarchar(255) NOT NULL,
    PO_NO nvarchar(255) NULL,
    PART_NO nvarchar(255) NULL,
    SUP_UPLOAD_FILE nvarchar(255) NULL,
    QUESTION nvarchar(255) NOT NULL,
    ANSWER nvarchar(255) NULL,
    TAM_UPLOAD_FILE nvarchar(255) NULL,
    STATUS nvarchar(255) NOT NULL DEFAULT N'Outstanding',
    CONSTRAINT PK_SP1TICKET PRIMARY KEY (NO)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_ASN_ON_OFF_STG', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_ASN_ON_OFF_STG (
    ID int IDENTITY(1,1) NOT NULL,
    SETTING_TYPE nvarchar(10) NOT NULL,
    ONLINE_TIME_DAILY_STG_FROM nvarchar(5) NULL,
    ONLINE_TIME_DAILY_STG_TO nvarchar(5) NULL,
    PRD_DATE_FROM datetimeoffset NULL,
    PRD_DATE_TO datetimeoffset NULL,
    OFFLINE_TIME_STG_FROM nvarchar(5) NULL,
    OFFLINE_TIME_STG_TO nvarchar(5) NULL,
    REMARK nvarchar(255) NULL,
    STATUS nvarchar(20) NULL,
    CREATED_DATE datetimeoffset NULL,
    MODIFIED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_ASN_ON_OFF_STG PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_DRIVER_SHE_MASTER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_DRIVER_SHE_MASTER (
    ID int IDENTITY(1,1) NOT NULL,
    DRIVER_NAME nvarchar(255) NOT NULL,
    DRIVER_LICENSE nvarchar(50) NOT NULL,
    DRIVER_PHOTO nvarchar(500) NULL,
    DRIVER_LICENSE_PHOTO nvarchar(500) NULL,
    LICENSE_EXPIRE_DATE date NULL,
    SIO_TAM_NO nvarchar(50) NULL,
    SIO_TAM_PHOTO nvarchar(500) NULL,
    SIO_TAM_DATE date NULL,
    SIO_GOVERNMENT_NO nvarchar(50) NULL,
    SIO_GOVERNMENT_PHOTO nvarchar(500) NULL,
    SIO_GOV_DATE date NULL,
    OTHER_REQUIREMENTS nvarchar(500) NULL,
    REMARK nvarchar(500) NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_DRIVER_SHE_MASTER PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_ETA_SPLD', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_ETA_SPLD (
    ID int IDENTITY(1,1) NOT NULL,
    INVOICE_NO nvarchar(50) NOT NULL,
    ORIGINAL_ETA_SPLD date NULL,
    CURRENT_ETA_SPLD date NULL,
    ETA_SPLD date NULL,
    REMARK nvarchar(100) NULL,
    UPDATED_BY nvarchar(100) NULL,
    UPDATED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_ETA_SPLD PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_ETD_EMAIL_CONTENT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_ETD_EMAIL_CONTENT (
    ID int IDENTITY(1,1) NOT NULL,
    FUNCTION_ID nvarchar(50) NOT NULL,
    FUNC_DESCRIPTION nvarchar(255) NULL,
    PLANT_CODE nvarchar(50) NOT NULL,
    EMAIL_TO nvarchar(500) NULL,
    EMAIL_CC nvarchar(500) NULL,
    EMAIL_BCC nvarchar(500) NULL,
    EMAIL_SUBJECT nvarchar(500) NOT NULL,
    EMAIL_MESSAGE nvarchar(max) NOT NULL,
    CREATED_BY nvarchar(255) NULL,
    CHANGED_BY nvarchar(255) NULL,
    CREATED_DT datetimeoffset NULL,
    CHANGED_DT datetimeoffset NULL,
    CONSTRAINT PK_TB_M_ETD_EMAIL_CONTENT PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_FD_GROUP', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_FD_GROUP (
    FD_CODE nvarchar(20) NOT NULL,
    FD_GROUP nvarchar(50) NULL,
    CONSTRAINT PK_TB_M_FD_GROUP PRIMARY KEY (FD_CODE)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_FUNCTION', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_FUNCTION (
    id char(36) NOT NULL,
    Name nvarchar(255) NOT NULL,
    createdAt datetimeoffset NULL,
    updatedAt datetimeoffset NULL,
    CONSTRAINT PK_TB_M_FUNCTION PRIMARY KEY (id)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_GATE_BOOK', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_GATE_BOOK (
    ID int IDENTITY(1,1) NOT NULL,
    GATE_NO nvarchar(50) NOT NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_GATE_BOOK PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_GATE_VENDOR', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_GATE_VENDOR (
    ID int IDENTITY(1,1) NOT NULL,
    GATE_ID int NOT NULL,
    VENDOR_CODE nvarchar(100) NOT NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_GATE_VENDOR PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_MODULE_CONFIG', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_MODULE_CONFIG (
    ModuleId nvarchar(50) NOT NULL,
    ModuleName nvarchar(255) NOT NULL,
    TenantId nvarchar(50) NOT NULL,
    Enabled bit NOT NULL DEFAULT 1,
    Config nvarchar(max) NULL,
    createdAt datetimeoffset NOT NULL,
    updatedAt datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_MODULE_CONFIG PRIMARY KEY (ModuleId)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_NEWS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_NEWS (
    ID int IDENTITY(1,1) NOT NULL,
    COMPANY_CODE nvarchar(255) NOT NULL,
    PLANT_CODE nvarchar(255) NOT NULL,
    MESSAGE nvarchar(255) NOT NULL,
    START_FROM datetimeoffset NOT NULL,
    END_TO datetimeoffset NOT NULL,
    STATUS nvarchar(255) NOT NULL DEFAULT N'Active',
    REMARK nvarchar(255) NULL,
    CHANGE_DT datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_NEWS PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_NOTE_CONFIG', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_NOTE_CONFIG (
    Id nvarchar(36) NOT NULL,
    FunctionCode nvarchar(50) NOT NULL,
    PlantCode nvarchar(50) NOT NULL,
    RemarkOrNote nvarchar(max) NOT NULL,
    CreatedBy nvarchar(100) NULL,
    CreatedDate datetimeoffset NOT NULL,
    ModifiedDate datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_NOTE_CONFIG PRIMARY KEY (Id)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_PERMISSION', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_PERMISSION (
    ROLE_ID int NOT NULL,
    FUNCTION_ID char(36) NOT NULL,
    VIEW_FEATURE bit NOT NULL DEFAULT 0,
    CREATE_FEATURE bit NOT NULL DEFAULT 0,
    UPDATE_FEATURE bit NOT NULL DEFAULT 0,
    DELETE_FEATURE bit NOT NULL DEFAULT 0,
    SEARCH_FEATURE bit NOT NULL DEFAULT 0,
    DOWNLOAD_FEATURE bit NOT NULL DEFAULT 0,
    UPLOAD_FEATURE bit NOT NULL DEFAULT 0,
    CREATED_BY nvarchar(100) NULL,
    UPDATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_PERMISSION PRIMARY KEY (ROLE_ID, FUNCTION_ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_SUPPLIER_BUSINESS_ROUTE', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_SUPPLIER_BUSINESS_ROUTE (
    ID int IDENTITY(1,1) NOT NULL,
    BUSINESS_CODE nvarchar(50) NOT NULL,
    SUPP_CODE nvarchar(50) NOT NULL,
    PLANT_CODE nvarchar(50) NOT NULL,
    IS_DELETED int NOT NULL DEFAULT 0,
    CREATED_BY nvarchar(100) NULL,
    CREATED_TIME datetimeoffset NULL,
    MODIFIED_BY nvarchar(100) NULL,
    MODIFIED_TIME datetimeoffset NULL,
    CONSTRAINT PK_TB_M_SUPPLIER_BUSINESS_ROUTE PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_TAM_MASTER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_TAM_MASTER (
    COMPANY_CODE nvarchar(50) NOT NULL,
    COMPANY_NAME nvarchar(255) NULL,
    BRAND_NAME nvarchar(255) NULL,
    DIVISION_NAME nvarchar(255) NULL,
    ADDRESS_LEGAL nvarchar(500) NULL,
    ADDRESS_MAILING nvarchar(500) NULL,
    ADDRESS_OPERATION nvarchar(500) NULL,
    ADDRESS_DIVISION nvarchar(500) NULL,
    PHONE_NO nvarchar(50) NULL,
    DIVISION_HEAD nvarchar(255) NULL,
    FAX_NO nvarchar(50) NULL,
    MANAGER nvarchar(255) NULL,
    WEBSITE_ADDRESS nvarchar(255) NULL,
    ASST_MANAGER nvarchar(255) NULL,
    EMAIL_ADDRESS nvarchar(255) NULL,
    SUPERVISOR_1 nvarchar(255) NULL,
    NPWP_NO nvarchar(100) NULL,
    EMAIL_ADDRESS_SPV1 nvarchar(255) NULL,
    SIUP_NO nvarchar(100) NULL,
    SUPERVISOR_2 nvarchar(255) NULL,
    OTHERS_NO nvarchar(100) NULL,
    EMAIL_ADDRESS_SPV2 nvarchar(255) NULL,
    DIRECTOR_1 nvarchar(255) NULL,
    COORDINATOR_NAME nvarchar(255) NULL,
    DIRECTOR_2 nvarchar(255) NULL,
    EMAIL_ADDRESS_COORD nvarchar(255) NULL,
    REMARK nvarchar(500) NULL,
    createdAt datetimeoffset NOT NULL,
    updatedAt datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_TAM_MASTER PRIMARY KEY (COMPANY_CODE)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_TENANT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_TENANT (
    TenantId nvarchar(50) NOT NULL,
    CompanyName nvarchar(255) NOT NULL,
    [Plan] nvarchar(50) NOT NULL,
    Status nvarchar(20) NOT NULL DEFAULT N'Active',
    createdAt datetimeoffset NOT NULL,
    updatedAt datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_TENANT PRIMARY KEY (TenantId)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_TRUCK_BOOKING', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_TRUCK_BOOKING (
    ID int IDENTITY(1,1) NOT NULL,
    GATE_NO nvarchar(50) NOT NULL,
    TIME_SLOT nvarchar(25) NULL,
    START_TIME_SLOT nvarchar(10) NOT NULL,
    END_TIME_SLOT nvarchar(10) NOT NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_TRUCK_BOOKING PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_TRUCK_SHE_MASTER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_TRUCK_SHE_MASTER (
    TRUCK_POLICE_NO nvarchar(20) NOT NULL,
    COMPANY nvarchar(10) NOT NULL,
    TRUCK_TYPE nvarchar(50) NOT NULL,
    DRIVER_NAME nvarchar(100) NULL,
    FUEL_TYPE nvarchar(50) NULL,
    STD_EMISSIONE_ENGINE nvarchar(50) NULL,
    ENGINE_CC int NULL,
    CARGO_CAPACITY int NULL,
    REMARK nvarchar(500) NULL,
    TRUCK_COMPANY nvarchar(100) NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_M_TRUCK_SHE_MASTER PRIMARY KEY (TRUCK_POLICE_NO)
    );
END
GO

IF OBJECT_ID('dbo.TB_M_USER_PROC_ID', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_M_USER_PROC_ID (
    ID int IDENTITY(1,1) NOT NULL,
    USER_ID_WINDOWS nvarchar(100) NOT NULL,
    PROC_CODE_ID nvarchar(50) NOT NULL,
    USER_NAME nvarchar(255) NOT NULL,
    DEPT_SECTION nvarchar(255) NOT NULL,
    CREATED_BY nvarchar(255) NULL,
    UPDATED_BY nvarchar(255) NULL,
    CREATED_DATE datetimeoffset NOT NULL,
    UPDATED_DATE datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_M_USER_PROC_ID PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_CONT_DLV', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_CONT_DLV (
    INVOICE_NO nvarchar(50) NOT NULL,
    SHIPMENT_STATUS nvarchar(20) NULL,
    SEAL_NO nvarchar(50) NULL,
    TMA_INVOICE_READY date NULL,
    IVL_READY date NULL,
    UPDATED_BY nvarchar(100) NULL,
    UPDATED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_R_CONT_DLV PRIMARY KEY (INVOICE_NO)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_DDD_REV_REQ', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_DDD_REV_REQ (
    Id nvarchar(36) NOT NULL,
    RequestNo nvarchar(20) NOT NULL,
    PlantCode nvarchar(10) NULL,
    SupplierCode nvarchar(20) NULL,
    PoDate datetimeoffset NULL,
    PoNo nvarchar(20) NOT NULL,
    PoItemNo nvarchar(10) NOT NULL,
    PoPno nvarchar(50) NULL,
    PoQty int NULL,
    AsnQty int NULL DEFAULT 0,
    RemainQty int NULL DEFAULT 0,
    PoType nvarchar(10) NULL,
    CrossDock nvarchar(5) NULL,
    ReviseNo int NULL DEFAULT 0,
    PlanDeliveryDate datetimeoffset NULL,
    ReviseReqDate datetimeoffset NULL,
    TamReqType nvarchar(20) NULL,
    Remark nvarchar(255) NULL,
    RequestType nvarchar(20) NOT NULL,
    ApprovalFlag nvarchar(5) NULL,
    ApprovalBy nvarchar(50) NULL,
    CreatedBy nvarchar(50) NULL,
    CreatedDate datetimeoffset NOT NULL,
    ModifiedDate datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_R_DDD_REV_REQ PRIMARY KEY (Id)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_DD_DP_CASE', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_DD_DP_CASE (
    ASN_NO nvarchar(100) NOT NULL,
    RECEIVING_CASE_NO nvarchar(100) NOT NULL,
    CPD_ARRIVAL_DATE date NULL,
    EXIST_FLAG int NOT NULL DEFAULT 1,
    REMARK nvarchar(500) NULL,
    CHECKED_BY nvarchar(100) NULL,
    CHECKED_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_R_DD_DP_CASE PRIMARY KEY (ASN_NO, RECEIVING_CASE_NO)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_DOC_HUB', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_DOC_HUB (
    ID int IDENTITY(1,1) NOT NULL,
    COMPANY_CODE nvarchar(255) NOT NULL,
    PLANT_CODE nvarchar(255) NOT NULL,
    CATEGORY nvarchar(255) NOT NULL,
    FILE_NAME nvarchar(255) NOT NULL,
    FILE_ADDRESS nvarchar(255) NOT NULL,
    SIZE_FILE nvarchar(255) NOT NULL,
    REMARK nvarchar(255) NULL,
    UPLOAD_DATE datetimeoffset NOT NULL,
    UPLOAD_BY nvarchar(255) NOT NULL,
    CONSTRAINT PK_TB_R_DOC_HUB PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_DOC_HUB_DOWNLOAD', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_DOC_HUB_DOWNLOAD (
    ID int IDENTITY(1,1) NOT NULL,
    DOC_HUB_ID int NOT NULL,
    USER_ID nvarchar(255) NOT NULL,
    DOWNLOAD_DT datetimeoffset NOT NULL,
    CONSTRAINT PK_TB_R_DOC_HUB_DOWNLOAD PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_MONTHLY_REPORT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_MONTHLY_REPORT (
    ID int IDENTITY(1,1) NOT NULL,
    PERIOD nvarchar(6) NULL,
    YEAR nvarchar(4) NOT NULL,
    MONTH nvarchar(2) NOT NULL,
    VENDOR_GROUP nvarchar(100) NOT NULL,
    SUPPLIER_CODE nvarchar(100) NULL,
    SUPPLIER_NAME nvarchar(255) NULL,
    PIC nvarchar(255) NULL,
    MO_RPT nvarchar(255) NULL,
    FILE_PATH nvarchar(500) NULL,
    CONSTRAINT PK_TB_R_MONTHLY_REPORT PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_PALLET_REQ', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_PALLET_REQ (
    REQUEST_NO nvarchar(50) NOT NULL,
    PLANT_CODE nvarchar(20) NOT NULL,
    PALLET_TYPE nvarchar(50) NOT NULL,
    REQUEST_QTY int NOT NULL,
    ADD_QUOTA int NOT NULL,
    ADD_START_DATE date NULL,
    ADD_END_DATE date NULL,
    REQUEST_DATE date NOT NULL,
    REASON_REQUEST nvarchar(255) NULL,
    REASON_REJECT nvarchar(100) NULL,
    REQUEST_STATUS nvarchar(20) NOT NULL DEFAULT N'Waiting',
    CONSTRAINT PK_TB_R_PALLET_REQ PRIMARY KEY (REQUEST_NO)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_PN_LABEL_REQ', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_PN_LABEL_REQ (
    ID nvarchar(36) NOT NULL,
    REQUEST_NO nvarchar(50) NOT NULL,
    PLANT_CODE nvarchar(20) NOT NULL,
    SUPP_CODE nvarchar(20) NULL,
    PART_NO nvarchar(50) NOT NULL,
    PART_NAME nvarchar(255) NULL,
    PO_NO nvarchar(50) NULL,
    PO_DATE date NULL,
    PO_ITEM_NO nvarchar(10) NULL,
    PO_QTY int NULL,
    REMAIN_QTY int NULL,
    POQ_PERIOD nvarchar(20) NULL,
    PRINT_REQ_QTY int NOT NULL,
    PRINT_REQ_DATE datetimeoffset NOT NULL,
    PICKUP_DATE date NOT NULL,
    PRINT_APP_QTY int NULL,
    PRINT_APP_FLAG int NOT NULL DEFAULT 0,
    PRINT_APP_DATE datetimeoffset NULL,
    PRINTER_ID nvarchar(20) NULL,
    CONSTRAINT PK_TB_R_PN_LABEL_REQ PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_PRINT_CASE_LABEL_HISTORY', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_PRINT_CASE_LABEL_HISTORY (
    ID int IDENTITY(1,1) NOT NULL,
    ASN_NO nvarchar(100) NULL,
    CASE_NO nvarchar(100) NULL,
    PRINT_QTY int NULL,
    DELIVERY_NOTE nvarchar(100) NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetime NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_TB_R_PRINT_CASE_LABEL_HISTORY PRIMARY KEY (ID)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_TRUCK_BOOK_TRANS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_TRUCK_BOOK_TRANS (
    Id char(36) NOT NULL,
    GATE_NO nvarchar(20) NOT NULL,
    TIME_SLOT nvarchar(50) NOT NULL,
    START_TIME_SLOT nvarchar(20) NULL,
    END_TIME_SLOT nvarchar(20) NULL,
    DELIVERY_PLAN_DATE date NOT NULL,
    COMPANY_CODE nvarchar(20) NULL,
    BOOK_TYPE char(1) NULL,
    AVAILABLE_FLAG nvarchar(10) NULL,
    TRUCK_POLICE_NO nvarchar(20) NULL,
    TRUCK_TYPE nvarchar(50) NULL,
    DRIVER_NAME nvarchar(100) NULL,
    DRIVER_LICENSE nvarchar(50) NULL,
    LICENSE_EXPIRE_DATE date NULL,
    SIO_TAM_NO nvarchar(50) NULL,
    SIO_TAM_DATE date NULL,
    SIO_GOVERNMENT_NO nvarchar(50) NULL,
    ASN_NO nvarchar(50) NULL,
    ACTUAL_ARRIVAL_DATE date NULL,
    ACTUAL_ARRIVAL_TIME nvarchar(10) NULL,
    ACCURACY_FLAG char(1) NULL,
    START_EFF_DATE date NULL,
    END_EFF_DATE date NULL,
    FOLDING_QTY int NULL,
    MESH_BOX_QTY int NULL,
    OTHER_QTY int NULL,
    CREATED_BY nvarchar(100) NULL,
    CREATED_DATE datetimeoffset NULL,
    UPDATE_BY nvarchar(100) NULL,
    UPDATE_DATE datetimeoffset NULL,
    CONSTRAINT PK_TB_R_TRUCK_BOOK_TRANS PRIMARY KEY (Id)
    );
END
GO

IF OBJECT_ID('dbo.TB_R_WEEKLY_REPORT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_WEEKLY_REPORT (
    ID bigint IDENTITY(1,1) NOT NULL,
    MONTH nvarchar(6) NULL,
    VENDOR_GROUP nvarchar(50) NULL,
    VENDOR_CODE nvarchar(50) NULL,
    VENDOR_NAME nvarchar(255) NULL,
    PIC nvarchar(255) NULL,
    MO_RPT nvarchar(255) NULL,
    POQ_CONFIRM_PCT decimal(5,2) NULL,
    DDD_ACCURACY_PCT decimal(5,2) NULL,
    CreatedDate datetime NULL DEFAULT GETDATE(),
    ModifiedDate datetime NULL,
    CONSTRAINT PK_TB_R_WEEKLY_REPORT PRIMARY KEY (ID)
    );
END
GO

-- TB_R_PALLET_SUM lives here per FSD (DB_SP_SP.dbo.TB_R_PALLET_SUM -- see
-- §2.4.2.2, §2.6.1.2, §2.6.4.2, §2.6.6.2, every occurrence). The BE originally
-- created it under DB_SP_PRO instead (spec/code mismatch, not covered by
-- Migration Plan.xlsx); repointed 2026-08-30 to match this DDL -- model moved
-- to shared/models/db_sp_sp/tb_r_pallet_sum.js, db_sp_pro/006 reverted by
-- db_sp_pro/055-drop-tb-r-pallet-sum.js, created for DB_SP_SP by
-- db_sp_sp/138-create-tb-r-pallet-sum.js, and asnWrite.js's commitAsn now
-- writes these rows in its DB_SP_SP transaction (alongside SP1ASN) instead of
-- the DB_SP_PRO one it shared with TB_R_ASN before.
IF OBJECT_ID('dbo.TB_R_PALLET_SUM', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TB_R_PALLET_SUM (
    id int IDENTITY(1,1) NOT NULL,
    ASN_NO nvarchar(50) NOT NULL,
    PALLET_TYPE nvarchar(50) NOT NULL,
    PALLET_QTY int NULL,
    [TRANSACTION] nvarchar(10) NULL,
    CONSTRAINT PK_TB_R_PALLET_SUM PRIMARY KEY (id)
    );
END
GO

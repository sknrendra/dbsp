-- Problem Sheet e-mail events (= migration 184). Idempotent: re-running inserts nothing.
-- Target: DB_SP_SP. Templates are the built-in starters (1434 has no Signer row to copy from).
USE DB_SP_SP;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

-- 1. Functions (e-mail identities, no permissions)
IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'ProblemSheetToSupplier')
  INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES (CONVERT(char(36), NEWID()), N'ProblemSheetToSupplier', SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'ProblemSheetReplyToTam')
  INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES (CONVERT(char(36), NEWID()), N'ProblemSheetReplyToTam', SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM dbo.TB_M_FUNCTION WHERE Name = N'ProblemSheetResponseToSupplier')
  INSERT INTO dbo.TB_M_FUNCTION (id, Name, createdAt, updatedAt) VALUES (CONVERT(char(36), NEWID()), N'ProblemSheetResponseToSupplier', SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET());

-- 2. Declared template variables
INSERT INTO dbo.TB_M_TEMPLATE_KEYS (FUNCTION_ID, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML, IS_ACTIVE, CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
SELECT f.id, v.KEY_NAME, v.DESCRIPTION, v.SAMPLE_VALUE, 0, 1, N'seed', SYSDATETIMEOFFSET(), N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
CROSS JOIN (VALUES
  (N'problemNo', N'Problem sheet number', N'PS-0001'),
  (N'qitCode', N'Source QIT code', N'QIT-0001'),
  (N'caseNo', N'Case number', N'CASE-0001'),
  (N'supplierCode', N'Supplier code', N'AII1'),
  (N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA'),
  (N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA'),
  (N'partNo', N'Part number', N'312100D180'),
  (N'partName', N'Part name', N'COVER ASSY, CLUTCH'),
  (N'problemCategory', N'Problem category', N'Wrong Part'),
  (N'status', N'Problem sheet status', N'Drafting'),
  (N'ngQty', N'NG quantity', N'3'),
  (N'deliveryQty', N'Delivery quantity', N'100'),
  (N'poNumber', N'PO number', N'A4303519'),
  (N'deliveryDate', N'Delivery date', N'08-02-2026'),
  (N'createdDate', N'Created date', N'06-02-2026'),
  (N'repliedDate', N'Replied date', N'09-02-2026'),
  (N'replyUntilDate', N'Reply deadline', N'12-02-2026'),
  (N'action', N'What happened (Approved / Rejected / Revised)', N'Approved'),
  (N'comment', N'Revise comment from TAM', N'Lampirkan foto part'),
  (N'picSupplier', N'First supplier PIC on the e-mail route', N'Budi'),
  (N'picTam', N'First TAM PIC on the e-mail route', N'Sari')
) v(KEY_NAME, DESCRIPTION, SAMPLE_VALUE)
WHERE f.Name = N'ProblemSheetToSupplier'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_TEMPLATE_KEYS k WHERE k.FUNCTION_ID = f.id AND k.KEY_NAME = v.KEY_NAME);
INSERT INTO dbo.TB_M_TEMPLATE_KEYS (FUNCTION_ID, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML, IS_ACTIVE, CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
SELECT f.id, v.KEY_NAME, v.DESCRIPTION, v.SAMPLE_VALUE, 0, 1, N'seed', SYSDATETIMEOFFSET(), N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
CROSS JOIN (VALUES
  (N'problemNo', N'Problem sheet number', N'PS-0001'),
  (N'qitCode', N'Source QIT code', N'QIT-0001'),
  (N'caseNo', N'Case number', N'CASE-0001'),
  (N'supplierCode', N'Supplier code', N'AII1'),
  (N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA'),
  (N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA'),
  (N'partNo', N'Part number', N'312100D180'),
  (N'partName', N'Part name', N'COVER ASSY, CLUTCH'),
  (N'problemCategory', N'Problem category', N'Wrong Part'),
  (N'status', N'Problem sheet status', N'Drafting'),
  (N'ngQty', N'NG quantity', N'3'),
  (N'deliveryQty', N'Delivery quantity', N'100'),
  (N'poNumber', N'PO number', N'A4303519'),
  (N'deliveryDate', N'Delivery date', N'08-02-2026'),
  (N'createdDate', N'Created date', N'06-02-2026'),
  (N'repliedDate', N'Replied date', N'09-02-2026'),
  (N'replyUntilDate', N'Reply deadline', N'12-02-2026'),
  (N'action', N'What happened (Approved / Rejected / Revised)', N'Approved'),
  (N'comment', N'Revise comment from TAM', N'Lampirkan foto part'),
  (N'picSupplier', N'First supplier PIC on the e-mail route', N'Budi'),
  (N'picTam', N'First TAM PIC on the e-mail route', N'Sari')
) v(KEY_NAME, DESCRIPTION, SAMPLE_VALUE)
WHERE f.Name = N'ProblemSheetReplyToTam'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_TEMPLATE_KEYS k WHERE k.FUNCTION_ID = f.id AND k.KEY_NAME = v.KEY_NAME);
INSERT INTO dbo.TB_M_TEMPLATE_KEYS (FUNCTION_ID, KEY_NAME, DESCRIPTION, SAMPLE_VALUE, ALLOW_HTML, IS_ACTIVE, CREATED_BY, CREATED_DT, CHANGED_BY, CHANGED_DT)
SELECT f.id, v.KEY_NAME, v.DESCRIPTION, v.SAMPLE_VALUE, 0, 1, N'seed', SYSDATETIMEOFFSET(), N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
CROSS JOIN (VALUES
  (N'problemNo', N'Problem sheet number', N'PS-0001'),
  (N'qitCode', N'Source QIT code', N'QIT-0001'),
  (N'caseNo', N'Case number', N'CASE-0001'),
  (N'supplierCode', N'Supplier code', N'AII1'),
  (N'supplierName', N'Supplier name', N'PT. AISIN INDONESIA'),
  (N'supplier', N'Supplier code and name combined', N'AII1 PT. AISIN INDONESIA'),
  (N'partNo', N'Part number', N'312100D180'),
  (N'partName', N'Part name', N'COVER ASSY, CLUTCH'),
  (N'problemCategory', N'Problem category', N'Wrong Part'),
  (N'status', N'Problem sheet status', N'Drafting'),
  (N'ngQty', N'NG quantity', N'3'),
  (N'deliveryQty', N'Delivery quantity', N'100'),
  (N'poNumber', N'PO number', N'A4303519'),
  (N'deliveryDate', N'Delivery date', N'08-02-2026'),
  (N'createdDate', N'Created date', N'06-02-2026'),
  (N'repliedDate', N'Replied date', N'09-02-2026'),
  (N'replyUntilDate', N'Reply deadline', N'12-02-2026'),
  (N'action', N'What happened (Approved / Rejected / Revised)', N'Approved'),
  (N'comment', N'Revise comment from TAM', N'Lampirkan foto part'),
  (N'picSupplier', N'First supplier PIC on the e-mail route', N'Budi'),
  (N'picTam', N'First TAM PIC on the e-mail route', N'Sari')
) v(KEY_NAME, DESCRIPTION, SAMPLE_VALUE)
WHERE f.Name = N'ProblemSheetResponseToSupplier'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_TEMPLATE_KEYS k WHERE k.FUNCTION_ID = f.id AND k.KEY_NAME = v.KEY_NAME);

-- 3. One template row per function. PLANT_CODE is NULL after migration 174;
--    before 174 the column is NOT NULL, so '*' is used (ignored by the code either way).
DECLARE @plant nvarchar(50) = CASE WHEN COLUMNPROPERTY(OBJECT_ID('dbo.TB_M_ETD_EMAIL_CONTENT'), 'PLANT_CODE', 'AllowsNull') = 1 THEN NULL ELSE N'*' END;
INSERT INTO dbo.TB_M_ETD_EMAIL_CONTENT (FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE, EMAIL_TO, EMAIL_CC, EMAIL_BCC, EMAIL_SUBJECT, EMAIL_MESSAGE, CREATED_BY, CREATED_DT)
SELECT f.id, f.Name, @plant, NULL, NULL, NULL,
  N'Request Problem Sheet Reply {{problemNo}}',
  N'<p>Dear {{picSupplier}},</p><p>A Problem Sheet has been raised and requires your reply by {{replyUntilDate}}.</p><table border="1" cellspacing="0" cellpadding="6"><tr><td>Problem Sheet No</td><td>{{problemNo}}</td></tr><tr><td>Supplier</td><td>{{supplier}}</td></tr><tr><td>Case No</td><td>{{caseNo}}</td></tr><tr><td>PO No</td><td>{{poNumber}}</td></tr><tr><td>Part No</td><td>{{partNo}} {{partName}}</td></tr><tr><td>Problem Category</td><td>{{problemCategory}}</td></tr><tr><td>NG Qty</td><td>{{ngQty}}</td></tr></table><p>Please reply in the Supplier Portal.</p><p>Regards,<br/>{{picTam}}</p>',
  N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
WHERE f.Name = N'ProblemSheetToSupplier'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_ETD_EMAIL_CONTENT e WHERE e.FUNCTION_ID = f.id);
INSERT INTO dbo.TB_M_ETD_EMAIL_CONTENT (FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE, EMAIL_TO, EMAIL_CC, EMAIL_BCC, EMAIL_SUBJECT, EMAIL_MESSAGE, CREATED_BY, CREATED_DT)
SELECT f.id, f.Name, @plant, NULL, NULL, NULL,
  N'Problem Sheet {{problemNo}} replied by {{supplierCode}} ({{action}})',
  N'<p>Dear {{picTam}},</p><p>The supplier has replied to a Problem Sheet: <b>{{action}}</b>.</p><table border="1" cellspacing="0" cellpadding="6"><tr><td>Problem Sheet No</td><td>{{problemNo}}</td></tr><tr><td>Supplier</td><td>{{supplier}}</td></tr><tr><td>Case No</td><td>{{caseNo}}</td></tr><tr><td>PO No</td><td>{{poNumber}}</td></tr><tr><td>Part No</td><td>{{partNo}} {{partName}}</td></tr><tr><td>Problem Category</td><td>{{problemCategory}}</td></tr><tr><td>NG Qty</td><td>{{ngQty}}</td></tr></table><p>Please review the reply in the Supplier Portal.</p>',
  N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
WHERE f.Name = N'ProblemSheetReplyToTam'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_ETD_EMAIL_CONTENT e WHERE e.FUNCTION_ID = f.id);
INSERT INTO dbo.TB_M_ETD_EMAIL_CONTENT (FUNCTION_ID, FUNC_DESCRIPTION, PLANT_CODE, EMAIL_TO, EMAIL_CC, EMAIL_BCC, EMAIL_SUBJECT, EMAIL_MESSAGE, CREATED_BY, CREATED_DT)
SELECT f.id, f.Name, @plant, NULL, NULL, NULL,
  N'Problem Sheet {{problemNo}} {{action}} by TAM',
  N'<p>Dear {{picSupplier}},</p><p>TAM has <b>{{action}}</b> your reply to this Problem Sheet.</p><table border="1" cellspacing="0" cellpadding="6"><tr><td>Problem Sheet No</td><td>{{problemNo}}</td></tr><tr><td>Supplier</td><td>{{supplier}}</td></tr><tr><td>Case No</td><td>{{caseNo}}</td></tr><tr><td>PO No</td><td>{{poNumber}}</td></tr><tr><td>Part No</td><td>{{partNo}} {{partName}}</td></tr><tr><td>Problem Category</td><td>{{problemCategory}}</td></tr><tr><td>NG Qty</td><td>{{ngQty}}</td></tr></table><p>Comment: {{comment}}</p><p>Please check the Supplier Portal.</p>',
  N'seed', SYSDATETIMEOFFSET()
FROM dbo.TB_M_FUNCTION f
WHERE f.Name = N'ProblemSheetResponseToSupplier'
  AND NOT EXISTS (SELECT 1 FROM dbo.TB_M_ETD_EMAIL_CONTENT e WHERE e.FUNCTION_ID = f.id);

COMMIT;

-- Check
SELECT f.Name, e.EMAIL_SUBJECT, (SELECT COUNT(*) FROM dbo.TB_M_TEMPLATE_KEYS k WHERE k.FUNCTION_ID = f.id) AS key_count
FROM dbo.TB_M_FUNCTION f LEFT JOIN dbo.TB_M_ETD_EMAIL_CONTENT e ON e.FUNCTION_ID = f.id
WHERE f.Name IN (N'ProblemSheetToSupplier', N'ProblemSheetReplyToTam', N'ProblemSheetResponseToSupplier');

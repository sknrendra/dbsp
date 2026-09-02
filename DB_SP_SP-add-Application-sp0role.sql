IF COL_LENGTH('dbo.SP0ROLE', 'Application') IS NULL
BEGIN
    ALTER TABLE dbo.SP0ROLE ADD Application nvarchar(50) NULL;
END
GO

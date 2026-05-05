-- ============================================================
-- MIGRATION: Customers table restructure
-- Run against each tenant DB (TravelERP_Client1, etc.)
-- ============================================================

USE TravelERP_Client1;
GO

-- Step 1: Drop old columns
IF COL_LENGTH('Customers','FirstName')   IS NOT NULL ALTER TABLE Customers DROP COLUMN FirstName;
IF COL_LENGTH('Customers','LastName')    IS NOT NULL ALTER TABLE Customers DROP COLUMN LastName;
IF COL_LENGTH('Customers','AlternatePhone') IS NOT NULL ALTER TABLE Customers DROP COLUMN AlternatePhone;
IF COL_LENGTH('Customers','Gender')      IS NOT NULL ALTER TABLE Customers DROP COLUMN Gender;
IF COL_LENGTH('Customers','DateOfBirth') IS NOT NULL ALTER TABLE Customers DROP COLUMN DateOfBirth;
IF COL_LENGTH('Customers','Nationality') IS NOT NULL ALTER TABLE Customers DROP COLUMN Nationality;
IF COL_LENGTH('Customers','Address')     IS NOT NULL ALTER TABLE Customers DROP COLUMN Address;
IF COL_LENGTH('Customers','City')        IS NOT NULL ALTER TABLE Customers DROP COLUMN City;
IF COL_LENGTH('Customers','Country')     IS NOT NULL ALTER TABLE Customers DROP COLUMN Country;
IF COL_LENGTH('Customers','LoyaltyPoints') IS NOT NULL
BEGIN
    DECLARE @dfName NVARCHAR(200) = (
        SELECT dc.name FROM sys.default_constraints dc
        JOIN sys.columns c ON dc.parent_object_id=c.object_id AND dc.parent_column_id=c.column_id
        WHERE c.object_id=OBJECT_ID('Customers') AND c.name='LoyaltyPoints');
    IF @dfName IS NOT NULL EXEC('ALTER TABLE Customers DROP CONSTRAINT [' + @dfName + ']');
    ALTER TABLE Customers DROP COLUMN LoyaltyPoints;
END
IF COL_LENGTH('Customers','BranchId')    IS NOT NULL ALTER TABLE Customers DROP COLUMN BranchId;
IF COL_LENGTH('Customers','AssignedAgentId') IS NOT NULL ALTER TABLE Customers DROP COLUMN AssignedAgentId;
GO

-- Step 2: Add Mobile, populate from Phone, drop Phone
IF COL_LENGTH('Customers','Mobile') IS NULL
    ALTER TABLE Customers ADD Mobile NVARCHAR(30) NULL;
GO
IF COL_LENGTH('Customers','Phone') IS NOT NULL
BEGIN
    UPDATE Customers SET Mobile = Phone WHERE Mobile IS NULL;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Customers_Phone' AND object_id=OBJECT_ID('Customers'))
        DROP INDEX IX_Customers_Phone ON Customers;
    ALTER TABLE Customers DROP COLUMN Phone;
END
GO

-- Step 3: Add Name, populate, make NOT NULL
IF COL_LENGTH('Customers','Name') IS NULL
    ALTER TABLE Customers ADD Name NVARCHAR(150) NULL;
GO
UPDATE Customers SET Name = ISNULL(NULLIF(LTRIM(RTRIM('')), ''), 'Unknown') WHERE Name IS NULL;
ALTER TABLE Customers ALTER COLUMN Name NVARCHAR(150) NOT NULL;
GO

-- Step 4: Add all new enquiry columns
IF COL_LENGTH('Customers','Destination')      IS NULL ALTER TABLE Customers ADD Destination      NVARCHAR(200) NULL;
IF COL_LENGTH('Customers','TravelingDate')    IS NULL ALTER TABLE Customers ADD TravelingDate    DATE          NULL;
IF COL_LENGTH('Customers','LeavingFrom')      IS NULL ALTER TABLE Customers ADD LeavingFrom      NVARCHAR(100) NULL;
IF COL_LENGTH('Customers','TravelCity')       IS NULL ALTER TABLE Customers ADD TravelCity       NVARCHAR(100) NULL;
IF COL_LENGTH('Customers','HotelRecommended') IS NULL ALTER TABLE Customers ADD HotelRecommended NVARCHAR(200) NULL;
IF COL_LENGTH('Customers','NoOfAdults')       IS NULL ALTER TABLE Customers ADD NoOfAdults       TINYINT       NULL;
IF COL_LENGTH('Customers','NoOfChildren')     IS NULL ALTER TABLE Customers ADD NoOfChildren     TINYINT       NULL;
IF COL_LENGTH('Customers','NoOfDays')         IS NULL ALTER TABLE Customers ADD NoOfDays         TINYINT       NULL;
IF COL_LENGTH('Customers','AssignedTo')       IS NULL ALTER TABLE Customers ADD AssignedTo       NVARCHAR(150) NULL;
IF COL_LENGTH('Customers','LeadSource')       IS NULL ALTER TABLE Customers ADD LeadSource       NVARCHAR(100) NULL;
IF COL_LENGTH('Customers','Infant')           IS NULL ALTER TABLE Customers ADD Infant           NVARCHAR(50)  NULL;
IF COL_LENGTH('Customers','Remark')           IS NULL ALTER TABLE Customers ADD Remark           NVARCHAR(MAX) NULL;
GO

-- Step 5: Fix index
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Customers_Phone' AND object_id=OBJECT_ID('Customers'))
    DROP INDEX IX_Customers_Phone ON Customers;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Customers_Mobile' AND object_id=OBJECT_ID('Customers'))
    CREATE INDEX IX_Customers_Mobile ON Customers(Mobile);
GO

PRINT '✓ Customers table migrated successfully';
GO

-- ============================================================
-- TRAVEL ERP -- MASTER DATABASE SCHEMA
-- Run this on your SQL Server to create the master database
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TravelERP_Master')
BEGIN
    CREATE DATABASE TravelERP_Master;
END
GO

USE TravelERP_Master;
GO

-- ============================================================
-- CLIENT SEQUENCE TABLE
-- Generates TravelERP_Client1, TravelERP_Client2, etc.
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ClientSequence') AND type = 'U')
BEGIN
    CREATE TABLE ClientSequence (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        DatabaseName NVARCHAR(100) NOT NULL UNIQUE,
        CompanyId   INT           NULL,
        CreatedAt   DATETIME      NOT NULL DEFAULT GETUTCDATE()
    );
END
GO

-- ============================================================
-- COMPANIES TABLE
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Companies') AND type = 'U')
BEGIN
    CREATE TABLE Companies (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        Name            NVARCHAR(150) NOT NULL,
        Slug            NVARCHAR(50)  NOT NULL UNIQUE,
        DatabaseName    NVARCHAR(100) NOT NULL UNIQUE,
        Email           NVARCHAR(150) NOT NULL,
        Phone           NVARCHAR(30)  NOT NULL,
        Address         NVARCHAR(300) NULL,
        City            NVARCHAR(100) NULL,
        Country         NVARCHAR(100) NOT NULL DEFAULT 'India',
        LogoUrl         NVARCHAR(500) NULL,
        LicenseNumber   NVARCHAR(100) NULL,
        TaxNumber       NVARCHAR(100) NULL,
        Status          TINYINT       NOT NULL DEFAULT 2,  -- 0=Active,1=Suspended,2=Trial,3=Expired
        TrialEndsAt     DATETIME      NOT NULL DEFAULT DATEADD(DAY, 30, GETUTCDATE()),
        SubscriptionEndsAt DATETIME   NULL,
        PlanName        NVARCHAR(50)  NOT NULL DEFAULT 'Trial',
        MaxUsers        INT           NOT NULL DEFAULT 5,
        TimeZone        NVARCHAR(100) NOT NULL DEFAULT 'UTC',
        Currency        NVARCHAR(10)  NOT NULL DEFAULT 'INR',
        CurrencySymbol  NVARCHAR(5)   NOT NULL DEFAULT N'₹',
        CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt       DATETIME      NULL,
        CreatedBy       INT           NULL,
        UpdatedBy       INT           NULL,
        IsDeleted       BIT           NOT NULL DEFAULT 0
    );
END
GO

-- ============================================================
-- MASTER USERS TABLE
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'MasterUsers') AND type = 'U')
BEGIN
    CREATE TABLE MasterUsers (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId       INT           NOT NULL,
        FullName        NVARCHAR(150) NOT NULL,
        Email           NVARCHAR(150) NOT NULL UNIQUE,
        PasswordHash    NVARCHAR(500) NOT NULL,
        Role            TINYINT       NOT NULL DEFAULT 2,
        IsActive        BIT           NOT NULL DEFAULT 1,
        LastLoginAt     DATETIME      NULL,
        ProfileImageUrl NVARCHAR(500) NULL,
        CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt       DATETIME      NULL,
        CreatedBy       INT           NULL,
        UpdatedBy       INT           NULL,
        IsDeleted       BIT           NOT NULL DEFAULT 0,
        TenantRoleId    INT           NULL,
        CONSTRAINT FK_MasterUsers_Company FOREIGN KEY (CompanyId) REFERENCES Companies(Id)
    );
END
GO

-- Add TenantRoleId to existing MasterUsers table if missing
IF COL_LENGTH('MasterUsers','TenantRoleId') IS NULL
    ALTER TABLE MasterUsers ADD TenantRoleId INT NULL;
GO

-- Add configurable number prefixes (idempotent)
IF COL_LENGTH('Companies','LeadPrefix') IS NULL
    ALTER TABLE Companies ADD LeadPrefix NVARCHAR(20) NOT NULL DEFAULT 'LD';
GO
IF COL_LENGTH('Companies','PackagePrefix') IS NULL
    ALTER TABLE Companies ADD PackagePrefix NVARCHAR(20) NOT NULL DEFAULT 'PKG';
GO

-- ============================================================
-- SUBSCRIPTION PLANS TABLE
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'SubscriptionPlans') AND type = 'U')
BEGIN
    CREATE TABLE SubscriptionPlans (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        Name            NVARCHAR(50)  NOT NULL,
        MonthlyPrice    DECIMAL(10,2) NOT NULL DEFAULT 0,
        YearlyPrice     DECIMAL(10,2) NOT NULL DEFAULT 0,
        MaxUsers        INT           NOT NULL DEFAULT 5,
        Features        NVARCHAR(MAX) NULL,
        IsActive        BIT           NOT NULL DEFAULT 1,
        CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE()
    );

    INSERT INTO SubscriptionPlans (Name, MonthlyPrice, YearlyPrice, MaxUsers, Features) VALUES
    ('Trial',      0,       0,        5,   'Basic features, 5 users, 30 days'),
    ('Starter',    29.99,   299.99,   10,  'All modules, 10 users, email support'),
    ('Business',   79.99,   799.99,   50,  'All modules, 50 users, priority support, custom reports'),
    ('Enterprise', 199.99,  1999.99,  999, 'Unlimited users, white-label, dedicated support');
END
GO

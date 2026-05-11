-- ============================================================
-- TENANT DB SCHEMA
-- Run against each tenant DB (TravelERP_Client1, etc.)
-- ============================================================

-- ============================================================
-- ROLES
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Roles') AND type = 'U')
BEGIN
    CREATE TABLE Roles (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        RoleName    NVARCHAR(100)  NOT NULL,
        Description NVARCHAR(300)  NULL,
        IsSystem    BIT            NOT NULL DEFAULT 0,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- ROLE PERMISSIONS
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RolePermissions') AND type = 'U')
BEGIN
    CREATE TABLE RolePermissions (
        Id        INT IDENTITY(1,1) PRIMARY KEY,
        RoleId    INT           NOT NULL,
        Module    NVARCHAR(50)  NOT NULL,
        CanView   BIT           NOT NULL DEFAULT 0,
        CanAdd    BIT           NOT NULL DEFAULT 0,
        CanEdit   BIT           NOT NULL DEFAULT 0,
        CanDelete BIT           NOT NULL DEFAULT 0,
        CONSTRAINT FK_RolePerm_Role FOREIGN KEY (RoleId) REFERENCES Roles(Id) ON DELETE CASCADE,
        CONSTRAINT UQ_RolePerm_Module UNIQUE (RoleId, Module)
    );
END
GO

-- ============================================================
-- DESTINATIONS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Destinations') AND type = 'U')
BEGIN
    CREATE TABLE Destinations (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        Name            NVARCHAR(200)  NOT NULL,
        ImageUrl        NVARCHAR(500)  NULL,
        PackageTerms    NVARCHAR(MAX)  NULL,
        InvoiceTerms    NVARCHAR(MAX)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL
    );
    CREATE INDEX IX_Destinations_Name ON Destinations(Name);
END
GO

-- ============================================================
-- DESTINATION REVIEWS (1-to-many)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'DestinationReviews') AND type = 'U')
BEGIN
    CREATE TABLE DestinationReviews (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        DestinationId   INT            NOT NULL,
        TravelerName    NVARCHAR(200)  NOT NULL,
        ImageUrl        NVARCHAR(500)  NULL,
        ReviewText      NVARCHAR(MAX)  NULL,
        DisplayOrder    INT            NOT NULL DEFAULT 0,
        CONSTRAINT FK_DestReview_Dest FOREIGN KEY (DestinationId)
            REFERENCES Destinations(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_DestReview_Dest ON DestinationReviews(DestinationId);
END
GO

-- ============================================================
-- ROOM TYPES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RoomTypes') AND type = 'U')
BEGIN
    CREATE TABLE RoomTypes (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Name        NVARCHAR(100)  NOT NULL,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- HOTELS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Hotels') AND type = 'U')
BEGIN
    CREATE TABLE Hotels (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        DestinationId   INT            NOT NULL,
        Name            NVARCHAR(200)  NOT NULL,
        Category        TINYINT        NOT NULL DEFAULT 3,  -- 1..5 stars
        ImageUrl        NVARCHAR(500)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Hotels_Destination FOREIGN KEY (DestinationId)
            REFERENCES Destinations(Id)
    );
    CREATE INDEX IX_Hotels_Destination ON Hotels(DestinationId);
END
GO

-- ============================================================
-- SIGHTSEEINGS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Sightseeings') AND type = 'U')
BEGIN
    CREATE TABLE Sightseeings (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        DestinationId   INT            NOT NULL,
        Name            NVARCHAR(200)  NOT NULL,
        ImageUrl        NVARCHAR(500)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Sightseeings_Destination FOREIGN KEY (DestinationId)
            REFERENCES Destinations(Id)
    );
    CREATE INDEX IX_Sightseeings_Destination ON Sightseeings(DestinationId);
END
GO

-- ============================================================
-- ITINERARIES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Itineraries') AND type = 'U')
BEGIN
    CREATE TABLE Itineraries (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        DestinationId   INT            NOT NULL,
        Title           NVARCHAR(300)  NOT NULL,
        Description     NVARCHAR(MAX)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Itineraries_Destination FOREIGN KEY (DestinationId)
            REFERENCES Destinations(Id)
    );
    CREATE INDEX IX_Itineraries_Destination ON Itineraries(DestinationId);
END
GO

-- ============================================================
-- DESIGNATIONS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Designations') AND type = 'U')
BEGIN
    CREATE TABLE Designations (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Name        NVARCHAR(100)  NOT NULL,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- LEAD SOURCES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'LeadSources') AND type = 'U')
BEGIN
    CREATE TABLE LeadSources (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Name        NVARCHAR(100)  NOT NULL,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- VISA TYPES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'VisaTypes') AND type = 'U')
BEGIN
    CREATE TABLE VisaTypes (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Name        NVARCHAR(150)  NOT NULL,
        Country     NVARCHAR(100)  NULL,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- MAIL TEMPLATES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'MailTemplates') AND type = 'U')
BEGIN
    CREATE TABLE MailTemplates (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Name        NVARCHAR(150)  NOT NULL,
        Subject     NVARCHAR(300)  NOT NULL,
        Body        NVARCHAR(MAX)  NULL,
        Category    NVARCHAR(50)   NULL,   -- Booking, Invoice, Payment, Welcome, Other
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- MEAL PLANS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'MealPlans') AND type = 'U')
BEGIN
    CREATE TABLE MealPlans (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        Code        NVARCHAR(10)   NOT NULL,
        Name        NVARCHAR(100)  NOT NULL,
        IsActive    BIT            NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy   INT            NOT NULL DEFAULT 0,
        UpdatedAt   DATETIME2      NULL,
        UpdatedBy   INT            NULL
    );
END
GO

-- ============================================================
-- BANK ACCOUNTS (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BankAccounts') AND type = 'U')
BEGIN
    CREATE TABLE BankAccounts (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        BankName        NVARCHAR(150)  NOT NULL,
        HolderName      NVARCHAR(150)  NOT NULL,
        AccountNumber   NVARCHAR(50)   NOT NULL,
        IfscCode        NVARCHAR(20)   NULL,
        Branch          NVARCHAR(150)  NULL,
        AccountType     NVARCHAR(20)   NULL,    -- Savings / Current / OD
        UpiId           NVARCHAR(100)  NULL,
        IsDefault       BIT            NOT NULL DEFAULT 0,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL
    );
END
GO

-- ============================================================
-- LEAD STATUSES (Master)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'LeadStatuses') AND type = 'U')
BEGIN
    CREATE TABLE LeadStatuses (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        Name            NVARCHAR(100)  NOT NULL,
        Color           NVARCHAR(20)   NOT NULL DEFAULT 'secondary',  -- bootstrap variant
        DisplayOrder    INT            NOT NULL DEFAULT 0,
        IsDefault       BIT            NOT NULL DEFAULT 0,
        IsClosed        BIT            NOT NULL DEFAULT 0,    -- terminal status (Converted/Lost)
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL
    );
END
GO

-- ============================================================
-- LEADS (operational) — depends on LeadStatuses, LeadSources, Destinations
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Leads') AND type = 'U')
BEGIN
    CREATE TABLE Leads (
        Id                  INT IDENTITY(1,1) PRIMARY KEY,
        LeadNumber          NVARCHAR(30)   NOT NULL,                       -- e.g. LD-2026-0001
        StatusId            INT            NULL,                           -- FK → LeadStatuses
        SourceId            INT            NULL,                           -- FK → LeadSources
        AssignedToUserId    INT            NULL,                           -- MasterUsers.Id (cross-DB, loose)
        DestinationId       INT            NULL,                           -- FK → Destinations

        Name                NVARCHAR(150)  NOT NULL,
        Mobile              NVARCHAR(30)   NULL,
        Email               NVARCHAR(150)  NULL,

        TravelingDate       DATE           NULL,
        LeavingFrom         NVARCHAR(150)  NULL,
        HotelRecommended    NVARCHAR(200)  NULL,

        Adults              INT            NOT NULL DEFAULT 1,
        Children            INT            NOT NULL DEFAULT 0,
        Infants             INT            NOT NULL DEFAULT 0,
        Days                INT            NULL,

        Remark              NVARCHAR(MAX)  NULL,

        IsActive            BIT            NOT NULL DEFAULT 1,
        CreatedAt           DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy           INT            NOT NULL DEFAULT 0,
        UpdatedAt           DATETIME2      NULL,
        UpdatedBy           INT            NULL,

        CONSTRAINT FK_Leads_Status      FOREIGN KEY (StatusId)      REFERENCES LeadStatuses(Id),
        CONSTRAINT FK_Leads_Source      FOREIGN KEY (SourceId)      REFERENCES LeadSources(Id),
        CONSTRAINT FK_Leads_Destination FOREIGN KEY (DestinationId) REFERENCES Destinations(Id),
        CONSTRAINT UQ_Leads_LeadNumber  UNIQUE (LeadNumber)
    );
    CREATE INDEX IX_Leads_Status   ON Leads(StatusId);
    CREATE INDEX IX_Leads_Assigned ON Leads(AssignedToUserId);
    CREATE INDEX IX_Leads_Created  ON Leads(CreatedAt DESC);
END
GO

-- ============================================================
-- LEAD ACTIVITIES (timeline: notes, calls, emails, follow-ups, status changes)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'LeadActivities') AND type = 'U')
BEGIN
    CREATE TABLE LeadActivities (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        LeadId          INT             NOT NULL,
        ActivityType    NVARCHAR(30)    NOT NULL,        -- Call/Email/WhatsApp/Meeting/Note/StatusChange
        Subject         NVARCHAR(200)   NULL,
        Notes           NVARCHAR(MAX)   NULL,
        ActivityAt      DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
        NextFollowUpAt  DATETIME2       NULL,                  -- if set, schedules a future activity
        IsCompleted     BIT             NOT NULL DEFAULT 1,    -- 0 only when scheduled in the future
        CreatedByUserId INT             NOT NULL DEFAULT 0,    -- MasterUsers.Id (cross-DB, loose)
        CreatedAt       DATETIME2       NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt       DATETIME2       NULL,

        CONSTRAINT FK_LeadActivity_Lead FOREIGN KEY (LeadId)
            REFERENCES Leads(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_LeadActivity_Lead       ON LeadActivities(LeadId, ActivityAt DESC);
    CREATE INDEX IX_LeadActivity_NextFollow ON LeadActivities(NextFollowUpAt);
END
GO

-- ============================================================
-- ACTIVITY TEMPLATES (predefined log snippets for fast follow-up entry)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ActivityTemplates') AND type = 'U')
BEGIN
    CREATE TABLE ActivityTemplates (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        Name            NVARCHAR(150)  NOT NULL,        -- short label shown in dropdown
        ActivityType    NVARCHAR(30)   NOT NULL DEFAULT 'All',  -- All/Call/Email/WhatsApp/Meeting/Note/FollowUp
        Subject         NVARCHAR(200)  NULL,
        Notes           NVARCHAR(MAX)  NULL,
        DisplayOrder    INT            NOT NULL DEFAULT 0,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL
    );
END
GO

-- ============================================================
-- EMPLOYEES (Master)
-- Loose link to MasterUsers via UserId (not enforced — cross-DB)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Employees') AND type = 'U')
BEGIN
    CREATE TABLE Employees (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        UserId          INT            NULL,           -- MasterUsers.Id (cross-DB, loose)
        DesignationId   INT            NULL,
        FirstName       NVARCHAR(100)  NOT NULL,
        LastName        NVARCHAR(100)  NULL,
        Email           NVARCHAR(150)  NOT NULL,       -- CRM Login
        Mobile          NVARCHAR(30)   NULL,
        DateOfBirth     DATE           NULL,
        ImageUrl        NVARCHAR(500)  NULL,
        ReplyEmail      NVARCHAR(150)  NULL,           -- Mail Id (To get travelers reply)
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Employees_Designation FOREIGN KEY (DesignationId)
            REFERENCES Designations(Id)
    );
    CREATE INDEX IX_Employees_UserId ON Employees(UserId);
END
GO

-- ============================================================
-- PACKAGES (operational — quotes/itineraries with multiple price options)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Packages') AND type = 'U')
BEGIN
    CREATE TABLE Packages (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        PackageNumber   NVARCHAR(40)   NOT NULL,            -- e.g. PKG-2026-0001
        ShareToken      NVARCHAR(64)   NULL,                -- random token for public web view
        LeadId          INT            NULL,                -- nullable: standalone or from-lead
        Title           NVARCHAR(200)  NOT NULL,
        DestinationId   INT            NULL,
        CustomerName    NVARCHAR(150)  NOT NULL,
        CustomerMobile  NVARCHAR(30)   NULL,
        CustomerEmail   NVARCHAR(150)  NULL,
        Adults          INT            NOT NULL DEFAULT 1,
        Children        INT            NOT NULL DEFAULT 0,
        Infants         INT            NOT NULL DEFAULT 0,
        Days            INT            NULL,
        Nights          INT            NULL,
        StartDate       DATE           NULL,
        PriceMode       NVARCHAR(20)   NOT NULL DEFAULT 'Total',  -- Total / PerPax
        Currency        NVARCHAR(10)   NOT NULL DEFAULT 'INR',
        FlightDetails   NVARCHAR(MAX)  NULL,
        Inclusions      NVARCHAR(MAX)  NULL,
        Exclusions      NVARCHAR(MAX)  NULL,
        Notes           NVARCHAR(MAX)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Packages_Lead        FOREIGN KEY (LeadId)        REFERENCES Leads(Id),
        CONSTRAINT FK_Packages_Destination FOREIGN KEY (DestinationId) REFERENCES Destinations(Id),
        CONSTRAINT UQ_Packages_PackageNumber UNIQUE (PackageNumber)
    );
    CREATE INDEX IX_Packages_Lead    ON Packages(LeadId);
    CREATE INDEX IX_Packages_Created ON Packages(CreatedAt DESC);
END
GO

-- Add ShareToken to existing Packages tables (idempotent)
IF COL_LENGTH('Packages','ShareToken') IS NULL
BEGIN
    ALTER TABLE Packages ADD ShareToken NVARCHAR(64) NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UQ_Packages_ShareToken' AND object_id = OBJECT_ID('Packages'))
BEGIN
    CREATE UNIQUE INDEX UQ_Packages_ShareToken
        ON Packages(ShareToken) WHERE ShareToken IS NOT NULL;
END
GO

-- ============================================================
-- PACKAGE OPTIONS (Standard/Deluxe/Luxury price tiers per package)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PackageOptions') AND type = 'U')
BEGIN
    CREATE TABLE PackageOptions (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        PackageId       INT            NOT NULL,
        OptionName      NVARCHAR(150)  NOT NULL,
        DisplayOrder    INT            NOT NULL DEFAULT 0,
        LandPrice       DECIMAL(18,2)  NOT NULL DEFAULT 0,
        FlightPrice     DECIMAL(18,2)  NOT NULL DEFAULT 0,
        FinalPrice      DECIMAL(18,2)  NOT NULL DEFAULT 0,
        IsRecommended   BIT            NOT NULL DEFAULT 0,
        Notes           NVARCHAR(MAX)  NULL,
        CONSTRAINT FK_PackageOption_Package FOREIGN KEY (PackageId)
            REFERENCES Packages(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_PackageOption_Package ON PackageOptions(PackageId, DisplayOrder);
END
GO

-- ============================================================
-- PACKAGE OPTION HOTELS (per-option hotel breakdown)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PackageOptionHotels') AND type = 'U')
BEGIN
    CREATE TABLE PackageOptionHotels (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        PackageOptionId   INT            NOT NULL,
        DisplayOrder      INT            NOT NULL DEFAULT 0,
        Nights            INT            NOT NULL DEFAULT 1,
        HotelId           INT            NULL,
        RoomTypeId        INT            NULL,
        MealPlanId        INT            NULL,
        OtherText         NVARCHAR(300)  NULL,             -- free text notes per row
        CONSTRAINT FK_POH_Option   FOREIGN KEY (PackageOptionId) REFERENCES PackageOptions(Id) ON DELETE CASCADE,
        CONSTRAINT FK_POH_Hotel    FOREIGN KEY (HotelId)         REFERENCES Hotels(Id),
        CONSTRAINT FK_POH_RoomType FOREIGN KEY (RoomTypeId)      REFERENCES RoomTypes(Id),
        CONSTRAINT FK_POH_MealPlan FOREIGN KEY (MealPlanId)      REFERENCES MealPlans(Id)
    );
    CREATE INDEX IX_POH_Option ON PackageOptionHotels(PackageOptionId, DisplayOrder);
END
GO

-- Roles: data-scope flag (idempotent — defaults to 0 = "All data")
IF COL_LENGTH('Roles','OnlyAssigned') IS NULL
    ALTER TABLE Roles ADD OnlyAssigned BIT NOT NULL DEFAULT 0;
GO

-- Voucher-specific extras (idempotent — safe to re-run)
IF COL_LENGTH('PackageOptionHotels','Rooms')        IS NULL ALTER TABLE PackageOptionHotels ADD Rooms        INT NOT NULL DEFAULT 1;
IF COL_LENGTH('PackageOptionHotels','ExtraBeds')    IS NULL ALTER TABLE PackageOptionHotels ADD ExtraBeds    INT NOT NULL DEFAULT 0;
IF COL_LENGTH('PackageOptionHotels','HotelCnfNo')   IS NULL ALTER TABLE PackageOptionHotels ADD HotelCnfNo   NVARCHAR(60) NULL;
GO

-- Bookings.PackageOptionId FK: relax to ON DELETE SET NULL so editing a package
-- (which delete-and-replaces its options) doesn't blow up on existing bookings.
-- OptionName is denormalized on the Booking row, so historical data is preserved.
-- Guarded so brand-new tenant DBs (where Bookings hasn't been created yet at this
-- point in the script) skip these ALTERs cleanly — the CREATE TABLE below already
-- declares the FK with ON DELETE SET NULL.
IF OBJECT_ID(N'Bookings', 'U') IS NOT NULL
    AND EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Bookings_PackageOption')
    ALTER TABLE Bookings DROP CONSTRAINT FK_Bookings_PackageOption;
GO
IF OBJECT_ID(N'Bookings', 'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Bookings_PackageOption')
    ALTER TABLE Bookings ADD CONSTRAINT FK_Bookings_PackageOption
        FOREIGN KEY (PackageOptionId) REFERENCES PackageOptions(Id) ON DELETE SET NULL;
GO

-- ============================================================
-- PACKAGE DAYS (day-wise itinerary; shared across options)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PackageDays') AND type = 'U')
BEGIN
    CREATE TABLE PackageDays (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        PackageId     INT            NOT NULL,
        DayNumber     INT            NOT NULL,
        Title         NVARCHAR(200)  NOT NULL,
        Description   NVARCHAR(MAX)  NULL,
        CONSTRAINT FK_PackageDay_Package FOREIGN KEY (PackageId)
            REFERENCES Packages(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_PackageDay_Package ON PackageDays(PackageId, DayNumber);
END
GO

-- ============================================================
-- PACKAGE DAY SIGHTSEEINGS (many-to-many)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PackageDaySightseeings') AND type = 'U')
BEGIN
    CREATE TABLE PackageDaySightseeings (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        PackageDayId    INT NOT NULL,
        SightseeingId   INT NOT NULL,
        CONSTRAINT FK_PDS_Day         FOREIGN KEY (PackageDayId)  REFERENCES PackageDays(Id) ON DELETE CASCADE,
        CONSTRAINT FK_PDS_Sightseeing FOREIGN KEY (SightseeingId) REFERENCES Sightseeings(Id)
    );
    CREATE INDEX IX_PDS_Day ON PackageDaySightseeings(PackageDayId);
END
GO

-- ============================================================
-- EMAIL LOGS  — outbound email audit trail
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'EmailLogs') AND type = 'U')
BEGIN
    CREATE TABLE EmailLogs (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        RelatedType     NVARCHAR(20)  NOT NULL,                  -- 'Package' | 'Booking' | 'Other'
        RelatedId       INT           NULL,
        ToEmail         NVARCHAR(500) NOT NULL,
        CcEmail         NVARCHAR(500) NULL,
        Subject         NVARCHAR(500) NOT NULL,
        BodyPreview     NVARCHAR(1000) NULL,                     -- first ~1000 chars of body for the audit panel
        AttachmentNames NVARCHAR(500) NULL,                      -- comma-separated file names
        Status          NVARCHAR(20)  NOT NULL DEFAULT 'Sent',   -- 'Sent' | 'Failed'
        ErrorMessage    NVARCHAR(MAX) NULL,
        SentAt          DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
        SentBy          INT           NOT NULL DEFAULT 0
    );
    CREATE INDEX IX_EmailLogs_Related ON EmailLogs(RelatedType, RelatedId, SentAt DESC);
END
GO

-- ============================================================
-- BOOKINGS  — confirmed sale, links back to a chosen Package Option
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Bookings') AND type = 'U')
BEGIN
    CREATE TABLE Bookings (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        BookingNumber   NVARCHAR(40)   NOT NULL,                        -- e.g. BK-2026-0001
        InvoiceNumber   NVARCHAR(40)   NOT NULL,                        -- e.g. INV-2026-0001 (issued at booking time)
        LeadId          INT            NULL,
        PackageId       INT            NULL,
        PackageOptionId INT            NULL,
        OptionName      NVARCHAR(150)  NULL,                            -- denormalized snapshot of which option was sold
        CustomerName    NVARCHAR(150)  NOT NULL,
        CustomerMobile  NVARCHAR(30)   NULL,
        CustomerEmail   NVARCHAR(150)  NULL,
        Adults          INT            NOT NULL DEFAULT 1,
        Children        INT            NOT NULL DEFAULT 0,
        Infants         INT            NOT NULL DEFAULT 0,
        StartDate       DATE           NULL,
        EndDate         DATE           NULL,
        Days            INT            NULL,
        Nights          INT            NULL,
        DestinationId   INT            NULL,
        TotalAmount     DECIMAL(18,2)  NOT NULL DEFAULT 0,              -- locked-in price at booking time
        Currency        NVARCHAR(10)   NOT NULL DEFAULT 'INR',
        Status          NVARCHAR(20)   NOT NULL DEFAULT 'Confirmed',    -- Confirmed / Cancelled / Completed
        Notes           NVARCHAR(MAX)  NULL,
        IsActive        BIT            NOT NULL DEFAULT 1,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_Bookings_Lead          FOREIGN KEY (LeadId)          REFERENCES Leads(Id),
        CONSTRAINT FK_Bookings_Package       FOREIGN KEY (PackageId)       REFERENCES Packages(Id),
        CONSTRAINT FK_Bookings_PackageOption FOREIGN KEY (PackageOptionId) REFERENCES PackageOptions(Id) ON DELETE SET NULL,
        CONSTRAINT FK_Bookings_Destination   FOREIGN KEY (DestinationId)   REFERENCES Destinations(Id),
        CONSTRAINT UQ_Bookings_BookingNumber UNIQUE (BookingNumber),
        CONSTRAINT UQ_Bookings_InvoiceNumber UNIQUE (InvoiceNumber)
    );
    CREATE INDEX IX_Bookings_Lead    ON Bookings(LeadId);
    CREATE INDEX IX_Bookings_Package ON Bookings(PackageId);
    CREATE INDEX IX_Bookings_Created ON Bookings(CreatedAt DESC);
END
GO

-- ============================================================
-- BOOKING HOTELS  — snapshot of the package option's hotels at booking time
-- (the booking owns its hotel rows so editing the source package later
--  doesn't blow away the voucher data).
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BookingHotels') AND type = 'U')
BEGIN
    CREATE TABLE BookingHotels (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        BookingId       INT            NOT NULL,
        DisplayOrder    INT            NOT NULL DEFAULT 0,
        Nights          INT            NOT NULL DEFAULT 1,
        HotelName       NVARCHAR(200)  NULL,
        RoomTypeName    NVARCHAR(100)  NULL,
        MealPlanCode    NVARCHAR(10)   NULL,
        MealPlanName    NVARCHAR(100)  NULL,
        OtherText       NVARCHAR(300)  NULL,
        Rooms           INT            NOT NULL DEFAULT 1,
        ExtraBeds       INT            NOT NULL DEFAULT 0,
        HotelCnfNo      NVARCHAR(60)   NULL,
        CONSTRAINT FK_BookingHotels_Booking FOREIGN KEY (BookingId)
            REFERENCES Bookings(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_BookingHotels_Booking ON BookingHotels(BookingId, DisplayOrder);
END
GO

-- ============================================================
-- BOOKING INSTALLMENTS  — payment plan rows
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'BookingInstallments') AND type = 'U')
BEGIN
    CREATE TABLE BookingInstallments (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        BookingId       INT            NOT NULL,
        InstallmentNo   INT            NOT NULL,
        Amount          DECIMAL(18,2)  NOT NULL DEFAULT 0,
        PaymentMode     NVARCHAR(50)   NULL,            -- Cash / UPI / NEFT / RTGS / Card / Cheque / Other
        PaymentStatus   NVARCHAR(20)   NOT NULL DEFAULT 'Pending',  -- Pending / Received / Refunded
        DueDate         DATE           NULL,
        ReceivedDate    DATE           NULL,
        Remark          NVARCHAR(500)  NULL,
        CreatedAt       DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy       INT            NOT NULL DEFAULT 0,
        UpdatedAt       DATETIME2      NULL,
        UpdatedBy       INT            NULL,
        CONSTRAINT FK_BookingInstallments_Booking FOREIGN KEY (BookingId)
            REFERENCES Bookings(Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_BookingInstallments_Booking ON BookingInstallments(BookingId);
END
GO

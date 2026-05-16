-- ============================================================
-- TRAVEL ERP — MASTER DATABASE STORED PROCEDURES
-- Only procedures that have active repos/controllers
-- ============================================================

USE TravelERP_Master;
GO

-- Required for procedures that touch tables with filtered indexes
-- (e.g. UQ_Packages_ShareToken) — these settings get baked into each
-- procedure at CREATE time, so every CREATE OR ALTER below inherits them.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ============================================================
-- CLIENT DB NAME GENERATOR
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Company_GenerateDbName
    @DatabaseName NVARCHAR(100) OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DELETE FROM ClientSequence WHERE CompanyId IS NULL;
    DECLARE @nextId INT;
    INSERT INTO ClientSequence (DatabaseName) VALUES ('__PENDING__');
    SET @nextId = SCOPE_IDENTITY();
    SET @DatabaseName = 'TravelERP_Client' + CAST(@nextId AS NVARCHAR(10));
    UPDATE ClientSequence SET DatabaseName = @DatabaseName WHERE Id = @nextId;
END
GO

-- ============================================================
-- COMPANY PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Company_GetById
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Companies WHERE Id = @Id AND IsDeleted = 0;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_GetBySlug
    @Slug NVARCHAR(50)
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Companies WHERE Slug = @Slug AND IsDeleted = 0;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_GetAll
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Companies WHERE IsDeleted = 0 ORDER BY Name;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_Insert
    @Name            NVARCHAR(150),
    @Slug            NVARCHAR(50),
    @DatabaseName    NVARCHAR(100),
    @Email           NVARCHAR(150),
    @Phone           NVARCHAR(30),
    @Address         NVARCHAR(300) = NULL,
    @City            NVARCHAR(100) = NULL,
    @Country         NVARCHAR(100),
    @LogoUrl         NVARCHAR(500) = NULL,
    @LicenseNumber   NVARCHAR(100) = NULL,
    @TaxNumber       NVARCHAR(100) = NULL,
    @Status          TINYINT       = 2,
    @TrialEndsAt     DATETIME,
    @SubscriptionEndsAt DATETIME   = NULL,
    @PlanName        NVARCHAR(50)  = 'Trial',
    @MaxUsers        INT           = 5,
    @TimeZone        NVARCHAR(100) = 'UTC',
    @Currency        NVARCHAR(10)  = 'INR',
    @CurrencySymbol  NVARCHAR(5)   = N'₹',
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());
    INSERT INTO Companies (Name, Slug, DatabaseName, Email, Phone, Address, City, Country,
        LogoUrl, LicenseNumber, TaxNumber, Status, TrialEndsAt, SubscriptionEndsAt,
        PlanName, MaxUsers, TimeZone, Currency, CurrencySymbol, CreatedAt, CreatedBy, IsDeleted)
    VALUES (@Name, @Slug, @DatabaseName, @Email, @Phone, @Address, @City, @Country,
        @LogoUrl, @LicenseNumber, @TaxNumber, @Status, @TrialEndsAt, @SubscriptionEndsAt,
        @PlanName, @MaxUsers, @TimeZone, @Currency, @CurrencySymbol, @CreatedAt, @CreatedBy, 0);
    SET @NewId = SCOPE_IDENTITY();
    UPDATE ClientSequence SET CompanyId = @NewId WHERE DatabaseName = @DatabaseName;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_Update
    @Id              INT,
    @Name            NVARCHAR(150),
    @Email           NVARCHAR(150),
    @Phone           NVARCHAR(30),
    @Address         NVARCHAR(300) = NULL,
    @City            NVARCHAR(100) = NULL,
    @Country         NVARCHAR(100),
    @LogoUrl         NVARCHAR(500) = NULL,
    @LicenseNumber   NVARCHAR(100) = NULL,
    @TaxNumber       NVARCHAR(100) = NULL,
    @Status          TINYINT,
    @SubscriptionEndsAt DATETIME   = NULL,
    @PlanName        NVARCHAR(50),
    @MaxUsers        INT,
    @TimeZone        NVARCHAR(100),
    @Currency        NVARCHAR(10),
    @CurrencySymbol  NVARCHAR(5),
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());
    UPDATE Companies SET
        Name=@Name, Email=@Email, Phone=@Phone, Address=@Address, City=@City, Country=@Country,
        LogoUrl=@LogoUrl, LicenseNumber=@LicenseNumber, TaxNumber=@TaxNumber, Status=@Status,
        SubscriptionEndsAt=@SubscriptionEndsAt, PlanName=@PlanName, MaxUsers=@MaxUsers,
        TimeZone=@TimeZone, Currency=@Currency, CurrencySymbol=@CurrencySymbol,
        UpdatedAt=@UpdatedAt, UpdatedBy=@UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateEmailSettings
    @Id            INT,
    @SmtpHost      NVARCHAR(200) = NULL,
    @SmtpPort      INT           = NULL,
    @SmtpUsername  NVARCHAR(200) = NULL,
    @SmtpPassword  NVARCHAR(500) = NULL,
    @SmtpFromEmail NVARCHAR(200) = NULL,
    @SmtpFromName  NVARCHAR(150) = NULL,
    @SmtpUseTls    BIT           = 1,
    @UpdatedBy     INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        SmtpHost      = @SmtpHost,
        SmtpPort      = @SmtpPort,
        SmtpUsername  = @SmtpUsername,
        SmtpPassword  = @SmtpPassword,
        SmtpFromEmail = @SmtpFromEmail,
        SmtpFromName  = @SmtpFromName,
        SmtpUseTls    = @SmtpUseTls,
        UpdatedAt     = GETUTCDATE(),
        UpdatedBy     = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateQuoteBranding
    @Id                INT,
    @GreetingParagraph NVARCHAR(MAX) = NULL,
    @WhyBookWithUs     NVARCHAR(MAX) = NULL,
    @LogoUrl           NVARCHAR(500) = NULL,
    @UpdateLogo        BIT           = 0,    -- only overwrite LogoUrl when true
    @GooglePlaceId     NVARCHAR(255) = NULL,
    @GoogleApiKey      NVARCHAR(255) = NULL,
    @UpdatedBy         INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    -- If Place ID changed, drop the cache so the next public view fetches fresh.
    DECLARE @clearCache BIT = CASE
        WHEN ISNULL((SELECT GooglePlaceId FROM Companies WHERE Id = @Id), '') <> ISNULL(@GooglePlaceId, '') THEN 1
        ELSE 0
    END;

    UPDATE Companies SET
        GreetingParagraph      = @GreetingParagraph,
        WhyBookWithUs          = @WhyBookWithUs,
        LogoUrl                = CASE WHEN @UpdateLogo = 1 THEN @LogoUrl ELSE LogoUrl END,
        GooglePlaceId          = @GooglePlaceId,
        GoogleApiKey           = @GoogleApiKey,
        GoogleReviewsCacheJson = CASE WHEN @clearCache = 1 THEN NULL ELSE GoogleReviewsCacheJson END,
        GoogleReviewsCachedAt  = CASE WHEN @clearCache = 1 THEN NULL ELSE GoogleReviewsCachedAt  END,
        UpdatedAt              = GETUTCDATE(),
        UpdatedBy              = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateGoogleReviewsCache
    @Id        INT,
    @CacheJson NVARCHAR(MAX) = NULL,
    @CachedAt  DATETIME2     = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        GoogleReviewsCacheJson = @CacheJson,
        GoogleReviewsCachedAt  = @CachedAt
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateVoucherDefaults
    @Id                  INT,
    @VoucherCheckInTime  NVARCHAR(20)  = NULL,
    @VoucherCheckOutTime NVARCHAR(20)  = NULL,
    @VoucherHotelNote    NVARCHAR(MAX) = NULL,
    @VoucherPolicyHtml   NVARCHAR(MAX) = NULL,
    @UpdatedBy           INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        VoucherCheckInTime  = @VoucherCheckInTime,
        VoucherCheckOutTime = @VoucherCheckOutTime,
        VoucherHotelNote    = @VoucherHotelNote,
        VoucherPolicyHtml   = @VoucherPolicyHtml,
        UpdatedAt           = GETUTCDATE(),
        UpdatedBy           = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateProfile
    @Id              INT,
    @Name            NVARCHAR(200),
    @Email           NVARCHAR(150) = NULL,
    @Phone           NVARCHAR(50)  = NULL,
    @Address         NVARCHAR(500) = NULL,
    @City            NVARCHAR(100) = NULL,
    @Country         NVARCHAR(100) = NULL,
    @LicenseNumber   NVARCHAR(100) = NULL,
    @TaxNumber       NVARCHAR(100) = NULL,
    @TimeZone        NVARCHAR(100) = NULL,
    @Currency        NVARCHAR(10)  = NULL,
    @CurrencySymbol  NVARCHAR(10)  = NULL,
    @RequireOtpLogin BIT           = 0,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        Name            = @Name,
        Email           = ISNULL(@Email, ''),
        Phone           = ISNULL(@Phone, ''),
        Address         = ISNULL(@Address, ''),
        City            = ISNULL(@City, ''),
        Country         = ISNULL(@Country, ''),
        LicenseNumber   = ISNULL(@LicenseNumber, ''),
        TaxNumber       = ISNULL(@TaxNumber, ''),
        TimeZone        = ISNULL(@TimeZone, 'UTC'),
        Currency        = ISNULL(@Currency, 'INR'),
        CurrencySymbol  = ISNULL(@CurrencySymbol, N'₹'),
        RequireOtpLogin = @RequireOtpLogin,
        UpdatedAt       = GETUTCDATE(),
        UpdatedBy       = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateNumberSeries
    @Id            INT,
    @LeadPrefix    NVARCHAR(20),
    @PackagePrefix NVARCHAR(20),
    @BookingPrefix NVARCHAR(20) = 'BK',
    @InvoicePrefix NVARCHAR(20) = 'INV',
    @UpdatedBy     INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        LeadPrefix    = @LeadPrefix,
        PackagePrefix = @PackagePrefix,
        BookingPrefix = @BookingPrefix,
        InvoicePrefix = @InvoicePrefix,
        UpdatedAt     = GETUTCDATE(),
        UpdatedBy     = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_ExistsBySlug
    @Slug NVARCHAR(50)
AS BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(1) FROM Companies WHERE Slug = @Slug;
END
GO

-- ============================================================
-- USER PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_User_GetById
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM MasterUsers WHERE Id = @Id AND IsDeleted = 0;
END
GO

CREATE OR ALTER PROCEDURE sp_User_GetByEmail
    @Email NVARCHAR(150)
AS BEGIN
    SET NOCOUNT ON;
    SELECT u.*, c.Name AS CompanyName, c.DatabaseName, c.Currency,
           c.CurrencySymbol, c.Status AS CompanyStatus
    FROM MasterUsers u
    INNER JOIN Companies c ON u.CompanyId = c.Id
    WHERE u.Email = @Email AND u.IsDeleted = 0;
END
GO

CREATE OR ALTER PROCEDURE sp_User_GetByCompany
    @CompanyId INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM MasterUsers
    WHERE CompanyId = @CompanyId AND IsDeleted = 0
    ORDER BY FullName;
END
GO

CREATE OR ALTER PROCEDURE sp_User_Insert
    @CompanyId       INT,
    @FullName        NVARCHAR(150),
    @Email           NVARCHAR(150),
    @PasswordHash    NVARCHAR(500),
    @Role            TINYINT       = 2,
    @IsActive        BIT           = 1,
    @ProfileImageUrl NVARCHAR(500) = NULL,
    @Mobile          NVARCHAR(50)  = NULL,
    @DateOfBirth     DATE          = NULL,
    @ReplyEmail      NVARCHAR(200) = NULL,
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());
    INSERT INTO MasterUsers (CompanyId, FullName, Email, PasswordHash, Role, IsActive,
        ProfileImageUrl, Mobile, DateOfBirth, ReplyEmail,
        CreatedAt, CreatedBy, IsDeleted)
    VALUES (@CompanyId, @FullName, @Email, @PasswordHash, @Role, @IsActive,
        @ProfileImageUrl, @Mobile, @DateOfBirth, @ReplyEmail,
        @CreatedAt, @CreatedBy, 0);
    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_User_Update
    @Id              INT,
    @FullName        NVARCHAR(150),
    @Email           NVARCHAR(150),
    @Role            TINYINT,
    @IsActive        BIT,
    @ProfileImageUrl NVARCHAR(500) = NULL,
    @Mobile          NVARCHAR(50)  = NULL,
    @DateOfBirth     DATE          = NULL,
    @ReplyEmail      NVARCHAR(200) = NULL,
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());
    UPDATE MasterUsers SET
        FullName=@FullName, Email=@Email, Role=@Role, IsActive=@IsActive,
        ProfileImageUrl=@ProfileImageUrl,
        Mobile=@Mobile, DateOfBirth=@DateOfBirth, ReplyEmail=@ReplyEmail,
        UpdatedAt=@UpdatedAt, UpdatedBy=@UpdatedBy
    WHERE Id = @Id;
END
GO

-- Drop the legacy Employees-migration SP if it's still hanging around in master.
IF OBJECT_ID(N'sp_User_MigrateFromEmployees', 'P') IS NOT NULL
    DROP PROCEDURE sp_User_MigrateFromEmployees;
GO

CREATE OR ALTER PROCEDURE sp_User_UpdateLastLogin
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET LastLoginAt = GETUTCDATE() WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_User_ChangePassword
    @Id           INT,
    @PasswordHash NVARCHAR(500)
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET PasswordHash = @PasswordHash, UpdatedAt = GETUTCDATE() WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_User_SetTenantRole
    @Id           INT,
    @TenantRoleId INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET TenantRoleId = @TenantRoleId WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_User_Delete
    @Id        INT,
    @UpdatedBy INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET
        IsDeleted = 1, IsActive = 0,
        UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
    WHERE Id = @Id;
END
GO

-- ============================================================
-- OTP login — store hashed 6-digit code with TTL + attempts.
-- The code itself never leaves C# in plaintext after SetOtp returns.
-- ============================================================
CREATE OR ALTER PROCEDURE sp_User_SetOtp
    @Id        INT,
    @OtpHash   NVARCHAR(128),
    @ExpiresAt DATETIME2
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET
        OtpHash      = @OtpHash,
        OtpExpiresAt = @ExpiresAt,
        OtpIssuedAt  = GETUTCDATE(),
        OtpAttempts  = 0
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_User_ClearOtp
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET
        OtpHash      = NULL,
        OtpExpiresAt = NULL,
        OtpIssuedAt  = NULL,
        OtpAttempts  = 0
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_User_IncrementOtpAttempts
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE MasterUsers SET OtpAttempts = ISNULL(OtpAttempts, 0) + 1 WHERE Id = @Id;
    SELECT OtpAttempts FROM MasterUsers WHERE Id = @Id;
END
GO

-- ============================================================
-- ROLE PROCEDURES (cross-DB, tenant data)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Role_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Roles
        WHERE IsActive = 1 ORDER BY IsSystem DESC, RoleName';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Role_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Roles WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Role_Insert
    @DatabaseName NVARCHAR(100),
    @RoleName     NVARCHAR(100),
    @Description  NVARCHAR(300) = NULL,
    @IsSystem     BIT           = 0,
    @OnlyAssigned BIT           = 0,
    @CreatedBy    INT           = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Roles
            (RoleName, Description, IsSystem, OnlyAssigned, IsActive, CreatedAt, CreatedBy)
        VALUES (@RoleName, @Description, @IsSystem, @OnlyAssigned, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@RoleName NVARCHAR(100), @Description NVARCHAR(300), @IsSystem BIT, @OnlyAssigned BIT, @CreatedBy INT, @NewId INT OUTPUT',
        @RoleName, @Description, @IsSystem, @OnlyAssigned, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Role_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @RoleName     NVARCHAR(100),
    @Description  NVARCHAR(300) = NULL,
    @OnlyAssigned BIT           = 0,
    @UpdatedBy    INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Roles
        SET RoleName = @RoleName, Description = @Description, OnlyAssigned = @OnlyAssigned,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id AND IsSystem = 0';
    EXEC sp_executesql @sql,
        N'@Id INT, @RoleName NVARCHAR(100), @Description NVARCHAR(300), @OnlyAssigned BIT, @UpdatedBy INT',
        @Id, @RoleName, @Description, @OnlyAssigned, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Role_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Roles
        SET IsActive = 0 WHERE Id = @Id AND IsSystem = 0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_RolePermission_GetByRole
    @DatabaseName NVARCHAR(100),
    @RoleId       INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.RolePermissions WHERE RoleId = @RoleId';
    EXEC sp_executesql @sql, N'@RoleId INT', @RoleId;
END
GO

CREATE OR ALTER PROCEDURE sp_RolePermission_Upsert
    @DatabaseName NVARCHAR(100),
    @RoleId       INT,
    @Module       NVARCHAR(50),
    @CanView      BIT,
    @CanAdd       BIT,
    @CanEdit      BIT,
    @CanDelete    BIT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        IF EXISTS (SELECT 1 FROM [' + @DatabaseName + N'].dbo.RolePermissions
                   WHERE RoleId = @RoleId AND Module = @Module)
            UPDATE [' + @DatabaseName + N'].dbo.RolePermissions
            SET CanView=@CanView, CanAdd=@CanAdd, CanEdit=@CanEdit, CanDelete=@CanDelete
            WHERE RoleId = @RoleId AND Module = @Module
        ELSE
            INSERT INTO [' + @DatabaseName + N'].dbo.RolePermissions
                (RoleId, Module, CanView, CanAdd, CanEdit, CanDelete)
            VALUES (@RoleId, @Module, @CanView, @CanAdd, @CanEdit, @CanDelete)';
    EXEC sp_executesql @sql,
        N'@RoleId INT, @Module NVARCHAR(50), @CanView BIT, @CanAdd BIT, @CanEdit BIT, @CanDelete BIT',
        @RoleId, @Module, @CanView, @CanAdd, @CanEdit, @CanDelete;
END
GO

-- ============================================================
-- DESTINATION PROCEDURES (cross-DB, tenant data)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Destination_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Destinations
        WHERE IsActive = 1 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Destination_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Destinations WHERE Id = @Id;
        SELECT * FROM [' + @DatabaseName + N'].dbo.DestinationReviews
        WHERE DestinationId = @Id ORDER BY DisplayOrder, Id;';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Destination_Insert
    @DatabaseName  NVARCHAR(100),
    @Name          NVARCHAR(200),
    @ImageUrl      NVARCHAR(500) = NULL,
    @PackageTerms  NVARCHAR(MAX) = NULL,
    @InvoiceTerms  NVARCHAR(MAX) = NULL,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Destinations
            (Name, ImageUrl, PackageTerms, InvoiceTerms, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, @ImageUrl, @PackageTerms, @InvoiceTerms, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(200), @ImageUrl NVARCHAR(500), @PackageTerms NVARCHAR(MAX), @InvoiceTerms NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @ImageUrl, @PackageTerms, @InvoiceTerms, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Destination_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @Name          NVARCHAR(200),
    @ImageUrl      NVARCHAR(500) = NULL,
    @PackageTerms  NVARCHAR(MAX) = NULL,
    @InvoiceTerms  NVARCHAR(MAX) = NULL,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Destinations
        SET Name = @Name,
            ImageUrl = ISNULL(@ImageUrl, ImageUrl),
            PackageTerms = @PackageTerms,
            InvoiceTerms = @InvoiceTerms,
            UpdatedAt = GETUTCDATE(),
            UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(200), @ImageUrl NVARCHAR(500), @PackageTerms NVARCHAR(MAX), @InvoiceTerms NVARCHAR(MAX), @UpdatedBy INT',
        @Id, @Name, @ImageUrl, @PackageTerms, @InvoiceTerms, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Destination_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Destinations
        SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DestinationReview_DeleteByDestination
    @DatabaseName  NVARCHAR(100),
    @DestinationId INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DELETE FROM [' + @DatabaseName + N'].dbo.DestinationReviews
        WHERE DestinationId = @DestinationId';
    EXEC sp_executesql @sql, N'@DestinationId INT', @DestinationId;
END
GO

CREATE OR ALTER PROCEDURE sp_DestinationReview_Insert
    @DatabaseName  NVARCHAR(100),
    @DestinationId INT,
    @TravelerName  NVARCHAR(200),
    @ImageUrl      NVARCHAR(500) = NULL,
    @ReviewText    NVARCHAR(MAX) = NULL,
    @DisplayOrder  INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.DestinationReviews
            (DestinationId, TravelerName, ImageUrl, ReviewText, DisplayOrder)
        VALUES (@DestinationId, @TravelerName, @ImageUrl, @ReviewText, @DisplayOrder)';
    EXEC sp_executesql @sql,
        N'@DestinationId INT, @TravelerName NVARCHAR(200), @ImageUrl NVARCHAR(500), @ReviewText NVARCHAR(MAX), @DisplayOrder INT',
        @DestinationId, @TravelerName, @ImageUrl, @ReviewText, @DisplayOrder;
END
GO

-- ============================================================
-- ROOM TYPE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_RoomType_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.RoomTypes
        WHERE IsActive = 1 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_RoomType_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.RoomTypes WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_RoomType_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(100),
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.RoomTypes (Name, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(100), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_RoomType_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(100),
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.RoomTypes
        SET Name = @Name, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(100), @UpdatedBy INT',
        @Id, @Name, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_RoomType_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.RoomTypes SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- HOTEL PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Hotel_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT h.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Hotels h
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON h.DestinationId = d.Id
        WHERE h.IsActive = 1 ORDER BY d.Name, h.Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Hotel_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT h.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Hotels h
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON h.DestinationId = d.Id
        WHERE h.Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Hotel_Insert
    @DatabaseName  NVARCHAR(100),
    @DestinationId INT,
    @Name          NVARCHAR(200),
    @Category      TINYINT       = 3,
    @ImageUrl      NVARCHAR(500) = NULL,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Hotels
            (DestinationId, Name, Category, ImageUrl, IsActive, CreatedAt, CreatedBy)
        VALUES (@DestinationId, @Name, @Category, @ImageUrl, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@DestinationId INT, @Name NVARCHAR(200), @Category TINYINT, @ImageUrl NVARCHAR(500), @CreatedBy INT, @NewId INT OUTPUT',
        @DestinationId, @Name, @Category, @ImageUrl, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Hotel_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @DestinationId INT,
    @Name          NVARCHAR(200),
    @Category      TINYINT       = 3,
    @ImageUrl      NVARCHAR(500) = NULL,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Hotels
        SET DestinationId = @DestinationId,
            Name = @Name,
            Category = @Category,
            ImageUrl = ISNULL(@ImageUrl, ImageUrl),
            UpdatedAt = GETUTCDATE(),
            UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @DestinationId INT, @Name NVARCHAR(200), @Category TINYINT, @ImageUrl NVARCHAR(500), @UpdatedBy INT',
        @Id, @DestinationId, @Name, @Category, @ImageUrl, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Hotel_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Hotels SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- SIGHTSEEING PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Sightseeing_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT s.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Sightseeings s
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON s.DestinationId = d.Id
        WHERE s.IsActive = 1 ORDER BY d.Name, s.Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Sightseeing_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT s.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Sightseeings s
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON s.DestinationId = d.Id
        WHERE s.Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Sightseeing_Insert
    @DatabaseName  NVARCHAR(100),
    @DestinationId INT,
    @Name          NVARCHAR(200),
    @ImageUrl      NVARCHAR(500) = NULL,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Sightseeings
            (DestinationId, Name, ImageUrl, IsActive, CreatedAt, CreatedBy)
        VALUES (@DestinationId, @Name, @ImageUrl, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@DestinationId INT, @Name NVARCHAR(200), @ImageUrl NVARCHAR(500), @CreatedBy INT, @NewId INT OUTPUT',
        @DestinationId, @Name, @ImageUrl, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Sightseeing_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @DestinationId INT,
    @Name          NVARCHAR(200),
    @ImageUrl      NVARCHAR(500) = NULL,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Sightseeings
        SET DestinationId = @DestinationId,
            Name = @Name,
            ImageUrl = ISNULL(@ImageUrl, ImageUrl),
            UpdatedAt = GETUTCDATE(),
            UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @DestinationId INT, @Name NVARCHAR(200), @ImageUrl NVARCHAR(500), @UpdatedBy INT',
        @Id, @DestinationId, @Name, @ImageUrl, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Sightseeing_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Sightseeings SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- ITINERARY PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Itinerary_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT i.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Itineraries i
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON i.DestinationId = d.Id
        WHERE i.IsActive = 1 ORDER BY d.Name, i.Title';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Itinerary_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT i.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Itineraries i
        INNER JOIN [' + @DatabaseName + N'].dbo.Destinations d ON i.DestinationId = d.Id
        WHERE i.Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Itinerary_Insert
    @DatabaseName  NVARCHAR(100),
    @DestinationId INT,
    @Title         NVARCHAR(300),
    @Description   NVARCHAR(MAX) = NULL,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Itineraries
            (DestinationId, Title, Description, IsActive, CreatedAt, CreatedBy)
        VALUES (@DestinationId, @Title, @Description, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@DestinationId INT, @Title NVARCHAR(300), @Description NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @DestinationId, @Title, @Description, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Itinerary_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @DestinationId INT,
    @Title         NVARCHAR(300),
    @Description   NVARCHAR(MAX) = NULL,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Itineraries
        SET DestinationId = @DestinationId,
            Title = @Title,
            Description = @Description,
            UpdatedAt = GETUTCDATE(),
            UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @DestinationId INT, @Title NVARCHAR(300), @Description NVARCHAR(MAX), @UpdatedBy INT',
        @Id, @DestinationId, @Title, @Description, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Itinerary_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Itineraries SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- LEAD SOURCE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_LeadSource_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.LeadSources WHERE IsActive = 1 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadSource_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(100),
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.LeadSources (Name, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(100), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadSource_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(100),
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeadSources
        SET Name = @Name, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(100), @UpdatedBy INT',
        @Id, @Name, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadSource_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeadSources SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- VISA TYPE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_VisaType_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.VisaTypes WHERE IsActive = 1 ORDER BY Country, Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_VisaType_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(150),
    @Country      NVARCHAR(100) = NULL,
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.VisaTypes (Name, Country, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, @Country, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(150), @Country NVARCHAR(100), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @Country, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_VisaType_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(150),
    @Country      NVARCHAR(100) = NULL,
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.VisaTypes
        SET Name = @Name, Country = @Country,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(150), @Country NVARCHAR(100), @UpdatedBy INT',
        @Id, @Name, @Country, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_VisaType_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.VisaTypes SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- MAIL TEMPLATE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_MailTemplate_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.MailTemplates
        WHERE IsActive = 1 ORDER BY Category, Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_MailTemplate_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.MailTemplates WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_MailTemplate_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(150),
    @Subject      NVARCHAR(300),
    @Body         NVARCHAR(MAX) = NULL,
    @Category     NVARCHAR(50)  = NULL,
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.MailTemplates
            (Name, Subject, Body, Category, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, @Subject, @Body, @Category, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(150), @Subject NVARCHAR(300), @Body NVARCHAR(MAX), @Category NVARCHAR(50), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @Subject, @Body, @Category, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_MailTemplate_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(150),
    @Subject      NVARCHAR(300),
    @Body         NVARCHAR(MAX) = NULL,
    @Category     NVARCHAR(50)  = NULL,
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.MailTemplates
        SET Name = @Name, Subject = @Subject, Body = @Body, Category = @Category,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(150), @Subject NVARCHAR(300), @Body NVARCHAR(MAX), @Category NVARCHAR(50), @UpdatedBy INT',
        @Id, @Name, @Subject, @Body, @Category, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_MailTemplate_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.MailTemplates SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- MEAL PLAN PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_MealPlan_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.MealPlans WHERE IsActive = 1 ORDER BY Code';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_MealPlan_Insert
    @DatabaseName NVARCHAR(100),
    @Code         NVARCHAR(10),
    @Name         NVARCHAR(100),
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.MealPlans (Code, Name, IsActive, CreatedAt, CreatedBy)
        VALUES (@Code, @Name, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Code NVARCHAR(10), @Name NVARCHAR(100), @CreatedBy INT, @NewId INT OUTPUT',
        @Code, @Name, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_MealPlan_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Code         NVARCHAR(10),
    @Name         NVARCHAR(100),
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.MealPlans
        SET Code = @Code, Name = @Name, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Code NVARCHAR(10), @Name NVARCHAR(100), @UpdatedBy INT',
        @Id, @Code, @Name, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_MealPlan_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.MealPlans SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- BANK ACCOUNT PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_BankAccount_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.BankAccounts
        WHERE IsActive = 1 ORDER BY IsDefault DESC, BankName';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_BankAccount_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.BankAccounts WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_BankAccount_Insert
    @DatabaseName  NVARCHAR(100),
    @BankName      NVARCHAR(150),
    @HolderName    NVARCHAR(150),
    @AccountNumber NVARCHAR(50),
    @IfscCode      NVARCHAR(20)  = NULL,
    @Branch        NVARCHAR(150) = NULL,
    @AccountType   NVARCHAR(20)  = NULL,
    @UpiId         NVARCHAR(100) = NULL,
    @IsDefault     BIT           = 0,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        IF @IsDefault = 1
            UPDATE [' + @DatabaseName + N'].dbo.BankAccounts SET IsDefault = 0 WHERE IsDefault = 1;
        INSERT INTO [' + @DatabaseName + N'].dbo.BankAccounts
            (BankName, HolderName, AccountNumber, IfscCode, Branch, AccountType, UpiId,
             IsDefault, IsActive, CreatedAt, CreatedBy)
        VALUES (@BankName, @HolderName, @AccountNumber, @IfscCode, @Branch, @AccountType, @UpiId,
            @IsDefault, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@BankName NVARCHAR(150), @HolderName NVARCHAR(150), @AccountNumber NVARCHAR(50), @IfscCode NVARCHAR(20), @Branch NVARCHAR(150), @AccountType NVARCHAR(20), @UpiId NVARCHAR(100), @IsDefault BIT, @CreatedBy INT, @NewId INT OUTPUT',
        @BankName, @HolderName, @AccountNumber, @IfscCode, @Branch, @AccountType, @UpiId, @IsDefault, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_BankAccount_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @BankName      NVARCHAR(150),
    @HolderName    NVARCHAR(150),
    @AccountNumber NVARCHAR(50),
    @IfscCode      NVARCHAR(20)  = NULL,
    @Branch        NVARCHAR(150) = NULL,
    @AccountType   NVARCHAR(20)  = NULL,
    @UpiId         NVARCHAR(100) = NULL,
    @IsDefault     BIT           = 0,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        IF @IsDefault = 1
            UPDATE [' + @DatabaseName + N'].dbo.BankAccounts SET IsDefault = 0 WHERE IsDefault = 1 AND Id <> @Id;
        UPDATE [' + @DatabaseName + N'].dbo.BankAccounts
        SET BankName = @BankName, HolderName = @HolderName, AccountNumber = @AccountNumber,
            IfscCode = @IfscCode, Branch = @Branch, AccountType = @AccountType, UpiId = @UpiId,
            IsDefault = @IsDefault, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @BankName NVARCHAR(150), @HolderName NVARCHAR(150), @AccountNumber NVARCHAR(50), @IfscCode NVARCHAR(20), @Branch NVARCHAR(150), @AccountType NVARCHAR(20), @UpiId NVARCHAR(100), @IsDefault BIT, @UpdatedBy INT',
        @Id, @BankName, @HolderName, @AccountNumber, @IfscCode, @Branch, @AccountType, @UpiId, @IsDefault, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_BankAccount_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.BankAccounts SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- LEAD STATUS PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_LeadStatus_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.LeadStatuses
        WHERE IsActive = 1 ORDER BY DisplayOrder, Id';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadStatus_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(100),
    @Color        NVARCHAR(20)  = 'secondary',
    @DisplayOrder INT           = 0,
    @IsDefault    BIT           = 0,
    @IsClosed     BIT           = 0,
    @CreatedBy    INT           = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        IF @IsDefault = 1
            UPDATE [' + @DatabaseName + N'].dbo.LeadStatuses SET IsDefault = 0 WHERE IsDefault = 1;
        INSERT INTO [' + @DatabaseName + N'].dbo.LeadStatuses
            (Name, Color, DisplayOrder, IsDefault, IsClosed, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, @Color, @DisplayOrder, @IsDefault, @IsClosed, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(100), @Color NVARCHAR(20), @DisplayOrder INT, @IsDefault BIT, @IsClosed BIT, @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @Color, @DisplayOrder, @IsDefault, @IsClosed, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadStatus_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(100),
    @Color        NVARCHAR(20)  = 'secondary',
    @DisplayOrder INT           = 0,
    @IsDefault    BIT           = 0,
    @IsClosed     BIT           = 0,
    @UpdatedBy    INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        IF @IsDefault = 1
            UPDATE [' + @DatabaseName + N'].dbo.LeadStatuses SET IsDefault = 0 WHERE IsDefault = 1 AND Id <> @Id;
        UPDATE [' + @DatabaseName + N'].dbo.LeadStatuses
        SET Name = @Name, Color = @Color, DisplayOrder = @DisplayOrder,
            IsDefault = @IsDefault, IsClosed = @IsClosed,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(100), @Color NVARCHAR(20), @DisplayOrder INT, @IsDefault BIT, @IsClosed BIT, @UpdatedBy INT',
        @Id, @Name, @Color, @DisplayOrder, @IsDefault, @IsClosed, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadStatus_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeadStatuses SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- LEAD PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Lead_GetAll
    @DatabaseName  NVARCHAR(100),
    @StatusId      INT          = NULL,
    @SourceId      INT          = NULL,
    @AssignedTo    INT          = NULL,
    @DestinationId INT          = NULL,
    @DateFrom      DATE         = NULL,
    @DateTo        DATE         = NULL,
    @Search        NVARCHAR(150)= NULL,
    @ShowClosed    BIT          = 0,
    @Page          INT          = 1,
    @PageSize      INT          = 10
AS BEGIN
    SET NOCOUNT ON;
    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 10;
    IF @PageSize > 200 SET @PageSize = 200;

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT l.*,
               s.Name AS StatusName, s.Color AS StatusColor, s.IsClosed AS StatusIsClosed,
               src.Name AS SourceName,
               d.Name AS DestinationName,
               COUNT(*) OVER() AS TotalCount
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s   ON l.StatusId = s.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadSources  src ON l.SourceId = src.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d   ON l.DestinationId = d.Id
        WHERE l.IsActive = 1
          AND (@StatusId      IS NULL OR l.StatusId = @StatusId)
          AND (@SourceId      IS NULL OR l.SourceId = @SourceId)
          AND (@AssignedTo    IS NULL OR l.AssignedToUserId = @AssignedTo)
          AND (@DestinationId IS NULL OR l.DestinationId = @DestinationId)
          AND (@DateFrom      IS NULL OR CAST(l.CreatedAt AS DATE) >= @DateFrom)
          AND (@DateTo        IS NULL OR CAST(l.CreatedAt AS DATE) <= @DateTo)
          AND (@ShowClosed = 1 OR s.IsClosed = 0 OR s.IsClosed IS NULL)
          AND (@Search IS NULL OR
               l.Name LIKE ''%'' + @Search + ''%'' OR
               l.Mobile LIKE ''%'' + @Search + ''%'' OR
               l.Email LIKE ''%'' + @Search + ''%'' OR
               l.LeadNumber LIKE ''%'' + @Search + ''%'')
        ORDER BY l.CreatedAt DESC
        OFFSET ((@Page - 1) * @PageSize) ROWS
        FETCH NEXT @PageSize ROWS ONLY';
    EXEC sp_executesql @sql,
        N'@StatusId INT, @SourceId INT, @AssignedTo INT, @DestinationId INT, @DateFrom DATE, @DateTo DATE, @Search NVARCHAR(150), @ShowClosed BIT, @Page INT, @PageSize INT',
        @StatusId, @SourceId, @AssignedTo, @DestinationId, @DateFrom, @DateTo, @Search, @ShowClosed, @Page, @PageSize;
END
GO

CREATE OR ALTER PROCEDURE sp_Lead_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT l.*,
               s.Name AS StatusName, s.Color AS StatusColor, s.IsClosed AS StatusIsClosed,
               src.Name AS SourceName,
               d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s   ON l.StatusId = s.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadSources  src ON l.SourceId = src.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d   ON l.DestinationId = d.Id
        WHERE l.Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Lead_Insert
    @DatabaseName       NVARCHAR(100),
    @Prefix             NVARCHAR(20)  = 'LD',
    @StatusId           INT           = NULL,
    @SourceId           INT           = NULL,
    @AssignedToUserId   INT           = NULL,
    @DestinationId      INT           = NULL,
    @Name               NVARCHAR(150),
    @Mobile             NVARCHAR(30)  = NULL,
    @Email              NVARCHAR(150) = NULL,
    @TravelingDate      DATE          = NULL,
    @LeavingFrom        NVARCHAR(150) = NULL,
    @HotelRecommended   NVARCHAR(200) = NULL,
    @Adults             INT           = 1,
    @Children           INT           = 0,
    @Infants            INT           = 0,
    @Days               INT           = NULL,
    @Remark             NVARCHAR(MAX) = NULL,
    @CreatedBy          INT           = 0,
    @NewId              INT OUTPUT,
    @LeadNumber         NVARCHAR(30) OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    IF @Prefix IS NULL OR LEN(@Prefix) = 0 SET @Prefix = N'LD';

    -- Default StatusId to the configured default if not provided
    IF @StatusId IS NULL
    BEGIN
        DECLARE @lookupSql NVARCHAR(MAX) = N'
            SELECT TOP 1 @StatusOut = Id FROM [' + @DatabaseName + N'].dbo.LeadStatuses
            WHERE IsDefault = 1 AND IsActive = 1';
        EXEC sp_executesql @lookupSql, N'@StatusOut INT OUTPUT', @StatusOut = @StatusId OUTPUT;
    END

    -- Generate LeadNumber: {Prefix}-YYYY-NNNN (per-tenant per-year)
    DECLARE @year INT = YEAR(GETUTCDATE());
    DECLARE @count INT = 0;
    DECLARE @prefixPattern NVARCHAR(50) = @Prefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-%';
    DECLARE @countSql NVARCHAR(MAX) = N'
        SELECT @c = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Leads
        WHERE LeadNumber LIKE @pat';
    EXEC sp_executesql @countSql,
        N'@c INT OUTPUT, @pat NVARCHAR(50)',
        @c = @count OUTPUT, @pat = @prefixPattern;
    SET @LeadNumber = @Prefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-' +
                      RIGHT(N'0000' + CAST((@count + 1) AS NVARCHAR(10)), 4);

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Leads
            (LeadNumber, StatusId, SourceId, AssignedToUserId, DestinationId,
             Name, Mobile, Email, TravelingDate, LeavingFrom, HotelRecommended,
             Adults, Children, Infants, Days, Remark,
             IsActive, CreatedAt, CreatedBy)
        VALUES (@LeadNumber, @StatusId, @SourceId, @AssignedToUserId, @DestinationId,
            @Name, @Mobile, @Email, @TravelingDate, @LeavingFrom, @HotelRecommended,
            @Adults, @Children, @Infants, @Days, @Remark,
            1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@LeadNumber NVARCHAR(30), @StatusId INT, @SourceId INT, @AssignedToUserId INT, @DestinationId INT, @Name NVARCHAR(150), @Mobile NVARCHAR(30), @Email NVARCHAR(150), @TravelingDate DATE, @LeavingFrom NVARCHAR(150), @HotelRecommended NVARCHAR(200), @Adults INT, @Children INT, @Infants INT, @Days INT, @Remark NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @LeadNumber, @StatusId, @SourceId, @AssignedToUserId, @DestinationId,
        @Name, @Mobile, @Email, @TravelingDate, @LeavingFrom, @HotelRecommended,
        @Adults, @Children, @Infants, @Days, @Remark, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Lead_Update
    @DatabaseName       NVARCHAR(100),
    @Id                 INT,
    @StatusId           INT           = NULL,
    @SourceId           INT           = NULL,
    @AssignedToUserId   INT           = NULL,
    @DestinationId      INT           = NULL,
    @Name               NVARCHAR(150),
    @Mobile             NVARCHAR(30)  = NULL,
    @Email              NVARCHAR(150) = NULL,
    @TravelingDate      DATE          = NULL,
    @LeavingFrom        NVARCHAR(150) = NULL,
    @HotelRecommended   NVARCHAR(200) = NULL,
    @Adults             INT           = 1,
    @Children           INT           = 0,
    @Infants            INT           = 0,
    @Days               INT           = NULL,
    @Remark             NVARCHAR(MAX) = NULL,
    @UpdatedBy          INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Leads
        SET StatusId = @StatusId,
            SourceId = @SourceId,
            AssignedToUserId = @AssignedToUserId,
            DestinationId = @DestinationId,
            Name = @Name, Mobile = @Mobile, Email = @Email,
            TravelingDate = @TravelingDate,
            LeavingFrom = @LeavingFrom,
            HotelRecommended = @HotelRecommended,
            Adults = @Adults, Children = @Children, Infants = @Infants, Days = @Days,
            Remark = @Remark,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @StatusId INT, @SourceId INT, @AssignedToUserId INT, @DestinationId INT, @Name NVARCHAR(150), @Mobile NVARCHAR(30), @Email NVARCHAR(150), @TravelingDate DATE, @LeavingFrom NVARCHAR(150), @HotelRecommended NVARCHAR(200), @Adults INT, @Children INT, @Infants INT, @Days INT, @Remark NVARCHAR(MAX), @UpdatedBy INT',
        @Id, @StatusId, @SourceId, @AssignedToUserId, @DestinationId,
        @Name, @Mobile, @Email, @TravelingDate, @LeavingFrom, @HotelRecommended,
        @Adults, @Children, @Infants, @Days, @Remark, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Lead_ChangeStatus
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @StatusId     INT,
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DECLARE @oldStatusName NVARCHAR(100), @newStatusName NVARCHAR(100), @oldStatusId INT;

        SELECT @oldStatusId = StatusId FROM [' + @DatabaseName + N'].dbo.Leads WHERE Id = @Id;

        SELECT @oldStatusName = Name FROM [' + @DatabaseName + N'].dbo.LeadStatuses WHERE Id = @oldStatusId;
        SELECT @newStatusName = Name FROM [' + @DatabaseName + N'].dbo.LeadStatuses WHERE Id = @StatusId;

        UPDATE [' + @DatabaseName + N'].dbo.Leads
        SET StatusId = @StatusId, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id;

        -- Auto-log the status change as an activity (only if status actually changed)
        IF @oldStatusId IS NULL OR @oldStatusId <> @StatusId
        BEGIN
            INSERT INTO [' + @DatabaseName + N'].dbo.LeadActivities
                (LeadId, ActivityType, Subject, Notes, ActivityAt, IsCompleted, CreatedByUserId, CreatedAt)
            VALUES (@Id, ''StatusChange'',
                    CONCAT(ISNULL(@oldStatusName, N''(none)''), '' → '', @newStatusName),
                    NULL, GETUTCDATE(), 1, @UpdatedBy, GETUTCDATE());
        END';
    EXEC sp_executesql @sql,
        N'@Id INT, @StatusId INT, @UpdatedBy INT',
        @Id, @StatusId, @UpdatedBy;
END
GO

-- ============================================================
-- LEAD ACTIVITY PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_LeadActivity_GetByLead
    @DatabaseName NVARCHAR(100),
    @LeadId       INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.LeadActivities
        WHERE LeadId = @LeadId
        ORDER BY
            CASE WHEN IsCompleted = 0 THEN 0 ELSE 1 END,    -- pending follow-ups first
            CASE WHEN IsCompleted = 0 THEN NextFollowUpAt END ASC,
            ActivityAt DESC';
    EXEC sp_executesql @sql, N'@LeadId INT', @LeadId;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadActivity_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.LeadActivities WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadActivity_Insert
    @DatabaseName     NVARCHAR(100),
    @LeadId           INT,
    @ActivityType     NVARCHAR(30),
    @Subject          NVARCHAR(200) = NULL,
    @Notes            NVARCHAR(MAX) = NULL,
    @ActivityAt       DATETIME2     = NULL,
    @NextFollowUpAt   DATETIME2     = NULL,
    @IsCompleted      BIT           = 1,
    @CreatedByUserId  INT           = 0,
    @NewId            INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.LeadActivities
            (LeadId, ActivityType, Subject, Notes, ActivityAt, NextFollowUpAt, IsCompleted, CreatedByUserId, CreatedAt)
        VALUES (@LeadId, @ActivityType, @Subject, @Notes,
                ISNULL(@ActivityAt, GETUTCDATE()), @NextFollowUpAt, @IsCompleted, @CreatedByUserId, GETUTCDATE());
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@LeadId INT, @ActivityType NVARCHAR(30), @Subject NVARCHAR(200), @Notes NVARCHAR(MAX), @ActivityAt DATETIME2, @NextFollowUpAt DATETIME2, @IsCompleted BIT, @CreatedByUserId INT, @NewId INT OUTPUT',
        @LeadId, @ActivityType, @Subject, @Notes, @ActivityAt, @NextFollowUpAt, @IsCompleted, @CreatedByUserId, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadActivity_Update
    @DatabaseName     NVARCHAR(100),
    @Id               INT,
    @ActivityType     NVARCHAR(30),
    @Subject          NVARCHAR(200) = NULL,
    @Notes            NVARCHAR(MAX) = NULL,
    @ActivityAt       DATETIME2     = NULL,
    @NextFollowUpAt   DATETIME2     = NULL,
    @IsCompleted      BIT           = 1
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeadActivities
        SET ActivityType = @ActivityType, Subject = @Subject, Notes = @Notes,
            ActivityAt = ISNULL(@ActivityAt, ActivityAt),
            NextFollowUpAt = @NextFollowUpAt,
            IsCompleted = @IsCompleted,
            UpdatedAt = GETUTCDATE()
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @ActivityType NVARCHAR(30), @Subject NVARCHAR(200), @Notes NVARCHAR(MAX), @ActivityAt DATETIME2, @NextFollowUpAt DATETIME2, @IsCompleted BIT',
        @Id, @ActivityType, @Subject, @Notes, @ActivityAt, @NextFollowUpAt, @IsCompleted;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadActivity_Complete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeadActivities
        SET IsCompleted = 1, UpdatedAt = GETUTCDATE()
        WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_LeadActivity_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DELETE FROM [' + @DatabaseName + N'].dbo.LeadActivities WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- ACTIVITY TEMPLATE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ActivityTemplate_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.ActivityTemplates
        WHERE IsActive = 1 ORDER BY DisplayOrder, ActivityType, Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_ActivityTemplate_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.ActivityTemplates WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_ActivityTemplate_Insert
    @DatabaseName  NVARCHAR(100),
    @Name          NVARCHAR(150),
    @ActivityType  NVARCHAR(30) = 'All',
    @Subject       NVARCHAR(200) = NULL,
    @Notes         NVARCHAR(MAX) = NULL,
    @DisplayOrder  INT = 0,
    @CreatedBy     INT = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.ActivityTemplates
            (Name, ActivityType, Subject, Notes, DisplayOrder, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, @ActivityType, @Subject, @Notes, @DisplayOrder, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(150), @ActivityType NVARCHAR(30), @Subject NVARCHAR(200), @Notes NVARCHAR(MAX), @DisplayOrder INT, @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @ActivityType, @Subject, @Notes, @DisplayOrder, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_ActivityTemplate_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @Name          NVARCHAR(150),
    @ActivityType  NVARCHAR(30) = 'All',
    @Subject       NVARCHAR(200) = NULL,
    @Notes         NVARCHAR(MAX) = NULL,
    @DisplayOrder  INT = 0,
    @UpdatedBy     INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.ActivityTemplates
        SET Name = @Name, ActivityType = @ActivityType, Subject = @Subject, Notes = @Notes,
            DisplayOrder = @DisplayOrder, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(150), @ActivityType NVARCHAR(30), @Subject NVARCHAR(200), @Notes NVARCHAR(MAX), @DisplayOrder INT, @UpdatedBy INT',
        @Id, @Name, @ActivityType, @Subject, @Notes, @DisplayOrder, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_ActivityTemplate_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.ActivityTemplates SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Lead_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Leads SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- PACKAGE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Package_GetAll
    @DatabaseName NVARCHAR(100),
    @Search       NVARCHAR(150)= NULL,
    @Page         INT          = 1,
    @PageSize     INT          = 20
AS BEGIN
    SET NOCOUNT ON;
    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 200 SET @PageSize = 200;

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT p.*,
               d.Name AS DestinationName,
               (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS OptionCount,
               (SELECT MIN(o.FinalPrice) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS MinPrice,
               (SELECT MAX(o.FinalPrice) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS MaxPrice,
               COUNT(*) OVER() AS TotalCount
        FROM [' + @DatabaseName + N'].dbo.Packages p
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON p.DestinationId = d.Id
        WHERE p.IsActive = 1
          AND (@Search IS NULL OR
               p.PackageNumber LIKE ''%'' + @Search + ''%'' OR
               p.Title LIKE ''%'' + @Search + ''%'' OR
               p.CustomerName LIKE ''%'' + @Search + ''%'')
        ORDER BY p.CreatedAt DESC
        OFFSET ((@Page - 1) * @PageSize) ROWS
        FETCH NEXT @PageSize ROWS ONLY';
    EXEC sp_executesql @sql,
        N'@Search NVARCHAR(150), @Page INT, @PageSize INT',
        @Search, @Page, @PageSize;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetByLead
    @DatabaseName NVARCHAR(100),
    @LeadId       INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT p.*,
               d.Name AS DestinationName,
               (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS OptionCount,
               (SELECT MIN(o.FinalPrice) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS MinPrice,
               (SELECT MAX(o.FinalPrice) FROM [' + @DatabaseName + N'].dbo.PackageOptions o WHERE o.PackageId = p.Id) AS MaxPrice
        FROM [' + @DatabaseName + N'].dbo.Packages p
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON p.DestinationId = d.Id
        WHERE p.IsActive = 1 AND p.LeadId = @LeadId
        ORDER BY p.CreatedAt DESC';
    EXEC sp_executesql @sql, N'@LeadId INT', @LeadId;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT p.*, d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Packages p
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON p.DestinationId = d.Id
        WHERE p.Id = @Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.PackageOptions
        WHERE PackageId = @Id ORDER BY DisplayOrder, Id;

        SELECT h.*, ho.Name AS HotelName, rt.Name AS RoomTypeName, mp.Code AS MealPlanCode, mp.Name AS MealPlanName
        FROM [' + @DatabaseName + N'].dbo.PackageOptionHotels h
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageOptions o ON h.PackageOptionId = o.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Hotels    ho ON h.HotelId    = ho.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.RoomTypes rt ON h.RoomTypeId = rt.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.MealPlans mp ON h.MealPlanId = mp.Id
        WHERE o.PackageId = @Id
        ORDER BY h.PackageOptionId, h.DisplayOrder, h.Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.PackageDays
        WHERE PackageId = @Id ORDER BY DayNumber, Id;

        SELECT pds.Id, pds.PackageDayId, pds.SightseeingId, s.Name AS SightseeingName
        FROM [' + @DatabaseName + N'].dbo.PackageDaySightseeings pds
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageDays pd ON pds.PackageDayId = pd.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Sightseeings s ON pds.SightseeingId = s.Id
        WHERE pd.PackageId = @Id
        ORDER BY pds.PackageDayId, pds.Id;';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Insert
    @DatabaseName    NVARCHAR(100),
    @Prefix          NVARCHAR(20)  = 'PKG',
    @LeadId          INT           = NULL,
    @Title           NVARCHAR(200),
    @DestinationId   INT           = NULL,
    @CustomerName    NVARCHAR(150),
    @CustomerMobile  NVARCHAR(30)  = NULL,
    @CustomerEmail   NVARCHAR(150) = NULL,
    @Adults          INT           = 1,
    @Children        INT           = 0,
    @Infants         INT           = 0,
    @Days            INT           = NULL,
    @Nights          INT           = NULL,
    @StartDate       DATE          = NULL,
    @PriceMode       NVARCHAR(20)  = 'Total',
    @Currency        NVARCHAR(10)  = 'INR',
    @FlightDetails   NVARCHAR(MAX) = NULL,
    @Inclusions      NVARCHAR(MAX) = NULL,
    @Exclusions      NVARCHAR(MAX) = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @CreatedBy       INT           = 0,
    @NewId           INT OUTPUT,
    @PackageNumber   NVARCHAR(40) OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    IF @Prefix IS NULL OR LEN(@Prefix) = 0 SET @Prefix = N'PKG';

    DECLARE @year INT = YEAR(GETUTCDATE());
    DECLARE @count INT = 0;
    DECLARE @pat NVARCHAR(50) = @Prefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-%';
    DECLARE @countSql NVARCHAR(MAX) = N'
        SELECT @c = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Packages
        WHERE PackageNumber LIKE @p';
    EXEC sp_executesql @countSql, N'@c INT OUTPUT, @p NVARCHAR(50)',
        @c = @count OUTPUT, @p = @pat;
    SET @PackageNumber = @Prefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-' +
                         RIGHT(N'0000' + CAST((@count + 1) AS NVARCHAR(10)), 4);

    -- 32-char random hex token (collision-resistant, URL-safe)
    DECLARE @ShareToken NVARCHAR(64) = LOWER(REPLACE(CAST(NEWID() AS NVARCHAR(40)), '-', ''));

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Packages
            (PackageNumber, ShareToken, LeadId, Title, DestinationId, CustomerName, CustomerMobile, CustomerEmail,
             Adults, Children, Infants, Days, Nights, StartDate, PriceMode, Currency,
             FlightDetails, Inclusions, Exclusions, Notes,
             IsActive, CreatedAt, CreatedBy)
        VALUES (@PackageNumber, @ShareToken, @LeadId, @Title, @DestinationId, @CustomerName, @CustomerMobile, @CustomerEmail,
            @Adults, @Children, @Infants, @Days, @Nights, @StartDate, @PriceMode, @Currency,
            @FlightDetails, @Inclusions, @Exclusions, @Notes,
            1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@PackageNumber NVARCHAR(40), @ShareToken NVARCHAR(64), @LeadId INT, @Title NVARCHAR(200), @DestinationId INT, @CustomerName NVARCHAR(150), @CustomerMobile NVARCHAR(30), @CustomerEmail NVARCHAR(150), @Adults INT, @Children INT, @Infants INT, @Days INT, @Nights INT, @StartDate DATE, @PriceMode NVARCHAR(20), @Currency NVARCHAR(10), @FlightDetails NVARCHAR(MAX), @Inclusions NVARCHAR(MAX), @Exclusions NVARCHAR(MAX), @Notes NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @PackageNumber, @ShareToken, @LeadId, @Title, @DestinationId, @CustomerName, @CustomerMobile, @CustomerEmail,
        @Adults, @Children, @Infants, @Days, @Nights, @StartDate, @PriceMode, @Currency,
        @FlightDetails, @Inclusions, @Exclusions, @Notes, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetByShareToken
    @DatabaseName NVARCHAR(100),
    @Token        NVARCHAR(64)
AS BEGIN
    SET NOCOUNT ON;

    -- Resolve package id + creator (agent) up front so we can return the agent
    -- name/phone alongside other context. CreatedBy points at MasterUsers in the
    -- master DB; profile fields (Mobile, ProfileImageUrl) live there too.
    DECLARE @id INT, @createdBy INT;
    DECLARE @findSql NVARCHAR(MAX) = N'
        SELECT @id = Id, @createdBy = CreatedBy
        FROM [' + @DatabaseName + N'].dbo.Packages
        WHERE ShareToken = @Token AND IsActive = 1;';
    EXEC sp_executesql @findSql,
        N'@Token NVARCHAR(64), @id INT OUTPUT, @createdBy INT OUTPUT',
        @Token, @id OUTPUT, @createdBy OUTPUT;

    IF @id IS NULL
    BEGIN
        -- Empty result sets matching the success shape so the reader doesn't crash.
        DECLARE @emptySql NVARCHAR(MAX) = N'
            SELECT TOP 0 *,
                   CAST(NULL AS NVARCHAR(200)) AS DestinationName,
                   CAST(NULL AS NVARCHAR(500)) AS DestinationBannerUrl,
                   CAST(NULL AS NVARCHAR(MAX)) AS DestinationTerms
            FROM [' + @DatabaseName + N'].dbo.Packages;

            SELECT TOP 0 * FROM [' + @DatabaseName + N'].dbo.PackageOptions;

            SELECT TOP 0 *,
                   CAST(NULL AS NVARCHAR(200)) AS HotelName,
                   CAST(NULL AS NVARCHAR(500)) AS HotelImageUrl,
                   CAST(NULL AS TINYINT)       AS HotelCategory,
                   CAST(NULL AS NVARCHAR(100)) AS RoomTypeName,
                   CAST(NULL AS NVARCHAR(10))  AS MealPlanCode,
                   CAST(NULL AS NVARCHAR(100)) AS MealPlanName
            FROM [' + @DatabaseName + N'].dbo.PackageOptionHotels;

            SELECT TOP 0 * FROM [' + @DatabaseName + N'].dbo.PackageDays;

            SELECT TOP 0 Id, PackageDayId, SightseeingId,
                   CAST(NULL AS NVARCHAR(200)) AS SightseeingName,
                   CAST(NULL AS NVARCHAR(500)) AS SightseeingImageUrl
            FROM [' + @DatabaseName + N'].dbo.PackageDaySightseeings;

            SELECT TOP 0 * FROM [' + @DatabaseName + N'].dbo.BankAccounts;';
        EXEC sp_executesql @emptySql;

        -- Empty agent + empty company.
        SELECT TOP 0
               CAST(NULL AS NVARCHAR(150)) AS FullName,
               CAST(NULL AS NVARCHAR(150)) AS Email,
               CAST(NULL AS NVARCHAR(30))  AS Mobile,
               CAST(NULL AS NVARCHAR(500)) AS ImageUrl;
        SELECT TOP 0
               CAST(NULL AS NVARCHAR(MAX)) AS GreetingParagraph,
               CAST(NULL AS NVARCHAR(MAX)) AS WhyBookWithUs;
        RETURN;
    END

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT p.*, d.Name AS DestinationName,
               d.ImageUrl     AS DestinationBannerUrl,
               d.PackageTerms AS DestinationTerms
        FROM [' + @DatabaseName + N'].dbo.Packages p
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON p.DestinationId = d.Id
        WHERE p.Id = @id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.PackageOptions
        WHERE PackageId = @id ORDER BY DisplayOrder, Id;

        SELECT h.*,
               ho.Name     AS HotelName,
               ho.ImageUrl AS HotelImageUrl,
               ho.Category AS HotelCategory,
               rt.Name     AS RoomTypeName,
               mp.Code     AS MealPlanCode,
               mp.Name     AS MealPlanName
        FROM [' + @DatabaseName + N'].dbo.PackageOptionHotels h
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageOptions o ON h.PackageOptionId = o.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.Hotels    ho ON h.HotelId    = ho.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.RoomTypes rt ON h.RoomTypeId = rt.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.MealPlans mp ON h.MealPlanId = mp.Id
        WHERE o.PackageId = @id
        ORDER BY h.PackageOptionId, h.DisplayOrder, h.Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.PackageDays
        WHERE PackageId = @id ORDER BY DayNumber, Id;

        SELECT pds.Id, pds.PackageDayId, pds.SightseeingId,
               s.Name     AS SightseeingName,
               s.ImageUrl AS SightseeingImageUrl
        FROM [' + @DatabaseName + N'].dbo.PackageDaySightseeings pds
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageDays pd ON pds.PackageDayId = pd.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.Sightseeings s ON pds.SightseeingId = s.Id
        WHERE pd.PackageId = @id
        ORDER BY pds.PackageDayId, pds.Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.BankAccounts
        WHERE IsActive = 1
        ORDER BY IsDefault DESC, Id;';
    EXEC sp_executesql @sql, N'@id INT', @id;

    -- Agent (creator) — all fields now live on MasterUsers since Employees was merged in.
    SELECT FullName, Email, Mobile, ProfileImageUrl AS ImageUrl
    FROM dbo.MasterUsers WHERE Id = @createdBy;

    -- Company branding (greeting + why-book-with-us JSON).
    SELECT GreetingParagraph, WhyBookWithUs
    FROM dbo.Companies
    WHERE DatabaseName = @DatabaseName;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_BackfillShareTokens
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Packages
        SET ShareToken = LOWER(REPLACE(CAST(NEWID() AS NVARCHAR(40)), ''-'', ''''))
        WHERE ShareToken IS NULL;';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @Title           NVARCHAR(200),
    @DestinationId   INT           = NULL,
    @CustomerName    NVARCHAR(150),
    @CustomerMobile  NVARCHAR(30)  = NULL,
    @CustomerEmail   NVARCHAR(150) = NULL,
    @Adults          INT           = 1,
    @Children        INT           = 0,
    @Infants         INT           = 0,
    @Days            INT           = NULL,
    @Nights          INT           = NULL,
    @StartDate       DATE          = NULL,
    @PriceMode       NVARCHAR(20)  = 'Total',
    @Currency        NVARCHAR(10)  = 'INR',
    @FlightDetails   NVARCHAR(MAX) = NULL,
    @Inclusions      NVARCHAR(MAX) = NULL,
    @Exclusions      NVARCHAR(MAX) = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @UpdatedBy       INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Packages
        SET Title = @Title, DestinationId = @DestinationId,
            CustomerName = @CustomerName, CustomerMobile = @CustomerMobile, CustomerEmail = @CustomerEmail,
            Adults = @Adults, Children = @Children, Infants = @Infants,
            Days = @Days, Nights = @Nights, StartDate = @StartDate,
            PriceMode = @PriceMode, Currency = @Currency,
            FlightDetails = @FlightDetails, Inclusions = @Inclusions, Exclusions = @Exclusions,
            Notes = @Notes,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Title NVARCHAR(200), @DestinationId INT, @CustomerName NVARCHAR(150), @CustomerMobile NVARCHAR(30), @CustomerEmail NVARCHAR(150), @Adults INT, @Children INT, @Infants INT, @Days INT, @Nights INT, @StartDate DATE, @PriceMode NVARCHAR(20), @Currency NVARCHAR(10), @FlightDetails NVARCHAR(MAX), @Inclusions NVARCHAR(MAX), @Exclusions NVARCHAR(MAX), @Notes NVARCHAR(MAX), @UpdatedBy INT',
        @Id, @Title, @DestinationId, @CustomerName, @CustomerMobile, @CustomerEmail,
        @Adults, @Children, @Infants, @Days, @Nights, @StartDate, @PriceMode, @Currency,
        @FlightDetails, @Inclusions, @Exclusions, @Notes, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Packages SET IsActive = 0 WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- Replace all options + their hotels for a package (transactional rebuild)
CREATE OR ALTER PROCEDURE sp_Package_ReplaceOptions
    @DatabaseName NVARCHAR(100),
    @PackageId    INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DELETE FROM [' + @DatabaseName + N'].dbo.PackageOptionHotels
        WHERE PackageOptionId IN (SELECT Id FROM [' + @DatabaseName + N'].dbo.PackageOptions WHERE PackageId = @PackageId);

        DELETE FROM [' + @DatabaseName + N'].dbo.PackageOptions WHERE PackageId = @PackageId;';
    EXEC sp_executesql @sql, N'@PackageId INT', @PackageId;
END
GO

CREATE OR ALTER PROCEDURE sp_PackageOption_Insert
    @DatabaseName   NVARCHAR(100),
    @PackageId      INT,
    @OptionName     NVARCHAR(150),
    @DisplayOrder   INT           = 0,
    @LandPrice      DECIMAL(18,2) = 0,
    @FlightPrice    DECIMAL(18,2) = 0,
    @FinalPrice     DECIMAL(18,2) = 0,
    @IsRecommended  BIT           = 0,
    @Notes          NVARCHAR(MAX) = NULL,
    @NewId          INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PackageOptions
            (PackageId, OptionName, DisplayOrder, LandPrice, FlightPrice, FinalPrice, IsRecommended, Notes)
        VALUES (@PackageId, @OptionName, @DisplayOrder, @LandPrice, @FlightPrice, @FinalPrice, @IsRecommended, @Notes);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@PackageId INT, @OptionName NVARCHAR(150), @DisplayOrder INT, @LandPrice DECIMAL(18,2), @FlightPrice DECIMAL(18,2), @FinalPrice DECIMAL(18,2), @IsRecommended BIT, @Notes NVARCHAR(MAX), @NewId INT OUTPUT',
        @PackageId, @OptionName, @DisplayOrder, @LandPrice, @FlightPrice, @FinalPrice, @IsRecommended, @Notes, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_PackageOptionHotel_Insert
    @DatabaseName     NVARCHAR(100),
    @PackageOptionId  INT,
    @DisplayOrder     INT           = 0,
    @Nights           INT           = 1,
    @HotelId          INT           = NULL,
    @RoomTypeId       INT           = NULL,
    @MealPlanId       INT           = NULL,
    @OtherText        NVARCHAR(300) = NULL,
    @Rooms            INT           = 1,
    @ExtraBeds        INT           = 0,
    @HotelCnfNo       NVARCHAR(60)  = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PackageOptionHotels
            (PackageOptionId, DisplayOrder, Nights, HotelId, RoomTypeId, MealPlanId, OtherText, Rooms, ExtraBeds, HotelCnfNo)
        VALUES (@PackageOptionId, @DisplayOrder, @Nights, @HotelId, @RoomTypeId, @MealPlanId, @OtherText, @Rooms, @ExtraBeds, @HotelCnfNo)';
    EXEC sp_executesql @sql,
        N'@PackageOptionId INT, @DisplayOrder INT, @Nights INT, @HotelId INT, @RoomTypeId INT, @MealPlanId INT,
          @OtherText NVARCHAR(300), @Rooms INT, @ExtraBeds INT, @HotelCnfNo NVARCHAR(60)',
        @PackageOptionId, @DisplayOrder, @Nights, @HotelId, @RoomTypeId, @MealPlanId, @OtherText,
        @Rooms, @ExtraBeds, @HotelCnfNo;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_ReplaceDays
    @DatabaseName NVARCHAR(100),
    @PackageId    INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DELETE FROM [' + @DatabaseName + N'].dbo.PackageDaySightseeings
        WHERE PackageDayId IN (SELECT Id FROM [' + @DatabaseName + N'].dbo.PackageDays WHERE PackageId = @PackageId);

        DELETE FROM [' + @DatabaseName + N'].dbo.PackageDays WHERE PackageId = @PackageId;';
    EXEC sp_executesql @sql, N'@PackageId INT', @PackageId;
END
GO

CREATE OR ALTER PROCEDURE sp_PackageDay_Insert
    @DatabaseName NVARCHAR(100),
    @PackageId    INT,
    @DayNumber    INT,
    @Title        NVARCHAR(200),
    @Description  NVARCHAR(MAX) = NULL,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PackageDays (PackageId, DayNumber, Title, Description)
        VALUES (@PackageId, @DayNumber, @Title, @Description);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@PackageId INT, @DayNumber INT, @Title NVARCHAR(200), @Description NVARCHAR(MAX), @NewId INT OUTPUT',
        @PackageId, @DayNumber, @Title, @Description, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_PackageDaySightseeing_Insert
    @DatabaseName   NVARCHAR(100),
    @PackageDayId   INT,
    @SightseeingId  INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PackageDaySightseeings (PackageDayId, SightseeingId)
        VALUES (@PackageDayId, @SightseeingId)';
    EXEC sp_executesql @sql,
        N'@PackageDayId INT, @SightseeingId INT',
        @PackageDayId, @SightseeingId;
END
GO

-- ============================================================
-- BOOKINGS  (cross-DB; numbering = {Prefix}-{YYYY}-{NNNN} per tenant per year)
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Booking_GetAll
    @DatabaseName NVARCHAR(100),
    @Search       NVARCHAR(150) = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @ScopeUserId  INT           = NULL,    -- when set, only bookings the user owns / is assigned via lead
    @Page         INT           = 1,
    @PageSize     INT           = 20
AS BEGIN
    SET NOCOUNT ON;
    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 200 SET @PageSize = 200;

    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT b.*,
               d.Name          AS DestinationName,
               l.LeadNumber    AS LeadNumber,
               p.PackageNumber AS PackageNumber,
               (SELECT COUNT(1)              FROM [' + @DatabaseName + N'].dbo.BookingInstallments i WHERE i.BookingId = b.Id) AS InstallmentCount,
               (SELECT ISNULL(SUM(Amount),0) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i WHERE i.BookingId = b.Id AND i.PaymentStatus = ''Received'') AS PaidAmount,
               COUNT(*) OVER() AS TotalCount
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON b.DestinationId = d.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Leads        l ON b.LeadId        = l.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Packages     p ON b.PackageId     = p.Id
        WHERE b.IsActive = 1
          AND (@Status IS NULL OR b.Status = @Status)
          AND (@ScopeUserId IS NULL
               OR b.CreatedBy = @ScopeUserId
               OR l.AssignedToUserId = @ScopeUserId)
          AND (@Search IS NULL OR
               b.BookingNumber LIKE ''%'' + @Search + ''%'' OR
               b.InvoiceNumber LIKE ''%'' + @Search + ''%'' OR
               l.LeadNumber    LIKE ''%'' + @Search + ''%'' OR
               b.CustomerName  LIKE ''%'' + @Search + ''%'' OR
               b.CustomerMobile LIKE ''%'' + @Search + ''%'')
        ORDER BY b.CreatedAt DESC
        OFFSET ((@Page - 1) * @PageSize) ROWS
        FETCH NEXT @PageSize ROWS ONLY';
    EXEC sp_executesql @sql,
        N'@Search NVARCHAR(150), @Status NVARCHAR(20), @ScopeUserId INT, @Page INT, @PageSize INT',
        @Search, @Status, @ScopeUserId, @Page, @PageSize;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetByLead
    @DatabaseName NVARCHAR(100),
    @LeadId       INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*,
               d.Name          AS DestinationName,
               l.LeadNumber    AS LeadNumber,
               p.PackageNumber AS PackageNumber,
               (SELECT ISNULL(SUM(Amount),0) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i WHERE i.BookingId = b.Id AND i.PaymentStatus = ''Received'') AS PaidAmount
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON b.DestinationId = d.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Leads        l ON b.LeadId        = l.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Packages     p ON b.PackageId     = p.Id
        WHERE b.LeadId = @LeadId AND b.IsActive = 1
        ORDER BY b.CreatedAt DESC';
    EXEC sp_executesql @sql, N'@LeadId INT', @LeadId;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT b.*,
               d.Name          AS DestinationName,
               d.PackageTerms  AS DestinationTerms,
               l.LeadNumber    AS LeadNumber,
               p.PackageNumber AS PackageNumber
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON b.DestinationId = d.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Leads        l ON b.LeadId        = l.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Packages     p ON b.PackageId     = p.Id
        WHERE b.Id = @Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.BookingInstallments
        WHERE BookingId = @Id
        ORDER BY InstallmentNo, Id;

        SELECT * FROM [' + @DatabaseName + N'].dbo.BookingHotels
        WHERE BookingId = @Id
        ORDER BY DisplayOrder, Id;';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- Insert one snapshot hotel row when a booking is created.
CREATE OR ALTER PROCEDURE sp_BookingHotel_Insert
    @DatabaseName  NVARCHAR(100),
    @BookingId     INT,
    @DisplayOrder  INT           = 0,
    @Nights        INT           = 1,
    @HotelName     NVARCHAR(200) = NULL,
    @RoomTypeName  NVARCHAR(100) = NULL,
    @MealPlanCode  NVARCHAR(10)  = NULL,
    @MealPlanName  NVARCHAR(100) = NULL,
    @OtherText     NVARCHAR(300) = NULL,
    @Rooms         INT           = 1,
    @ExtraBeds     INT           = 0,
    @HotelCnfNo    NVARCHAR(60)  = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        INSERT INTO [' + @DatabaseName + N'].dbo.BookingHotels
            (BookingId, DisplayOrder, Nights, HotelName, RoomTypeName,
             MealPlanCode, MealPlanName, OtherText, Rooms, ExtraBeds, HotelCnfNo)
        VALUES (@BookingId, @DisplayOrder, @Nights, @HotelName, @RoomTypeName,
                @MealPlanCode, @MealPlanName, @OtherText, @Rooms, @ExtraBeds, @HotelCnfNo);';
    EXEC sp_executesql @sql,
        N'@BookingId INT, @DisplayOrder INT, @Nights INT, @HotelName NVARCHAR(200),
          @RoomTypeName NVARCHAR(100), @MealPlanCode NVARCHAR(10), @MealPlanName NVARCHAR(100),
          @OtherText NVARCHAR(300), @Rooms INT, @ExtraBeds INT, @HotelCnfNo NVARCHAR(60)',
        @BookingId, @DisplayOrder, @Nights, @HotelName, @RoomTypeName,
        @MealPlanCode, @MealPlanName, @OtherText, @Rooms, @ExtraBeds, @HotelCnfNo;
END
GO

-- Backfill BookingHotels for any existing booking that has none.
-- Looks up the booking's package option (by PackageId + OptionName) and
-- snapshots its current hotel rows. Safe to re-run; only fills empty ones.
CREATE OR ALTER PROCEDURE sp_Booking_BackfillHotels
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        INSERT INTO [' + @DatabaseName + N'].dbo.BookingHotels
            (BookingId, DisplayOrder, Nights, HotelName, RoomTypeName,
             MealPlanCode, MealPlanName, OtherText, Rooms, ExtraBeds, HotelCnfNo)
        SELECT
            b.Id, h.DisplayOrder, h.Nights,
            ho.Name, rt.Name, mp.Code, mp.Name,
            h.OtherText, h.Rooms, h.ExtraBeds, h.HotelCnfNo
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageOptions     o
            ON o.PackageId = b.PackageId AND o.OptionName = b.OptionName
        INNER JOIN [' + @DatabaseName + N'].dbo.PackageOptionHotels h ON h.PackageOptionId = o.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.Hotels    ho ON h.HotelId    = ho.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.RoomTypes rt ON h.RoomTypeId = rt.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.MealPlans mp ON h.MealPlanId = mp.Id
        WHERE b.IsActive = 1
          AND b.PackageId IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [' + @DatabaseName + N'].dbo.BookingHotels bh WHERE bh.BookingId = b.Id);';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_Insert
    @DatabaseName    NVARCHAR(100),
    @BookingPrefix   NVARCHAR(20)  = 'BK',
    @InvoicePrefix   NVARCHAR(20)  = 'INV',
    @LeadId          INT           = NULL,
    @PackageId       INT           = NULL,
    @PackageOptionId INT           = NULL,
    @OptionName      NVARCHAR(150) = NULL,
    @CustomerName    NVARCHAR(150),
    @CustomerMobile  NVARCHAR(30)  = NULL,
    @CustomerEmail   NVARCHAR(150) = NULL,
    @Adults          INT           = 1,
    @Children        INT           = 0,
    @Infants         INT           = 0,
    @StartDate       DATE          = NULL,
    @EndDate         DATE          = NULL,
    @Days            INT           = NULL,
    @Nights          INT           = NULL,
    @DestinationId   INT           = NULL,
    @TotalAmount     DECIMAL(18,2) = 0,
    @Currency        NVARCHAR(10)  = 'INR',
    @Status          NVARCHAR(20)  = 'Confirmed',
    @Notes           NVARCHAR(MAX) = NULL,
    @CreatedBy       INT           = 0,
    @NewId           INT           OUTPUT,
    @BookingNumber   NVARCHAR(40)  OUTPUT,
    @InvoiceNumber   NVARCHAR(40)  OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    IF @BookingPrefix IS NULL OR LEN(@BookingPrefix) = 0 SET @BookingPrefix = N'BK';
    IF @InvoicePrefix IS NULL OR LEN(@InvoicePrefix) = 0 SET @InvoicePrefix = N'INV';

    DECLARE @year INT = YEAR(GETUTCDATE());
    DECLARE @bkCount INT = 0, @invCount INT = 0;
    DECLARE @bkPat  NVARCHAR(60) = @BookingPrefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-%';
    DECLARE @invPat NVARCHAR(60) = @InvoicePrefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-%';

    DECLARE @countSql NVARCHAR(MAX) = N'
        SELECT @bk = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings WHERE BookingNumber LIKE @bkPat;
        SELECT @inv = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings WHERE InvoiceNumber LIKE @invPat;';
    EXEC sp_executesql @countSql,
        N'@bk INT OUTPUT, @inv INT OUTPUT, @bkPat NVARCHAR(60), @invPat NVARCHAR(60)',
        @bk = @bkCount OUTPUT, @inv = @invCount OUTPUT, @bkPat = @bkPat, @invPat = @invPat;

    SET @BookingNumber = @BookingPrefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-' +
                         RIGHT(N'0000' + CAST((@bkCount + 1) AS NVARCHAR(10)), 4);
    SET @InvoiceNumber = @InvoicePrefix + N'-' + CAST(@year AS NVARCHAR(4)) + N'-' +
                         RIGHT(N'0000' + CAST((@invCount + 1) AS NVARCHAR(10)), 4);

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Bookings
            (BookingNumber, InvoiceNumber, LeadId, PackageId, PackageOptionId, OptionName,
             CustomerName, CustomerMobile, CustomerEmail,
             Adults, Children, Infants,
             StartDate, EndDate, Days, Nights,
             DestinationId, TotalAmount, Currency, Status, Notes,
             IsActive, CreatedAt, CreatedBy)
        VALUES
            (@BookingNumber, @InvoiceNumber, @LeadId, @PackageId, @PackageOptionId, @OptionName,
             @CustomerName, @CustomerMobile, @CustomerEmail,
             @Adults, @Children, @Infants,
             @StartDate, @EndDate, @Days, @Nights,
             @DestinationId, @TotalAmount, @Currency, @Status, @Notes,
             1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@BookingNumber NVARCHAR(40), @InvoiceNumber NVARCHAR(40),
          @LeadId INT, @PackageId INT, @PackageOptionId INT, @OptionName NVARCHAR(150),
          @CustomerName NVARCHAR(150), @CustomerMobile NVARCHAR(30), @CustomerEmail NVARCHAR(150),
          @Adults INT, @Children INT, @Infants INT,
          @StartDate DATE, @EndDate DATE, @Days INT, @Nights INT,
          @DestinationId INT, @TotalAmount DECIMAL(18,2), @Currency NVARCHAR(10),
          @Status NVARCHAR(20), @Notes NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @BookingNumber, @InvoiceNumber,
        @LeadId, @PackageId, @PackageOptionId, @OptionName,
        @CustomerName, @CustomerMobile, @CustomerEmail,
        @Adults, @Children, @Infants,
        @StartDate, @EndDate, @Days, @Nights,
        @DestinationId, @TotalAmount, @Currency, @Status, @Notes, @CreatedBy,
        @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @CustomerName    NVARCHAR(150),
    @CustomerMobile  NVARCHAR(30)  = NULL,
    @CustomerEmail   NVARCHAR(150) = NULL,
    @Adults          INT           = 1,
    @Children        INT           = 0,
    @Infants         INT           = 0,
    @StartDate       DATE          = NULL,
    @EndDate         DATE          = NULL,
    @Days            INT           = NULL,
    @Nights          INT           = NULL,
    @DestinationId   INT           = NULL,
    @TotalAmount     DECIMAL(18,2) = 0,
    @Currency        NVARCHAR(10)  = 'INR',
    @Status          NVARCHAR(20)  = 'Confirmed',
    @Notes           NVARCHAR(MAX) = NULL,
    @UpdatedBy       INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Bookings SET
            CustomerName = @CustomerName, CustomerMobile = @CustomerMobile, CustomerEmail = @CustomerEmail,
            Adults = @Adults, Children = @Children, Infants = @Infants,
            StartDate = @StartDate, EndDate = @EndDate, Days = @Days, Nights = @Nights,
            DestinationId = @DestinationId,
            TotalAmount = @TotalAmount, Currency = @Currency,
            Status = @Status, Notes = @Notes,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @CustomerName NVARCHAR(150), @CustomerMobile NVARCHAR(30), @CustomerEmail NVARCHAR(150),
          @Adults INT, @Children INT, @Infants INT,
          @StartDate DATE, @EndDate DATE, @Days INT, @Nights INT,
          @DestinationId INT, @TotalAmount DECIMAL(18,2), @Currency NVARCHAR(10),
          @Status NVARCHAR(20), @Notes NVARCHAR(MAX), @UpdatedBy INT',
        @Id, @CustomerName, @CustomerMobile, @CustomerEmail,
        @Adults, @Children, @Infants,
        @StartDate, @EndDate, @Days, @Nights,
        @DestinationId, @TotalAmount, @Currency, @Status, @Notes, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Bookings
        SET IsActive = 0, UpdatedAt = GETUTCDATE()
        WHERE Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_ReplaceInstallments
    @DatabaseName NVARCHAR(100),
    @BookingId    INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        DELETE FROM [' + @DatabaseName + N'].dbo.BookingInstallments WHERE BookingId = @BookingId';
    EXEC sp_executesql @sql, N'@BookingId INT', @BookingId;
END
GO

-- ============================================================
-- DASHBOARD SUMMARY  (6 result sets in one round-trip)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Dashboard_GetSummary
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    -- CAST forces the first literal to NVARCHAR(MAX); without it the whole
    -- concatenated string truncates to 4000 chars and later result sets vanish.
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        DECLARE @today DATE = CAST(GETUTCDATE() AS DATE);
        DECLARE @weekAgo DATE = DATEADD(DAY, -7, @today);
        DECLARE @monthStart DATE = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1);
        DECLARE @sixMonthsAgo DATE = DATEADD(MONTH, -5, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));

        ----------------------------------------------------------------
        -- 1) KPI counters (single row)
        ----------------------------------------------------------------
        SELECT
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads) AS TotalLeads,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads l
             LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
             WHERE ISNULL(s.IsClosed, 0) = 0) AS ActiveLeads,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads
             WHERE CAST(CreatedAt AS DATE) >= @weekAgo) AS NewLeadsThisWeek,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Bookings
             WHERE IsActive = 1 AND CAST(CreatedAt AS DATE) >= @monthStart) AS BookingsThisMonth,
            (SELECT ISNULL(SUM(TotalAmount), 0) FROM [' + @DatabaseName + N'].dbo.Bookings
             WHERE IsActive = 1 AND CAST(CreatedAt AS DATE) >= @monthStart) AS RevenueThisMonth,
            (SELECT ISNULL(SUM(b.TotalAmount), 0) - ISNULL(
                (SELECT SUM(i.Amount) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
                 INNER JOIN [' + @DatabaseName + N'].dbo.Bookings bb ON i.BookingId = bb.Id
                 WHERE bb.IsActive = 1 AND i.PaymentStatus = ''Received''), 0)
             FROM [' + @DatabaseName + N'].dbo.Bookings b WHERE b.IsActive = 1) AS OutstandingBalance,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
             INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
             WHERE b.IsActive = 1 AND i.PaymentStatus = ''Pending''
               AND i.DueDate IS NOT NULL AND i.DueDate < @today) AS OverdueInstallmentsCount,
            (SELECT ISNULL(SUM(i.Amount), 0) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
             INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
             WHERE b.IsActive = 1 AND i.PaymentStatus = ''Pending''
               AND i.DueDate IS NOT NULL AND i.DueDate < @today) AS OverdueAmount,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Packages WHERE IsActive = 1) AS TotalPackages,
            (SELECT ISNULL(SUM(i.Amount), 0) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
             INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
             WHERE b.IsActive = 1 AND i.PaymentStatus = ''Received''
               AND CAST(i.ReceivedDate AS DATE) >= @monthStart) AS CollectedThisMonth;

        ----------------------------------------------------------------
        -- 2) Revenue trend — last 6 months including current
        ----------------------------------------------------------------
        ;WITH Months AS (
            SELECT 0 AS Offset
            UNION ALL SELECT 1 UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
        )
        SELECT
            YEAR(DATEADD(MONTH, -m.Offset, @monthStart))  AS YearNo,
            MONTH(DATEADD(MONTH, -m.Offset, @monthStart)) AS MonthNo,
            DATENAME(MONTH, DATEADD(MONTH, -m.Offset, @monthStart)) AS MonthLabel,
            ISNULL(SUM(b.TotalAmount), 0)                 AS Revenue,
            COUNT(b.Id)                                   AS BookingCount
        FROM Months m
        LEFT JOIN [' + @DatabaseName + N'].dbo.Bookings b
            ON b.IsActive = 1
           AND YEAR(b.CreatedAt)  = YEAR(DATEADD(MONTH, -m.Offset, @monthStart))
           AND MONTH(b.CreatedAt) = MONTH(DATEADD(MONTH, -m.Offset, @monthStart))
        GROUP BY m.Offset
        ORDER BY m.Offset DESC;

        ----------------------------------------------------------------
        -- 3) Leads-by-status counts
        ----------------------------------------------------------------
        SELECT
            ISNULL(s.Name, ''No Status'') AS StatusName,
            ISNULL(s.Color, ''secondary'') AS StatusColor,
            COUNT(l.Id) AS LeadCount
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
        GROUP BY s.Name, s.Color, s.DisplayOrder
        ORDER BY ISNULL(s.DisplayOrder, 999), StatusName;

        ----------------------------------------------------------------
        -- 4) Recent leads (last 5)
        ----------------------------------------------------------------
        SELECT TOP 5
            l.Id, l.LeadNumber, l.Name, l.Mobile, l.CreatedAt,
            ISNULL(s.Name, ''New'') AS StatusName,
            ISNULL(s.Color, ''secondary'') AS StatusColor,
            d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON l.DestinationId = d.Id
        ORDER BY l.CreatedAt DESC;

        ----------------------------------------------------------------
        -- 5) Upcoming travel (active bookings starting in next 30 days)
        ----------------------------------------------------------------
        SELECT TOP 5
            b.Id, b.BookingNumber, b.CustomerName, b.StartDate, b.Days,
            b.TotalAmount, b.Currency, b.Status,
            d.Name AS DestinationName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON b.DestinationId = d.Id
        WHERE b.IsActive = 1
          AND b.Status <> ''Cancelled''
          AND b.StartDate IS NOT NULL
          AND b.StartDate >= @today
          AND b.StartDate <= DATEADD(DAY, 30, @today)
        ORDER BY b.StartDate ASC;

        ----------------------------------------------------------------
        -- 6) Overdue installments (top 5)
        ----------------------------------------------------------------
        SELECT TOP 5
            i.Id, i.BookingId, i.InstallmentNo, i.Amount, i.DueDate,
            DATEDIFF(DAY, i.DueDate, @today) AS DaysOverdue,
            b.BookingNumber, b.CustomerName, b.Currency
        FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
        INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
        WHERE b.IsActive = 1
          AND i.PaymentStatus = ''Pending''
          AND i.DueDate IS NOT NULL
          AND i.DueDate < @today
        ORDER BY i.DueDate ASC;';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- REPORTS  (cross-DB)
-- ============================================================

-- Sales Summary — KPIs + monthly trend over the date range
CREATE OR ALTER PROCEDURE sp_Report_SalesSummary
    @DatabaseName NVARCHAR(100),
    @From         DATE,
    @To           DATE
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        -- 1) KPIs
        SELECT
            COUNT(*)              AS BookingCount,
            ISNULL(SUM(b.TotalAmount), 0) AS TotalRevenue,
            CAST(ISNULL(AVG(NULLIF(b.TotalAmount, 0)), 0) AS DECIMAL(18,2)) AS AvgBookingValue,
            (SELECT ISNULL(SUM(i.Amount), 0) FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
                INNER JOIN [' + @DatabaseName + N'].dbo.Bookings bb ON i.BookingId = bb.Id
                WHERE bb.IsActive = 1 AND bb.IsActive = 1
                  AND CAST(bb.CreatedAt AS DATE) BETWEEN @From AND @To
                  AND i.PaymentStatus = ''Received'') AS Collected,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads
                WHERE CAST(CreatedAt AS DATE) BETWEEN @From AND @To) AS LeadCount
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        WHERE b.IsActive = 1
          AND CAST(b.CreatedAt AS DATE) BETWEEN @From AND @To;

        -- 2) Monthly trend
        SELECT
            YEAR(b.CreatedAt)    AS YearNo,
            MONTH(b.CreatedAt)   AS MonthNo,
            DATENAME(MONTH, b.CreatedAt) AS MonthLabel,
            COUNT(*)             AS BookingCount,
            ISNULL(SUM(b.TotalAmount), 0) AS Revenue
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        WHERE b.IsActive = 1
          AND CAST(b.CreatedAt AS DATE) BETWEEN @From AND @To
        GROUP BY YEAR(b.CreatedAt), MONTH(b.CreatedAt), DATENAME(MONTH, b.CreatedAt)
        ORDER BY YEAR(b.CreatedAt), MONTH(b.CreatedAt);';
    EXEC sp_executesql @sql, N'@From DATE, @To DATE', @From, @To;
END
GO

-- Sales by Destination
CREATE OR ALTER PROCEDURE sp_Report_SalesByDestination
    @DatabaseName NVARCHAR(100),
    @From         DATE,
    @To           DATE
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT
            ISNULL(d.Name, ''— No Destination —'') AS DestinationName,
            COUNT(b.Id)              AS BookingCount,
            ISNULL(SUM(b.TotalAmount), 0) AS TotalRevenue,
            CAST(ISNULL(AVG(NULLIF(b.TotalAmount, 0)), 0) AS DECIMAL(18,2)) AS AvgBookingValue
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Destinations d ON b.DestinationId = d.Id
        WHERE b.IsActive = 1
          AND CAST(b.CreatedAt AS DATE) BETWEEN @From AND @To
        GROUP BY d.Name
        ORDER BY TotalRevenue DESC;';
    EXEC sp_executesql @sql, N'@From DATE, @To DATE', @From, @To;
END
GO

-- Sales by Agent — joins MasterUsers (master DB) with Bookings.CreatedBy
CREATE OR ALTER PROCEDURE sp_Report_SalesByAgent
    @DatabaseName NVARCHAR(100),
    @From         DATE,
    @To           DATE
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT
            ISNULL(mu.FullName, ''— Unknown —'') AS AgentName,
            COUNT(b.Id)              AS BookingCount,
            ISNULL(SUM(b.TotalAmount), 0) AS TotalRevenue,
            CAST(ISNULL(AVG(NULLIF(b.TotalAmount, 0)), 0) AS DECIMAL(18,2)) AS AvgBookingValue
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN dbo.MasterUsers mu ON b.CreatedBy = mu.Id
        WHERE b.IsActive = 1
          AND CAST(b.CreatedAt AS DATE) BETWEEN @From AND @To
        GROUP BY mu.FullName
        ORDER BY TotalRevenue DESC;';
    EXEC sp_executesql @sql, N'@From DATE, @To DATE', @From, @To;
END
GO

-- Payment Aging — outstanding installments grouped by overdue buckets
CREATE OR ALTER PROCEDURE sp_Report_PaymentAging
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        DECLARE @today DATE = CAST(GETUTCDATE() AS DATE);
        SELECT
            CASE
                WHEN i.DueDate IS NULL OR i.DueDate >= @today THEN ''Current''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 1 AND 30  THEN ''1-30 days''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 31 AND 60 THEN ''31-60 days''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 61 AND 90 THEN ''61-90 days''
                ELSE ''90+ days''
            END                                AS Bucket,
            CASE
                WHEN i.DueDate IS NULL OR i.DueDate >= @today THEN 0
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 1 AND 30  THEN 1
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 31 AND 60 THEN 2
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 61 AND 90 THEN 3
                ELSE 4
            END                                AS BucketOrder,
            COUNT(*)                           AS InstallmentCount,
            ISNULL(SUM(i.Amount), 0)           AS Outstanding
        FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
        INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
        WHERE b.IsActive = 1
          AND b.Status <> ''Cancelled''
          AND i.PaymentStatus = ''Pending''
        GROUP BY
            CASE
                WHEN i.DueDate IS NULL OR i.DueDate >= @today THEN ''Current''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 1 AND 30  THEN ''1-30 days''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 31 AND 60 THEN ''31-60 days''
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 61 AND 90 THEN ''61-90 days''
                ELSE ''90+ days''
            END,
            CASE
                WHEN i.DueDate IS NULL OR i.DueDate >= @today THEN 0
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 1 AND 30  THEN 1
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 31 AND 60 THEN 2
                WHEN DATEDIFF(DAY, i.DueDate, @today) BETWEEN 61 AND 90 THEN 3
                ELSE 4
            END
        ORDER BY BucketOrder;

        -- Detail rows: each pending installment with customer + days overdue
        SELECT
            b.Id                  AS BookingId,
            b.BookingNumber,
            b.CustomerName,
            b.Currency,
            i.InstallmentNo,
            i.Amount,
            i.DueDate,
            CASE WHEN i.DueDate IS NULL OR i.DueDate >= @today THEN 0
                 ELSE DATEDIFF(DAY, i.DueDate, @today) END AS DaysOverdue
        FROM [' + @DatabaseName + N'].dbo.BookingInstallments i
        INNER JOIN [' + @DatabaseName + N'].dbo.Bookings b ON i.BookingId = b.Id
        WHERE b.IsActive = 1
          AND b.Status <> ''Cancelled''
          AND i.PaymentStatus = ''Pending''
        ORDER BY i.DueDate;';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- LEAD ACTIVITY · TODAY PANEL  (3 result sets: overdue / today / upcoming)
-- A scheduled follow-up has IsCompleted=0 + NextFollowUpAt set.
-- ============================================================
CREATE OR ALTER PROCEDURE sp_LeadActivity_GetTodayPanel
    @DatabaseName NVARCHAR(100),
    @UserId       INT  = NULL,    -- when @MyOnly=1, restrict to the lead's assigned agent
    @MyOnly       BIT  = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        DECLARE @startOfDay DATETIME2 = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2);
        DECLARE @endOfDay   DATETIME2 = DATEADD(SECOND, -1, DATEADD(DAY, 1, @startOfDay));
        DECLARE @endOfWeek  DATETIME2 = DATEADD(DAY, 7, @startOfDay);

        -- Build the work set once into a temp table so we can re-query it in
        -- multiple result sets. (CTEs in SQL Server only live for one statement.)
        SELECT a.Id, a.LeadId, a.ActivityType, a.Subject, a.Notes, a.ActivityAt,
               a.NextFollowUpAt, a.IsCompleted, a.CreatedByUserId, a.CreatedAt, a.UpdatedAt,
               l.LeadNumber, l.Name AS LeadName, l.Mobile AS LeadMobile, l.Email AS LeadEmail,
               l.AssignedToUserId,
               s.Name  AS LeadStatusName,
               s.Color AS LeadStatusColor
        INTO   #base
        FROM [' + @DatabaseName + N'].dbo.LeadActivities a
        INNER JOIN [' + @DatabaseName + N'].dbo.Leads        l ON a.LeadId   = l.Id
        LEFT JOIN  [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
        WHERE a.IsCompleted = 0
          AND a.NextFollowUpAt IS NOT NULL
          AND (@MyOnly = 0 OR l.AssignedToUserId = @UserId);

        -- 1) Overdue
        SELECT *,
               DATEDIFF(DAY, NextFollowUpAt, @startOfDay) AS DaysOverdue
        FROM #base
        WHERE NextFollowUpAt < @startOfDay
        ORDER BY NextFollowUpAt ASC;

        -- 2) Today
        SELECT *
        FROM #base
        WHERE NextFollowUpAt BETWEEN @startOfDay AND @endOfDay
        ORDER BY NextFollowUpAt ASC;

        -- 3) Upcoming (next 7 days)
        SELECT *,
               DATEDIFF(DAY, @startOfDay, NextFollowUpAt) AS DaysUntil
        FROM #base
        WHERE NextFollowUpAt > @endOfDay AND NextFollowUpAt <= @endOfWeek
        ORDER BY NextFollowUpAt ASC;

        -- 4) Summary counters (for navbar badge)
        SELECT
            (SELECT COUNT(*) FROM #base WHERE NextFollowUpAt < @startOfDay) AS OverdueCount,
            (SELECT COUNT(*) FROM #base WHERE NextFollowUpAt BETWEEN @startOfDay AND @endOfDay) AS TodayCount,
            (SELECT COUNT(*) FROM #base WHERE NextFollowUpAt > @endOfDay AND NextFollowUpAt <= @endOfWeek) AS UpcomingCount;

        DROP TABLE #base;';
    EXEC sp_executesql @sql,
        N'@UserId INT, @MyOnly BIT',
        @UserId, @MyOnly;
END
GO

-- ============================================================
-- EMAIL LOGS  (cross-DB)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_EmailLog_Insert
    @DatabaseName    NVARCHAR(100),
    @RelatedType     NVARCHAR(20),
    @RelatedId       INT           = NULL,
    @ToEmail         NVARCHAR(500),
    @CcEmail         NVARCHAR(500) = NULL,
    @Subject         NVARCHAR(500),
    @BodyPreview     NVARCHAR(1000)= NULL,
    @AttachmentNames NVARCHAR(500) = NULL,
    @Status          NVARCHAR(20)  = 'Sent',
    @ErrorMessage    NVARCHAR(MAX) = NULL,
    @SentBy          INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        INSERT INTO [' + @DatabaseName + N'].dbo.EmailLogs
            (RelatedType, RelatedId, ToEmail, CcEmail, Subject, BodyPreview, AttachmentNames, Status, ErrorMessage, SentAt, SentBy)
        VALUES
            (@RelatedType, @RelatedId, @ToEmail, @CcEmail, @Subject, @BodyPreview, @AttachmentNames, @Status, @ErrorMessage, GETUTCDATE(), @SentBy);';
    EXEC sp_executesql @sql,
        N'@RelatedType NVARCHAR(20), @RelatedId INT, @ToEmail NVARCHAR(500), @CcEmail NVARCHAR(500),
          @Subject NVARCHAR(500), @BodyPreview NVARCHAR(1000), @AttachmentNames NVARCHAR(500),
          @Status NVARCHAR(20), @ErrorMessage NVARCHAR(MAX), @SentBy INT',
        @RelatedType, @RelatedId, @ToEmail, @CcEmail, @Subject, @BodyPreview,
        @AttachmentNames, @Status, @ErrorMessage, @SentBy;
END
GO

CREATE OR ALTER PROCEDURE sp_EmailLog_GetByRelated
    @DatabaseName NVARCHAR(100),
    @RelatedType  NVARCHAR(20),
    @RelatedId    INT,
    @Top          INT = 10
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT TOP (@Top) *
        FROM [' + @DatabaseName + N'].dbo.EmailLogs
        WHERE RelatedType = @RelatedType AND RelatedId = @RelatedId
        ORDER BY SentAt DESC;';
    EXEC sp_executesql @sql,
        N'@Top INT, @RelatedType NVARCHAR(20), @RelatedId INT',
        @Top, @RelatedType, @RelatedId;
END
GO

-- ============================================================
-- DASHBOARD · MONTHLY BREAKDOWN  (filtered by year)
-- Returns 2 sets:
--   1) per-month rows: Year, Month, MonthLabel, TotalLeads, TotalNotes, TotalQuotes
--   2) per-month per-status rows: Year, Month, StatusName, StatusColor, LeadCount
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Dashboard_GetMonthlyBreakdown
    @DatabaseName NVARCHAR(100),
    @Year         INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        ;WITH Months AS (
            SELECT 1 AS m UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
            UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        )
        -- 1) per-month aggregate counts
        SELECT
            @Year AS YearNo,
            m.m   AS MonthNo,
            DATENAME(MONTH, DATEFROMPARTS(@Year, m.m, 1)) AS MonthLabel,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads
                WHERE YEAR(CreatedAt) = @Year AND MONTH(CreatedAt) = m.m) AS TotalLeads,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.LeadActivities
                WHERE YEAR(CreatedAt) = @Year AND MONTH(CreatedAt) = m.m) AS TotalNotes,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Packages
                WHERE YEAR(CreatedAt) = @Year AND MONTH(CreatedAt) = m.m AND IsActive = 1) AS TotalQuotes
        FROM Months m
        ORDER BY m.m;

        -- 2) per-month leads-by-status breakdown
        SELECT
            @Year                                  AS YearNo,
            MONTH(l.CreatedAt)                     AS MonthNo,
            ISNULL(s.Name,  ''No Status'')         AS StatusName,
            ISNULL(s.Color, ''secondary'')         AS StatusColor,
            COUNT(l.Id)                            AS LeadCount
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
        WHERE YEAR(l.CreatedAt) = @Year
        GROUP BY MONTH(l.CreatedAt), s.Name, s.Color, s.DisplayOrder
        ORDER BY MONTH(l.CreatedAt), ISNULL(s.DisplayOrder, 999);';

    EXEC sp_executesql @sql, N'@Year INT', @Year;
END
GO

-- ============================================================
-- DASHBOARD · RANGE SUMMARY  (date-range picker)
-- Returns 2 sets:
--   1) single-row counts: TotalLeads, TotalNotes, TotalQuotes
--   2) leads-by-status for the range (StatusName, StatusColor, LeadCount)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Dashboard_GetRangeSummary
    @DatabaseName NVARCHAR(100),
    @StartDate    DATE,
    @EndDate      DATE
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = CAST(N'' AS NVARCHAR(MAX)) + N'
        SELECT
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Leads
                WHERE CAST(CreatedAt AS DATE) BETWEEN @StartDate AND @EndDate) AS TotalLeads,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.LeadActivities
                WHERE CAST(CreatedAt AS DATE) BETWEEN @StartDate AND @EndDate) AS TotalNotes,
            (SELECT COUNT(*) FROM [' + @DatabaseName + N'].dbo.Packages
                WHERE IsActive = 1 AND CAST(CreatedAt AS DATE) BETWEEN @StartDate AND @EndDate) AS TotalQuotes;

        SELECT
            ISNULL(s.Name,  ''No Status'')  AS StatusName,
            ISNULL(s.Color, ''secondary'')  AS StatusColor,
            COUNT(l.Id)                     AS LeadCount
        FROM [' + @DatabaseName + N'].dbo.Leads l
        LEFT JOIN [' + @DatabaseName + N'].dbo.LeadStatuses s ON l.StatusId = s.Id
        WHERE CAST(l.CreatedAt AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY s.Name, s.Color, s.DisplayOrder
        HAVING COUNT(l.Id) > 0
        ORDER BY ISNULL(s.DisplayOrder, 999), StatusName;';

    EXEC sp_executesql @sql,
        N'@StartDate DATE, @EndDate DATE',
        @StartDate, @EndDate;
END
GO

CREATE OR ALTER PROCEDURE sp_BookingInstallment_Insert
    @DatabaseName   NVARCHAR(100),
    @BookingId      INT,
    @InstallmentNo  INT,
    @Amount         DECIMAL(18,2) = 0,
    @PaymentMode    NVARCHAR(50)  = NULL,
    @PaymentStatus  NVARCHAR(20)  = 'Pending',
    @DueDate        DATE          = NULL,
    @ReceivedDate   DATE          = NULL,
    @Remark         NVARCHAR(500) = NULL,
    @CreatedBy      INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.BookingInstallments
            (BookingId, InstallmentNo, Amount, PaymentMode, PaymentStatus, DueDate, ReceivedDate, Remark, CreatedAt, CreatedBy)
        VALUES
            (@BookingId, @InstallmentNo, @Amount, @PaymentMode, @PaymentStatus, @DueDate, @ReceivedDate, @Remark, GETUTCDATE(), @CreatedBy)';
    EXEC sp_executesql @sql,
        N'@BookingId INT, @InstallmentNo INT, @Amount DECIMAL(18,2),
          @PaymentMode NVARCHAR(50), @PaymentStatus NVARCHAR(20),
          @DueDate DATE, @ReceivedDate DATE, @Remark NVARCHAR(500), @CreatedBy INT',
        @BookingId, @InstallmentNo, @Amount, @PaymentMode, @PaymentStatus,
        @DueDate, @ReceivedDate, @Remark, @CreatedBy;
END
GO

-- ============================================================
-- SUBSCRIPTION PLAN PROCEDURES (Platform admin)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Plan_GetAll
    @IncludeInactive BIT = 0
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM SubscriptionPlans
    WHERE @IncludeInactive = 1 OR IsActive = 1
    ORDER BY DisplayOrder, MonthlyPrice;
END
GO

CREATE OR ALTER PROCEDURE sp_Plan_GetById
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM SubscriptionPlans WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Plan_Insert
    @Name         NVARCHAR(50),
    @MonthlyPrice DECIMAL(10,2),
    @YearlyPrice  DECIMAL(10,2),
    @MaxUsers     INT,
    @Features     NVARCHAR(MAX) = NULL,
    @IsActive     BIT           = 1,
    @Tagline      NVARCHAR(300) = NULL,
    @IconClass    NVARCHAR(50)  = NULL,
    @IconColor    NVARCHAR(20)  = NULL,
    @IsFeatured   BIT           = 0,
    @DisplayOrder INT           = 100,
    @CtaLabel     NVARCHAR(60)  = NULL,
    @CtaUrl       NVARCHAR(300) = NULL,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO SubscriptionPlans
        (Name, MonthlyPrice, YearlyPrice, MaxUsers, Features, IsActive,
         Tagline, IconClass, IconColor, IsFeatured, DisplayOrder, CtaLabel, CtaUrl, CreatedAt)
    VALUES
        (@Name, @MonthlyPrice, @YearlyPrice, @MaxUsers, @Features, @IsActive,
         @Tagline, @IconClass, @IconColor, @IsFeatured, @DisplayOrder, @CtaLabel, @CtaUrl, GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_Plan_Update
    @Id           INT,
    @Name         NVARCHAR(50),
    @MonthlyPrice DECIMAL(10,2),
    @YearlyPrice  DECIMAL(10,2),
    @MaxUsers     INT,
    @Features     NVARCHAR(MAX) = NULL,
    @IsActive     BIT,
    @Tagline      NVARCHAR(300) = NULL,
    @IconClass    NVARCHAR(50)  = NULL,
    @IconColor    NVARCHAR(20)  = NULL,
    @IsFeatured   BIT           = 0,
    @DisplayOrder INT           = 100,
    @CtaLabel     NVARCHAR(60)  = NULL,
    @CtaUrl       NVARCHAR(300) = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE SubscriptionPlans
    SET Name         = @Name,
        MonthlyPrice = @MonthlyPrice,
        YearlyPrice  = @YearlyPrice,
        MaxUsers     = @MaxUsers,
        Features     = @Features,
        IsActive     = @IsActive,
        Tagline      = @Tagline,
        IconClass    = @IconClass,
        IconColor    = @IconColor,
        IsFeatured   = @IsFeatured,
        DisplayOrder = @DisplayOrder,
        CtaLabel     = @CtaLabel,
        CtaUrl       = @CtaUrl
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Plan_SetActive
    @Id       INT,
    @IsActive BIT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE SubscriptionPlans SET IsActive = @IsActive WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Plan_Delete
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    -- Hard delete only if no companies are using it; otherwise soft-deactivate.
    IF EXISTS (SELECT 1 FROM Companies WHERE PlanName = (SELECT Name FROM SubscriptionPlans WHERE Id = @Id))
        UPDATE SubscriptionPlans SET IsActive = 0 WHERE Id = @Id;
    ELSE
        DELETE FROM SubscriptionPlans WHERE Id = @Id;
END
GO

-- ============================================================
-- COMPANY ADMIN PROCEDURES (Platform admin)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Company_UpdateStatus
    @Id        INT,
    @Status    TINYINT,
    @UpdatedBy INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        Status    = @Status,
        UpdatedAt = GETUTCDATE(),
        UpdatedBy = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_UpdateBilling
    @Id                 INT,
    @PlanName           NVARCHAR(50),
    @MaxUsers           INT,
    @TrialEndsAt        DATETIME      = NULL,
    @SubscriptionEndsAt DATETIME      = NULL,
    @UpdatedBy          INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        PlanName           = @PlanName,
        MaxUsers           = @MaxUsers,
        TrialEndsAt        = ISNULL(@TrialEndsAt, TrialEndsAt),
        SubscriptionEndsAt = @SubscriptionEndsAt,
        UpdatedAt          = GETUTCDATE(),
        UpdatedBy          = @UpdatedBy
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Company_SoftDelete
    @Id        INT,
    @UpdatedBy INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        IsDeleted = 1,
        Status    = 1,             -- Suspended
        UpdatedAt = GETUTCDATE(),
        UpdatedBy = @UpdatedBy
    WHERE Id = @Id;
END
GO

-- ============================================================
-- PLATFORM-WIDE STATS
-- Returns 3 result sets: counters, plan breakdown, recent signups
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Admin_GetStats
AS BEGIN
    SET NOCOUNT ON;

    -- 1) Counters + MRR
    SELECT
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0)                      AS TotalCompanies,
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0 AND Status = 0)       AS ActiveCount,
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0 AND Status = 1)       AS SuspendedCount,
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0 AND Status = 2)       AS TrialCount,
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0 AND Status = 3)       AS ExpiredCount,
        (SELECT COUNT(*) FROM Companies WHERE IsDeleted = 0
            AND CreatedAt >= DATEADD(DAY, -30, GETUTCDATE()))                     AS Signups30d,
        ISNULL((SELECT SUM(p.MonthlyPrice)
                FROM Companies c
                INNER JOIN SubscriptionPlans p ON c.PlanName = p.Name
                WHERE c.IsDeleted = 0 AND c.Status = 0), 0)                       AS MRR;

    -- 2) Breakdown by plan
    SELECT
        c.PlanName,
        COUNT(*) AS CompanyCount
    FROM Companies c
    WHERE c.IsDeleted = 0
    GROUP BY c.PlanName
    ORDER BY COUNT(*) DESC;

    -- 3) Recent signups (last 10)
    SELECT TOP 10
        Id, Name, Slug, Email, Status, PlanName, CreatedAt
    FROM Companies
    WHERE IsDeleted = 0
    ORDER BY CreatedAt DESC;
END
GO

-- ============================================================
-- API KEY PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ApiKey_GetByCompany
    @CompanyId INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT Id, CompanyId, Name, ApiKey AS [Key], IsActive, CreatedAt, CreatedBy, LastUsedAt, ExpiresAt
    FROM ApiKeys WHERE CompanyId = @CompanyId
    ORDER BY IsActive DESC, CreatedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_ApiKey_GetByKey
    @ApiKey NVARCHAR(80)
AS BEGIN
    SET NOCOUNT ON;
    SELECT k.Id, k.CompanyId, k.Name, k.ApiKey AS [Key], k.IsActive, k.CreatedAt, k.CreatedBy,
           k.LastUsedAt, k.ExpiresAt,
           c.DatabaseName, c.Status AS CompanyStatus, c.LeadPrefix
    FROM ApiKeys k
    INNER JOIN Companies c ON c.Id = k.CompanyId
    WHERE k.ApiKey = @ApiKey AND k.IsActive = 1 AND c.IsDeleted = 0;
END
GO

CREATE OR ALTER PROCEDURE sp_ApiKey_Insert
    @CompanyId INT,
    @Name      NVARCHAR(100),
    @ApiKey    NVARCHAR(80),
    @CreatedBy INT = NULL,
    @ExpiresAt DATETIME = NULL,
    @NewId     INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO ApiKeys (CompanyId, Name, ApiKey, IsActive, CreatedAt, CreatedBy, ExpiresAt)
    VALUES (@CompanyId, @Name, @ApiKey, 1, GETUTCDATE(), @CreatedBy, @ExpiresAt);
    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_ApiKey_Revoke
    @Id        INT,
    @CompanyId INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE ApiKeys SET IsActive = 0 WHERE Id = @Id AND CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE sp_ApiKey_MarkUsed
    @Id INT
AS BEGIN
    SET NOCOUNT ON;
    UPDATE ApiKeys SET LastUsedAt = GETUTCDATE() WHERE Id = @Id;
END
GO

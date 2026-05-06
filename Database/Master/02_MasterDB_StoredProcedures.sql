-- ============================================================
-- TRAVEL ERP — MASTER DATABASE STORED PROCEDURES
-- Only procedures that have active repos/controllers
-- ============================================================

USE TravelERP_Master;
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

CREATE OR ALTER PROCEDURE sp_Company_UpdateNumberSeries
    @Id            INT,
    @LeadPrefix    NVARCHAR(20),
    @PackagePrefix NVARCHAR(20),
    @UpdatedBy     INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Companies SET
        LeadPrefix    = @LeadPrefix,
        PackagePrefix = @PackagePrefix,
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
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());
    INSERT INTO MasterUsers (CompanyId, FullName, Email, PasswordHash, Role, IsActive,
        ProfileImageUrl, CreatedAt, CreatedBy, IsDeleted)
    VALUES (@CompanyId, @FullName, @Email, @PasswordHash, @Role, @IsActive,
        @ProfileImageUrl, @CreatedAt, @CreatedBy, 0);
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
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());
    UPDATE MasterUsers SET
        FullName=@FullName, Email=@Email, Role=@Role, IsActive=@IsActive,
        ProfileImageUrl=@ProfileImageUrl, UpdatedAt=@UpdatedAt, UpdatedBy=@UpdatedBy
    WHERE Id = @Id;
END
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
    @CreatedBy    INT           = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Roles
            (RoleName, Description, IsSystem, IsActive, CreatedAt, CreatedBy)
        VALUES (@RoleName, @Description, @IsSystem, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@RoleName NVARCHAR(100), @Description NVARCHAR(300), @IsSystem BIT, @CreatedBy INT, @NewId INT OUTPUT',
        @RoleName, @Description, @IsSystem, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Role_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @RoleName     NVARCHAR(100),
    @Description  NVARCHAR(300) = NULL,
    @UpdatedBy    INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Roles
        SET RoleName = @RoleName, Description = @Description,
            UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id AND IsSystem = 0';
    EXEC sp_executesql @sql,
        N'@Id INT, @RoleName NVARCHAR(100), @Description NVARCHAR(300), @UpdatedBy INT',
        @Id, @RoleName, @Description, @UpdatedBy;
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
-- DESIGNATION PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Designation_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Designations WHERE IsActive = 1 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Designation_Insert
    @DatabaseName NVARCHAR(100),
    @Name         NVARCHAR(100),
    @CreatedBy    INT = 0,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Designations (Name, IsActive, CreatedAt, CreatedBy)
        VALUES (@Name, 1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@Name NVARCHAR(100), @CreatedBy INT, @NewId INT OUTPUT',
        @Name, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Designation_Update
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Name         NVARCHAR(100),
    @UpdatedBy    INT = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Designations
        SET Name = @Name, UpdatedAt = GETUTCDATE(), UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @Name NVARCHAR(100), @UpdatedBy INT',
        @Id, @Name, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Designation_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Designations SET IsActive = 0 WHERE Id = @Id';
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
-- EMPLOYEE PROCEDURES
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Employee_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT e.*, d.Name AS DesignationName
        FROM [' + @DatabaseName + N'].dbo.Employees e
        LEFT JOIN [' + @DatabaseName + N'].dbo.Designations d ON e.DesignationId = d.Id
        WHERE e.IsActive = 1
        ORDER BY e.FirstName, e.LastName';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT e.*, d.Name AS DesignationName
        FROM [' + @DatabaseName + N'].dbo.Employees e
        LEFT JOIN [' + @DatabaseName + N'].dbo.Designations d ON e.DesignationId = d.Id
        WHERE e.Id = @Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Insert
    @DatabaseName  NVARCHAR(100),
    @UserId        INT           = NULL,
    @DesignationId INT           = NULL,
    @FirstName     NVARCHAR(100),
    @LastName      NVARCHAR(100) = NULL,
    @Email         NVARCHAR(150),
    @Mobile        NVARCHAR(30)  = NULL,
    @DateOfBirth   DATE          = NULL,
    @ImageUrl      NVARCHAR(500) = NULL,
    @ReplyEmail    NVARCHAR(150) = NULL,
    @CreatedBy     INT           = 0,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Employees
            (UserId, DesignationId, FirstName, LastName, Email, Mobile, DateOfBirth, ImageUrl, ReplyEmail,
             IsActive, CreatedAt, CreatedBy)
        VALUES (@UserId, @DesignationId, @FirstName, @LastName, @Email, @Mobile, @DateOfBirth, @ImageUrl, @ReplyEmail,
            1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@UserId INT, @DesignationId INT, @FirstName NVARCHAR(100), @LastName NVARCHAR(100), @Email NVARCHAR(150), @Mobile NVARCHAR(30), @DateOfBirth DATE, @ImageUrl NVARCHAR(500), @ReplyEmail NVARCHAR(150), @CreatedBy INT, @NewId INT OUTPUT',
        @UserId, @DesignationId, @FirstName, @LastName, @Email, @Mobile, @DateOfBirth, @ImageUrl, @ReplyEmail, @CreatedBy, @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Update
    @DatabaseName  NVARCHAR(100),
    @Id            INT,
    @DesignationId INT           = NULL,
    @FirstName     NVARCHAR(100),
    @LastName      NVARCHAR(100) = NULL,
    @Email         NVARCHAR(150),
    @Mobile        NVARCHAR(30)  = NULL,
    @DateOfBirth   DATE          = NULL,
    @ImageUrl      NVARCHAR(500) = NULL,
    @ReplyEmail    NVARCHAR(150) = NULL,
    @UpdatedBy     INT           = 0
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Employees
        SET DesignationId = @DesignationId,
            FirstName = @FirstName,
            LastName = @LastName,
            Email = @Email,
            Mobile = @Mobile,
            DateOfBirth = @DateOfBirth,
            ImageUrl = ISNULL(@ImageUrl, ImageUrl),
            ReplyEmail = @ReplyEmail,
            UpdatedAt = GETUTCDATE(),
            UpdatedBy = @UpdatedBy
        WHERE Id = @Id';
    EXEC sp_executesql @sql,
        N'@Id INT, @DesignationId INT, @FirstName NVARCHAR(100), @LastName NVARCHAR(100), @Email NVARCHAR(150), @Mobile NVARCHAR(30), @DateOfBirth DATE, @ImageUrl NVARCHAR(500), @ReplyEmail NVARCHAR(150), @UpdatedBy INT',
        @Id, @DesignationId, @FirstName, @LastName, @Email, @Mobile, @DateOfBirth, @ImageUrl, @ReplyEmail, @UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Employees SET IsActive = 0 WHERE Id = @Id';
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

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Packages
            (PackageNumber, LeadId, Title, DestinationId, CustomerName, CustomerMobile, CustomerEmail,
             Adults, Children, Infants, Days, Nights, StartDate, PriceMode, Currency,
             FlightDetails, Inclusions, Exclusions, Notes,
             IsActive, CreatedAt, CreatedBy)
        VALUES (@PackageNumber, @LeadId, @Title, @DestinationId, @CustomerName, @CustomerMobile, @CustomerEmail,
            @Adults, @Children, @Infants, @Days, @Nights, @StartDate, @PriceMode, @Currency,
            @FlightDetails, @Inclusions, @Exclusions, @Notes,
            1, GETUTCDATE(), @CreatedBy);
        SELECT @NewId = SCOPE_IDENTITY();';
    EXEC sp_executesql @sql,
        N'@PackageNumber NVARCHAR(40), @LeadId INT, @Title NVARCHAR(200), @DestinationId INT, @CustomerName NVARCHAR(150), @CustomerMobile NVARCHAR(30), @CustomerEmail NVARCHAR(150), @Adults INT, @Children INT, @Infants INT, @Days INT, @Nights INT, @StartDate DATE, @PriceMode NVARCHAR(20), @Currency NVARCHAR(10), @FlightDetails NVARCHAR(MAX), @Inclusions NVARCHAR(MAX), @Exclusions NVARCHAR(MAX), @Notes NVARCHAR(MAX), @CreatedBy INT, @NewId INT OUTPUT',
        @PackageNumber, @LeadId, @Title, @DestinationId, @CustomerName, @CustomerMobile, @CustomerEmail,
        @Adults, @Children, @Infants, @Days, @Nights, @StartDate, @PriceMode, @Currency,
        @FlightDetails, @Inclusions, @Exclusions, @Notes, @CreatedBy, @NewId OUTPUT;
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
    @OtherText        NVARCHAR(300) = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PackageOptionHotels
            (PackageOptionId, DisplayOrder, Nights, HotelId, RoomTypeId, MealPlanId, OtherText)
        VALUES (@PackageOptionId, @DisplayOrder, @Nights, @HotelId, @RoomTypeId, @MealPlanId, @OtherText)';
    EXEC sp_executesql @sql,
        N'@PackageOptionId INT, @DisplayOrder INT, @Nights INT, @HotelId INT, @RoomTypeId INT, @MealPlanId INT, @OtherText NVARCHAR(300)',
        @PackageOptionId, @DisplayOrder, @Nights, @HotelId, @RoomTypeId, @MealPlanId, @OtherText;
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

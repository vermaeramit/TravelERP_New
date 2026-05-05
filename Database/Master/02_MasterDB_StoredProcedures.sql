-- ============================================================
-- TRAVEL ERP -- MASTER DATABASE STORED PROCEDURES
-- ALL stored procedures live here (master + all tenant ops)
-- Tenant procedures use @DatabaseName for cross-DB dynamic SQL
-- ============================================================

USE TravelERP_Master;
GO

-- ============================================================
-- CLIENT DATABASE NAME GENERATOR
-- Returns next name: TravelERP_Client1, TravelERP_Client2 ...
-- Inserts a reservation row atomically to prevent duplicates
-- ============================================================
CREATE OR ALTER PROCEDURE sp_Company_GenerateDbName
    @DatabaseName NVARCHAR(100) OUTPUT
AS BEGIN
    SET NOCOUNT ON;

    -- Remove any orphaned rows from previously failed registrations
    DELETE FROM ClientSequence WHERE CompanyId IS NULL;

    DECLARE @nextId INT;

    INSERT INTO ClientSequence (DatabaseName)
    VALUES ('__PENDING__');

    SET @nextId = SCOPE_IDENTITY();

    SET @DatabaseName = 'TravelERP_Client' + CAST(@nextId AS NVARCHAR(10));

    UPDATE ClientSequence
    SET DatabaseName = @DatabaseName
    WHERE Id = @nextId;
END
GO

-- ============================================================
-- COMPANY STORED PROCEDURES
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
    @Status          TINYINT = 2,
    @TrialEndsAt     DATETIME,
    @SubscriptionEndsAt DATETIME = NULL,
    @PlanName        NVARCHAR(50) = 'Trial',
    @MaxUsers        INT = 5,
    @TimeZone        NVARCHAR(100) = 'UTC',
    @Currency        NVARCHAR(10) = 'INR',
    @CurrencySymbol  NVARCHAR(5) = N'₹',
    @CreatedAt       DATETIME = NULL,
    @CreatedBy       INT = NULL,
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

    -- Link sequence entry to the company
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
    @SubscriptionEndsAt DATETIME = NULL,
    @PlanName        NVARCHAR(50),
    @MaxUsers        INT,
    @TimeZone        NVARCHAR(100),
    @Currency        NVARCHAR(10),
    @CurrencySymbol  NVARCHAR(5),
    @UpdatedAt       DATETIME = NULL,
    @UpdatedBy       INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    UPDATE Companies SET
        Name = @Name, Email = @Email, Phone = @Phone, Address = @Address,
        City = @City, Country = @Country, LogoUrl = @LogoUrl,
        LicenseNumber = @LicenseNumber, TaxNumber = @TaxNumber, Status = @Status,
        SubscriptionEndsAt = @SubscriptionEndsAt, PlanName = @PlanName, MaxUsers = @MaxUsers,
        TimeZone = @TimeZone, Currency = @Currency, CurrencySymbol = @CurrencySymbol,
        UpdatedAt = @UpdatedAt, UpdatedBy = @UpdatedBy
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
-- USER STORED PROCEDURES
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
    @Role            TINYINT = 2,
    @IsActive        BIT = 1,
    @ProfileImageUrl NVARCHAR(500) = NULL,
    @CreatedAt       DATETIME = NULL,
    @CreatedBy       INT = NULL,
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
    @UpdatedAt       DATETIME = NULL,
    @UpdatedBy       INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    UPDATE MasterUsers SET
        FullName = @FullName, Email = @Email, Role = @Role, IsActive = @IsActive,
        ProfileImageUrl = @ProfileImageUrl, UpdatedAt = @UpdatedAt, UpdatedBy = @UpdatedBy
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

-- ============================================================
-- ============================================================
-- TENANT STORED PROCEDURES (Dynamic Cross-DB)
-- All use @DatabaseName to query the correct client database
-- Data lives in [TravelERP_ClientN].dbo.TableName
-- ============================================================
-- ============================================================

-- ============================================================
-- CUSTOMER PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Customer_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Customers
        WHERE Id = @Id AND IsDeleted = 0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_GetAll
    @DatabaseName NVARCHAR(100),
    @BranchId     INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Customers
        WHERE IsDeleted = 0
        ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_Search
    @DatabaseName NVARCHAR(100),
    @Keyword      NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @kw  NVARCHAR(102) = '%' + @Keyword + '%';
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Customers
        WHERE IsDeleted = 0 AND (
            Name LIKE @kw OR Email LIKE @kw OR Mobile LIKE @kw
            OR PassportNumber LIKE @kw OR CustomerCode LIKE @kw OR Destination LIKE @kw)
        ORDER BY Name';
    EXEC sp_executesql @sql, N'@kw NVARCHAR(102)', @kw;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_Insert
    @DatabaseName    NVARCHAR(100),
    @CustomerCode    NVARCHAR(20),
    @Name            NVARCHAR(150),
    @Mobile          NVARCHAR(30),
    @Email           NVARCHAR(150) = NULL,
    @Destination     NVARCHAR(200) = NULL,
    @TravelingDate   DATE          = NULL,
    @LeavingFrom     NVARCHAR(100) = NULL,
    @TravelCity      NVARCHAR(100) = NULL,
    @HotelRecommended NVARCHAR(200)= NULL,
    @NoOfAdults      TINYINT       = NULL,
    @NoOfChildren    TINYINT       = NULL,
    @NoOfDays        TINYINT       = NULL,
    @AssignedTo      NVARCHAR(150) = NULL,
    @LeadSource      NVARCHAR(100) = NULL,
    @Infant          NVARCHAR(50)  = NULL,
    @Remark          NVARCHAR(MAX) = NULL,
    @PassportNumber  NVARCHAR(50)  = NULL,
    @PassportExpiry  DATE          = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Customers
            (CustomerCode,Name,Mobile,Email,Destination,TravelingDate,LeavingFrom,TravelCity,
             HotelRecommended,NoOfAdults,NoOfChildren,NoOfDays,AssignedTo,LeadSource,
             Infant,Remark,PassportNumber,PassportExpiry,Notes,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@CustomerCode,@Name,@Mobile,@Email,@Destination,@TravelingDate,@LeavingFrom,@TravelCity,
             @HotelRecommended,@NoOfAdults,@NoOfChildren,@NoOfDays,@AssignedTo,@LeadSource,
             @Infant,@Remark,@PassportNumber,@PassportExpiry,@Notes,@CreatedAt,@CreatedBy,0)';

    DECLARE @params NVARCHAR(MAX) = N'
        @CustomerCode NVARCHAR(20),@Name NVARCHAR(150),@Mobile NVARCHAR(30),
        @Email NVARCHAR(150),@Destination NVARCHAR(200),@TravelingDate DATE,
        @LeavingFrom NVARCHAR(100),@TravelCity NVARCHAR(100),@HotelRecommended NVARCHAR(200),
        @NoOfAdults TINYINT,@NoOfChildren TINYINT,@NoOfDays TINYINT,
        @AssignedTo NVARCHAR(150),@LeadSource NVARCHAR(100),@Infant NVARCHAR(50),
        @Remark NVARCHAR(MAX),@PassportNumber NVARCHAR(50),@PassportExpiry DATE,
        @Notes NVARCHAR(MAX),@CreatedAt DATETIME,@CreatedBy INT';

    EXEC sp_executesql @sql, @params,
        @CustomerCode,@Name,@Mobile,@Email,@Destination,@TravelingDate,@LeavingFrom,@TravelCity,
        @HotelRecommended,@NoOfAdults,@NoOfChildren,@NoOfDays,@AssignedTo,@LeadSource,
        @Infant,@Remark,@PassportNumber,@PassportExpiry,@Notes,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Customers';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @Name            NVARCHAR(150),
    @Mobile          NVARCHAR(30),
    @Email           NVARCHAR(150) = NULL,
    @Destination     NVARCHAR(200) = NULL,
    @TravelingDate   DATE          = NULL,
    @LeavingFrom     NVARCHAR(100) = NULL,
    @TravelCity      NVARCHAR(100) = NULL,
    @HotelRecommended NVARCHAR(200)= NULL,
    @NoOfAdults      TINYINT       = NULL,
    @NoOfChildren    TINYINT       = NULL,
    @NoOfDays        TINYINT       = NULL,
    @AssignedTo      NVARCHAR(150) = NULL,
    @LeadSource      NVARCHAR(100) = NULL,
    @Infant          NVARCHAR(50)  = NULL,
    @Remark          NVARCHAR(MAX) = NULL,
    @PassportNumber  NVARCHAR(50)  = NULL,
    @PassportExpiry  DATE          = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Customers SET
            Name=@Name,Mobile=@Mobile,Email=@Email,Destination=@Destination,
            TravelingDate=@TravelingDate,LeavingFrom=@LeavingFrom,TravelCity=@TravelCity,
            HotelRecommended=@HotelRecommended,NoOfAdults=@NoOfAdults,NoOfChildren=@NoOfChildren,
            NoOfDays=@NoOfDays,AssignedTo=@AssignedTo,LeadSource=@LeadSource,
            Infant=@Infant,Remark=@Remark,PassportNumber=@PassportNumber,PassportExpiry=@PassportExpiry,
            Notes=@Notes,UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@Name NVARCHAR(150),@Mobile NVARCHAR(30),@Email NVARCHAR(150),
          @Destination NVARCHAR(200),@TravelingDate DATE,@LeavingFrom NVARCHAR(100),
          @TravelCity NVARCHAR(100),@HotelRecommended NVARCHAR(200),
          @NoOfAdults TINYINT,@NoOfChildren TINYINT,@NoOfDays TINYINT,
          @AssignedTo NVARCHAR(150),@LeadSource NVARCHAR(100),@Infant NVARCHAR(50),
          @Remark NVARCHAR(MAX),@PassportNumber NVARCHAR(50),@PassportExpiry DATE,
          @Notes NVARCHAR(MAX),@UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@Name,@Mobile,@Email,@Destination,@TravelingDate,@LeavingFrom,@TravelCity,
        @HotelRecommended,@NoOfAdults,@NoOfChildren,@NoOfDays,@AssignedTo,@LeadSource,
        @Infant,@Remark,@PassportNumber,@PassportExpiry,@Notes,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Customers
        SET IsDeleted=1, UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_GenerateCode
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Customers';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'CUS' + RIGHT('00000' + CAST(@count + 1 AS VARCHAR), 5);
END
GO

CREATE OR ALTER PROCEDURE sp_Customer_GetTotalCount
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Customers WHERE IsDeleted=0';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- BOOKING PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Booking_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, c.Name, c.Email AS CustomerEmail, c.Mobile AS CustomerPhone,
               p.Name AS PackageName, p.PackageCode
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId = c.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.TourPackages p ON b.PackageId = p.Id
        WHERE b.Id = @Id AND b.IsDeleted = 0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetByReference
    @DatabaseName     NVARCHAR(100),
    @BookingReference NVARCHAR(20)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, c.Name AS CustomerName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId = c.Id
        WHERE b.BookingReference = @BookingReference AND b.IsDeleted = 0';
    EXEC sp_executesql @sql, N'@BookingReference NVARCHAR(20)', @BookingReference;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetAll
    @DatabaseName NVARCHAR(100),
    @BranchId     INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, c.Name AS CustomerName, p.Name AS PackageName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId = c.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.TourPackages p ON b.PackageId = p.Id
        WHERE b.IsDeleted = 0
          AND (@BranchId IS NULL OR b.BranchId = @BranchId)
        ORDER BY b.CreatedAt DESC';
    EXEC sp_executesql @sql, N'@BranchId INT', @BranchId;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetByCustomer
    @DatabaseName NVARCHAR(100),
    @CustomerId   INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, p.Name AS PackageName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.TourPackages p ON b.PackageId = p.Id
        WHERE b.CustomerId = @CustomerId AND b.IsDeleted = 0
        ORDER BY b.CreatedAt DESC';
    EXEC sp_executesql @sql, N'@CustomerId INT', @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetByStatus
    @DatabaseName NVARCHAR(100),
    @Status       TINYINT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, c.Name AS CustomerName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId = c.Id
        WHERE b.Status = @Status AND b.IsDeleted = 0
        ORDER BY b.TravelDate';
    EXEC sp_executesql @sql, N'@Status TINYINT', @Status;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetByDateRange
    @DatabaseName NVARCHAR(100),
    @FromDate     DATE,
    @ToDate       DATE
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT b.*, c.Name AS CustomerName
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId = c.Id
        WHERE b.TravelDate BETWEEN @FromDate AND @ToDate AND b.IsDeleted = 0
        ORDER BY b.TravelDate';
    EXEC sp_executesql @sql, N'@FromDate DATE, @ToDate DATE', @FromDate, @ToDate;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_Insert
    @DatabaseName     NVARCHAR(100),
    @BookingReference NVARCHAR(20),
    @CustomerId       INT,
    @PackageId        INT           = NULL,
    @BookingType      TINYINT,
    @Status           TINYINT       = 0,
    @PaymentStatus    TINYINT       = 0,
    @TravelDate       DATE,
    @ReturnDate       DATE          = NULL,
    @Adults           INT           = 1,
    @Children         INT           = 0,
    @Infants          INT           = 0,
    @Destination      NVARCHAR(200),
    @TotalAmount      DECIMAL(12,2) = 0,
    @PaidAmount       DECIMAL(12,2) = 0,
    @DiscountAmount   DECIMAL(12,2) = 0,
    @SpecialRequests  NVARCHAR(MAX) = NULL,
    @InternalNotes    NVARCHAR(MAX) = NULL,
    @BranchId         INT           = NULL,
    @AgentId          INT           = NULL,
    @CreatedAt        DATETIME      = NULL,
    @CreatedBy        INT           = NULL,
    @NewId            INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Bookings
            (BookingReference,CustomerId,PackageId,BookingType,Status,PaymentStatus,
             TravelDate,ReturnDate,Adults,Children,Infants,Destination,TotalAmount,
             PaidAmount,DiscountAmount,SpecialRequests,InternalNotes,BranchId,AgentId,
             CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@BookingReference,@CustomerId,@PackageId,@BookingType,@Status,@PaymentStatus,
             @TravelDate,@ReturnDate,@Adults,@Children,@Infants,@Destination,@TotalAmount,
             @PaidAmount,@DiscountAmount,@SpecialRequests,@InternalNotes,@BranchId,@AgentId,
             @CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@BookingReference NVARCHAR(20),@CustomerId INT,@PackageId INT,@BookingType TINYINT,
          @Status TINYINT,@PaymentStatus TINYINT,@TravelDate DATE,@ReturnDate DATE,
          @Adults INT,@Children INT,@Infants INT,@Destination NVARCHAR(200),
          @TotalAmount DECIMAL(12,2),@PaidAmount DECIMAL(12,2),@DiscountAmount DECIMAL(12,2),
          @SpecialRequests NVARCHAR(MAX),@InternalNotes NVARCHAR(MAX),
          @BranchId INT,@AgentId INT,@CreatedAt DATETIME,@CreatedBy INT',
        @BookingReference,@CustomerId,@PackageId,@BookingType,@Status,@PaymentStatus,
        @TravelDate,@ReturnDate,@Adults,@Children,@Infants,@Destination,
        @TotalAmount,@PaidAmount,@DiscountAmount,@SpecialRequests,@InternalNotes,
        @BranchId,@AgentId,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Bookings';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @PackageId       INT           = NULL,
    @BookingType     TINYINT,
    @Status          TINYINT,
    @PaymentStatus   TINYINT,
    @TravelDate      DATE,
    @ReturnDate      DATE          = NULL,
    @Adults          INT,
    @Children        INT,
    @Infants         INT,
    @Destination     NVARCHAR(200),
    @TotalAmount     DECIMAL(12,2),
    @PaidAmount      DECIMAL(12,2),
    @DiscountAmount  DECIMAL(12,2),
    @SpecialRequests NVARCHAR(MAX) = NULL,
    @InternalNotes   NVARCHAR(MAX) = NULL,
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Bookings SET
            PackageId=@PackageId,BookingType=@BookingType,Status=@Status,
            PaymentStatus=@PaymentStatus,TravelDate=@TravelDate,ReturnDate=@ReturnDate,
            Adults=@Adults,Children=@Children,Infants=@Infants,Destination=@Destination,
            TotalAmount=@TotalAmount,PaidAmount=@PaidAmount,DiscountAmount=@DiscountAmount,
            SpecialRequests=@SpecialRequests,InternalNotes=@InternalNotes,
            UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@PackageId INT,@BookingType TINYINT,@Status TINYINT,@PaymentStatus TINYINT,
          @TravelDate DATE,@ReturnDate DATE,@Adults INT,@Children INT,@Infants INT,
          @Destination NVARCHAR(200),@TotalAmount DECIMAL(12,2),@PaidAmount DECIMAL(12,2),
          @DiscountAmount DECIMAL(12,2),@SpecialRequests NVARCHAR(MAX),
          @InternalNotes NVARCHAR(MAX),@UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@PackageId,@BookingType,@Status,@PaymentStatus,@TravelDate,@ReturnDate,
        @Adults,@Children,@Infants,@Destination,@TotalAmount,@PaidAmount,
        @DiscountAmount,@SpecialRequests,@InternalNotes,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_UpdateStatus
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Status       TINYINT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Bookings
        SET Status=@Status, UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT, @Status TINYINT', @Id, @Status;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GenerateReference
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'BK' + FORMAT(GETDATE(), 'yyMM') + RIGHT('0000' + CAST(@count + 1 AS VARCHAR), 4);
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetTotalRevenue
    @DatabaseName NVARCHAR(100),
    @FromDate     DATETIME = NULL,
    @ToDate       DATETIME = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT ISNULL(SUM(TotalAmount), 0)
        FROM [' + @DatabaseName + N'].dbo.Bookings
        WHERE IsDeleted = 0 AND Status != 3
          AND (@FromDate IS NULL OR CreatedAt >= @FromDate)
          AND (@ToDate   IS NULL OR CreatedAt <= @ToDate)';
    EXEC sp_executesql @sql, N'@FromDate DATETIME, @ToDate DATETIME', @FromDate, @ToDate;
END
GO

CREATE OR ALTER PROCEDURE sp_Booking_GetTotalCount
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings WHERE IsDeleted=0';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- PACKAGE PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Package_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.TourPackages WHERE Id=@Id AND IsDeleted=0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.TourPackages WHERE IsDeleted=0 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetByType
    @DatabaseName NVARCHAR(100),
    @Type         TINYINT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.TourPackages WHERE Type=@Type AND IsDeleted=0 ORDER BY Name';
    EXEC sp_executesql @sql, N'@Type TINYINT', @Type;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GetFeatured
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.TourPackages WHERE IsFeatured=1 AND IsDeleted=0 AND Status=0 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Search
    @DatabaseName NVARCHAR(100),
    @Keyword      NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @kw NVARCHAR(102) = '%' + @Keyword + '%';
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.TourPackages
        WHERE IsDeleted=0 AND (Name LIKE @kw OR Destination LIKE @kw OR PackageCode LIKE @kw)
        ORDER BY Name';
    EXEC sp_executesql @sql, N'@kw NVARCHAR(102)', @kw;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Insert
    @DatabaseName   NVARCHAR(100),
    @PackageCode    NVARCHAR(20),
    @Name           NVARCHAR(200),
    @Description    NVARCHAR(MAX) = NULL,
    @Type           TINYINT,
    @Status         TINYINT       = 0,
    @Destination    NVARCHAR(200),
    @Origin         NVARCHAR(200) = NULL,
    @DurationDays   INT           = 1,
    @DurationNights INT           = 0,
    @BasePrice      DECIMAL(12,2) = 0,
    @ChildPrice     DECIMAL(12,2) = NULL,
    @InfantPrice    DECIMAL(12,2) = NULL,
    @Inclusions     NVARCHAR(MAX) = NULL,
    @Exclusions     NVARCHAR(MAX) = NULL,
    @Itinerary      NVARCHAR(MAX) = NULL,
    @ImageUrl       NVARCHAR(500) = NULL,
    @MaxCapacity    INT           = 20,
    @ValidFrom      DATE          = NULL,
    @ValidTo        DATE          = NULL,
    @IsFeatured     BIT           = 0,
    @CreatedAt      DATETIME      = NULL,
    @CreatedBy      INT           = NULL,
    @NewId          INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.TourPackages
            (PackageCode,Name,Description,Type,Status,Destination,Origin,DurationDays,DurationNights,
             BasePrice,ChildPrice,InfantPrice,Inclusions,Exclusions,Itinerary,ImageUrl,
             MaxCapacity,ValidFrom,ValidTo,IsFeatured,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@PackageCode,@Name,@Description,@Type,@Status,@Destination,@Origin,@DurationDays,@DurationNights,
             @BasePrice,@ChildPrice,@InfantPrice,@Inclusions,@Exclusions,@Itinerary,@ImageUrl,
             @MaxCapacity,@ValidFrom,@ValidTo,@IsFeatured,@CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@PackageCode NVARCHAR(20),@Name NVARCHAR(200),@Description NVARCHAR(MAX),
          @Type TINYINT,@Status TINYINT,@Destination NVARCHAR(200),@Origin NVARCHAR(200),
          @DurationDays INT,@DurationNights INT,@BasePrice DECIMAL(12,2),
          @ChildPrice DECIMAL(12,2),@InfantPrice DECIMAL(12,2),@Inclusions NVARCHAR(MAX),
          @Exclusions NVARCHAR(MAX),@Itinerary NVARCHAR(MAX),@ImageUrl NVARCHAR(500),
          @MaxCapacity INT,@ValidFrom DATE,@ValidTo DATE,@IsFeatured BIT,
          @CreatedAt DATETIME,@CreatedBy INT',
        @PackageCode,@Name,@Description,@Type,@Status,@Destination,@Origin,
        @DurationDays,@DurationNights,@BasePrice,@ChildPrice,@InfantPrice,
        @Inclusions,@Exclusions,@Itinerary,@ImageUrl,
        @MaxCapacity,@ValidFrom,@ValidTo,@IsFeatured,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.TourPackages';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Update
    @DatabaseName   NVARCHAR(100),
    @Id             INT,
    @Name           NVARCHAR(200),
    @Description    NVARCHAR(MAX) = NULL,
    @Type           TINYINT,
    @Status         TINYINT,
    @Destination    NVARCHAR(200),
    @Origin         NVARCHAR(200) = NULL,
    @DurationDays   INT,
    @DurationNights INT,
    @BasePrice      DECIMAL(12,2),
    @ChildPrice     DECIMAL(12,2) = NULL,
    @InfantPrice    DECIMAL(12,2) = NULL,
    @Inclusions     NVARCHAR(MAX) = NULL,
    @Exclusions     NVARCHAR(MAX) = NULL,
    @Itinerary      NVARCHAR(MAX) = NULL,
    @ImageUrl       NVARCHAR(500) = NULL,
    @MaxCapacity    INT,
    @ValidFrom      DATE          = NULL,
    @ValidTo        DATE          = NULL,
    @IsFeatured     BIT           = 0,
    @UpdatedAt      DATETIME      = NULL,
    @UpdatedBy      INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.TourPackages SET
            Name=@Name,Description=@Description,Type=@Type,Status=@Status,
            Destination=@Destination,Origin=@Origin,DurationDays=@DurationDays,
            DurationNights=@DurationNights,BasePrice=@BasePrice,ChildPrice=@ChildPrice,
            InfantPrice=@InfantPrice,Inclusions=@Inclusions,Exclusions=@Exclusions,
            Itinerary=@Itinerary,ImageUrl=@ImageUrl,MaxCapacity=@MaxCapacity,
            ValidFrom=@ValidFrom,ValidTo=@ValidTo,IsFeatured=@IsFeatured,
            UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@Name NVARCHAR(200),@Description NVARCHAR(MAX),@Type TINYINT,@Status TINYINT,
          @Destination NVARCHAR(200),@Origin NVARCHAR(200),@DurationDays INT,@DurationNights INT,
          @BasePrice DECIMAL(12,2),@ChildPrice DECIMAL(12,2),@InfantPrice DECIMAL(12,2),
          @Inclusions NVARCHAR(MAX),@Exclusions NVARCHAR(MAX),@Itinerary NVARCHAR(MAX),
          @ImageUrl NVARCHAR(500),@MaxCapacity INT,@ValidFrom DATE,@ValidTo DATE,
          @IsFeatured BIT,@UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@Name,@Description,@Type,@Status,@Destination,@Origin,@DurationDays,@DurationNights,
        @BasePrice,@ChildPrice,@InfantPrice,@Inclusions,@Exclusions,@Itinerary,@ImageUrl,
        @MaxCapacity,@ValidFrom,@ValidTo,@IsFeatured,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'UPDATE [' + @DatabaseName + N'].dbo.TourPackages SET IsDeleted=1,UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Package_GenerateCode
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.TourPackages';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'PKG' + RIGHT('00000' + CAST(@count + 1 AS VARCHAR), 5);
END
GO

-- ============================================================
-- INVOICE PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Invoice_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT i.*, c.Name AS CustomerName, c.Email AS CustomerEmail,
               b.BookingReference, b.Destination
        FROM [' + @DatabaseName + N'].dbo.Invoices i
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON i.CustomerId = c.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Bookings  b ON i.BookingId  = b.Id
        WHERE i.Id=@Id AND i.IsDeleted=0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT i.*, c.Name AS CustomerName, b.BookingReference
        FROM [' + @DatabaseName + N'].dbo.Invoices i
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON i.CustomerId = c.Id
        LEFT JOIN [' + @DatabaseName + N'].dbo.Bookings  b ON i.BookingId  = b.Id
        WHERE i.IsDeleted=0 ORDER BY i.InvoiceDate DESC';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_GetByBooking
    @DatabaseName NVARCHAR(100),
    @BookingId    INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Invoices WHERE BookingId=@BookingId AND IsDeleted=0';
    EXEC sp_executesql @sql, N'@BookingId INT', @BookingId;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_GetByCustomer
    @DatabaseName NVARCHAR(100),
    @CustomerId   INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Invoices WHERE CustomerId=@CustomerId AND IsDeleted=0 ORDER BY InvoiceDate DESC';
    EXEC sp_executesql @sql, N'@CustomerId INT', @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_Insert
    @DatabaseName       NVARCHAR(100),
    @InvoiceNumber      NVARCHAR(20),
    @BookingId          INT,
    @CustomerId         INT,
    @Status             TINYINT       = 0,
    @InvoiceDate        DATE,
    @DueDate            DATE,
    @SubTotal           DECIMAL(12,2),
    @TaxAmount          DECIMAL(12,2) = 0,
    @DiscountAmount     DECIMAL(12,2) = 0,
    @TotalAmount        DECIMAL(12,2),
    @PaidAmount         DECIMAL(12,2) = 0,
    @Notes              NVARCHAR(MAX) = NULL,
    @TermsAndConditions NVARCHAR(MAX) = NULL,
    @CreatedAt          DATETIME      = NULL,
    @CreatedBy          INT           = NULL,
    @NewId              INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Invoices
            (InvoiceNumber,BookingId,CustomerId,Status,InvoiceDate,DueDate,SubTotal,
             TaxAmount,DiscountAmount,TotalAmount,PaidAmount,Notes,TermsAndConditions,
             CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@InvoiceNumber,@BookingId,@CustomerId,@Status,@InvoiceDate,@DueDate,@SubTotal,
             @TaxAmount,@DiscountAmount,@TotalAmount,@PaidAmount,@Notes,@TermsAndConditions,
             @CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@InvoiceNumber NVARCHAR(20),@BookingId INT,@CustomerId INT,@Status TINYINT,
          @InvoiceDate DATE,@DueDate DATE,@SubTotal DECIMAL(12,2),@TaxAmount DECIMAL(12,2),
          @DiscountAmount DECIMAL(12,2),@TotalAmount DECIMAL(12,2),@PaidAmount DECIMAL(12,2),
          @Notes NVARCHAR(MAX),@TermsAndConditions NVARCHAR(MAX),@CreatedAt DATETIME,@CreatedBy INT',
        @InvoiceNumber,@BookingId,@CustomerId,@Status,@InvoiceDate,@DueDate,@SubTotal,
        @TaxAmount,@DiscountAmount,@TotalAmount,@PaidAmount,@Notes,@TermsAndConditions,
        @CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Invoices';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_Update
    @DatabaseName       NVARCHAR(100),
    @Id                 INT,
    @Status             TINYINT,
    @DueDate            DATE,
    @SubTotal           DECIMAL(12,2),
    @TaxAmount          DECIMAL(12,2),
    @DiscountAmount     DECIMAL(12,2),
    @TotalAmount        DECIMAL(12,2),
    @PaidAmount         DECIMAL(12,2),
    @Notes              NVARCHAR(MAX) = NULL,
    @TermsAndConditions NVARCHAR(MAX) = NULL,
    @UpdatedAt          DATETIME      = NULL,
    @UpdatedBy          INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Invoices SET
            Status=@Status,DueDate=@DueDate,SubTotal=@SubTotal,TaxAmount=@TaxAmount,
            DiscountAmount=@DiscountAmount,TotalAmount=@TotalAmount,PaidAmount=@PaidAmount,
            Notes=@Notes,TermsAndConditions=@TermsAndConditions,
            UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@Status TINYINT,@DueDate DATE,@SubTotal DECIMAL(12,2),@TaxAmount DECIMAL(12,2),
          @DiscountAmount DECIMAL(12,2),@TotalAmount DECIMAL(12,2),@PaidAmount DECIMAL(12,2),
          @Notes NVARCHAR(MAX),@TermsAndConditions NVARCHAR(MAX),@UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@Status,@DueDate,@SubTotal,@TaxAmount,@DiscountAmount,@TotalAmount,@PaidAmount,
        @Notes,@TermsAndConditions,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Invoice_GenerateNumber
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Invoices';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'INV' + FORMAT(GETDATE(), 'yyMM') + RIGHT('0000' + CAST(@count + 1 AS VARCHAR), 4);
END
GO

CREATE OR ALTER PROCEDURE sp_Payment_Insert
    @DatabaseName    NVARCHAR(100),
    @InvoiceId       INT,
    @CustomerId      INT,
    @BookingId       INT,
    @Amount          DECIMAL(12,2),
    @Method          TINYINT,
    @PaymentDate     DATE,
    @ReferenceNumber NVARCHAR(100) = NULL,
    @Notes           NVARCHAR(500) = NULL,
    @ReceivedBy      NVARCHAR(150),
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Payments
            (InvoiceId,CustomerId,BookingId,Amount,Method,PaymentDate,
             ReferenceNumber,Notes,ReceivedBy,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@InvoiceId,@CustomerId,@BookingId,@Amount,@Method,@PaymentDate,
             @ReferenceNumber,@Notes,@ReceivedBy,@CreatedAt,@CreatedBy,0);

        UPDATE [' + @DatabaseName + N'].dbo.Invoices
        SET PaidAmount = PaidAmount + @Amount,
            Status = CASE WHEN PaidAmount + @Amount >= TotalAmount THEN 2 ELSE 1 END,
            UpdatedAt = GETUTCDATE()
        WHERE Id = @InvoiceId;

        UPDATE [' + @DatabaseName + N'].dbo.Bookings
        SET PaidAmount = PaidAmount + @Amount,
            PaymentStatus = CASE WHEN PaidAmount + @Amount >= TotalAmount THEN 2
                                 WHEN PaidAmount + @Amount > 0 THEN 1 ELSE 0 END,
            UpdatedAt = GETUTCDATE()
        WHERE Id = @BookingId;';

    EXEC sp_executesql @sql,
        N'@InvoiceId INT,@CustomerId INT,@BookingId INT,@Amount DECIMAL(12,2),@Method TINYINT,
          @PaymentDate DATE,@ReferenceNumber NVARCHAR(100),@Notes NVARCHAR(500),
          @ReceivedBy NVARCHAR(150),@CreatedAt DATETIME,@CreatedBy INT',
        @InvoiceId,@CustomerId,@BookingId,@Amount,@Method,@PaymentDate,
        @ReferenceNumber,@Notes,@ReceivedBy,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Payments';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Payment_GetByInvoice
    @DatabaseName NVARCHAR(100),
    @InvoiceId    INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Payments WHERE InvoiceId=@InvoiceId AND IsDeleted=0 ORDER BY PaymentDate DESC';
    EXEC sp_executesql @sql, N'@InvoiceId INT', @InvoiceId;
END
GO

-- ============================================================
-- EMPLOYEE PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Employee_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Employees WHERE Id=@Id AND IsDeleted=0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_GetAll
    @DatabaseName NVARCHAR(100),
    @BranchId     INT = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT * FROM [' + @DatabaseName + N'].dbo.Employees
        WHERE IsDeleted=0 AND (@BranchId IS NULL OR BranchId=@BranchId)
        ORDER BY FirstName, LastName';
    EXEC sp_executesql @sql, N'@BranchId INT', @BranchId;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_GetByDepartment
    @DatabaseName NVARCHAR(100),
    @Department   NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Employees WHERE Department=@Department AND IsDeleted=0 ORDER BY FirstName';
    EXEC sp_executesql @sql, N'@Department NVARCHAR(100)', @Department;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Insert
    @DatabaseName    NVARCHAR(100),
    @EmployeeCode    NVARCHAR(20),
    @FirstName       NVARCHAR(100),
    @LastName        NVARCHAR(100),
    @Email           NVARCHAR(150),
    @Phone           NVARCHAR(30),
    @Gender          TINYINT       = NULL,
    @DateOfBirth     DATE          = NULL,
    @Designation     NVARCHAR(150),
    @Department      NVARCHAR(100),
    @BranchId        INT           = NULL,
    @JoiningDate     DATE,
    @Status          TINYINT       = 0,
    @BasicSalary     DECIMAL(12,2) = 0,
    @Address         NVARCHAR(300) = NULL,
    @EmergencyContact NVARCHAR(200) = NULL,
    @ProfileImageUrl NVARCHAR(500) = NULL,
    @MasterUserId    INT           = NULL,
    @CreatedAt       DATETIME      = NULL,
    @CreatedBy       INT           = NULL,
    @NewId           INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Employees
            (EmployeeCode,FirstName,LastName,Email,Phone,Gender,DateOfBirth,Designation,
             Department,BranchId,JoiningDate,Status,BasicSalary,Address,EmergencyContact,
             ProfileImageUrl,MasterUserId,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@EmployeeCode,@FirstName,@LastName,@Email,@Phone,@Gender,@DateOfBirth,@Designation,
             @Department,@BranchId,@JoiningDate,@Status,@BasicSalary,@Address,@EmergencyContact,
             @ProfileImageUrl,@MasterUserId,@CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@EmployeeCode NVARCHAR(20),@FirstName NVARCHAR(100),@LastName NVARCHAR(100),
          @Email NVARCHAR(150),@Phone NVARCHAR(30),@Gender TINYINT,@DateOfBirth DATE,
          @Designation NVARCHAR(150),@Department NVARCHAR(100),@BranchId INT,@JoiningDate DATE,
          @Status TINYINT,@BasicSalary DECIMAL(12,2),@Address NVARCHAR(300),
          @EmergencyContact NVARCHAR(200),@ProfileImageUrl NVARCHAR(500),
          @MasterUserId INT,@CreatedAt DATETIME,@CreatedBy INT',
        @EmployeeCode,@FirstName,@LastName,@Email,@Phone,@Gender,@DateOfBirth,@Designation,
        @Department,@BranchId,@JoiningDate,@Status,@BasicSalary,@Address,@EmergencyContact,
        @ProfileImageUrl,@MasterUserId,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Employees';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @FirstName       NVARCHAR(100),
    @LastName        NVARCHAR(100),
    @Email           NVARCHAR(150),
    @Phone           NVARCHAR(30),
    @Gender          TINYINT       = NULL,
    @DateOfBirth     DATE          = NULL,
    @Designation     NVARCHAR(150),
    @Department      NVARCHAR(100),
    @BranchId        INT           = NULL,
    @Status          TINYINT,
    @BasicSalary     DECIMAL(12,2),
    @Address         NVARCHAR(300) = NULL,
    @EmergencyContact NVARCHAR(200) = NULL,
    @ProfileImageUrl NVARCHAR(500) = NULL,
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Employees SET
            FirstName=@FirstName,LastName=@LastName,Email=@Email,Phone=@Phone,
            Gender=@Gender,DateOfBirth=@DateOfBirth,Designation=@Designation,
            Department=@Department,BranchId=@BranchId,Status=@Status,BasicSalary=@BasicSalary,
            Address=@Address,EmergencyContact=@EmergencyContact,ProfileImageUrl=@ProfileImageUrl,
            UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@FirstName NVARCHAR(100),@LastName NVARCHAR(100),@Email NVARCHAR(150),
          @Phone NVARCHAR(30),@Gender TINYINT,@DateOfBirth DATE,@Designation NVARCHAR(150),
          @Department NVARCHAR(100),@BranchId INT,@Status TINYINT,@BasicSalary DECIMAL(12,2),
          @Address NVARCHAR(300),@EmergencyContact NVARCHAR(200),@ProfileImageUrl NVARCHAR(500),
          @UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@FirstName,@LastName,@Email,@Phone,@Gender,@DateOfBirth,@Designation,
        @Department,@BranchId,@Status,@BasicSalary,@Address,@EmergencyContact,
        @ProfileImageUrl,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'UPDATE [' + @DatabaseName + N'].dbo.Employees SET IsDeleted=1,Status=1,UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_GenerateCode
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Employees';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'EMP' + RIGHT('00000' + CAST(@count + 1 AS VARCHAR), 5);
END
GO

CREATE OR ALTER PROCEDURE sp_Employee_GetTotalCount
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Employees WHERE IsDeleted=0 AND Status=0';
    EXEC sp_executesql @sql;
END
GO

-- ============================================================
-- LEAVE PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Leave_Insert
    @DatabaseName NVARCHAR(100),
    @EmployeeId   INT,
    @LeaveType    TINYINT,
    @FromDate     DATE,
    @ToDate       DATE,
    @TotalDays    INT,
    @Reason       NVARCHAR(500),
    @Status       TINYINT  = 0,
    @CreatedAt    DATETIME = NULL,
    @CreatedBy    INT      = NULL,
    @NewId        INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.LeaveRequests
            (EmployeeId,LeaveType,FromDate,ToDate,TotalDays,Reason,Status,CreatedAt,CreatedBy,IsDeleted)
        VALUES (@EmployeeId,@LeaveType,@FromDate,@ToDate,@TotalDays,@Reason,@Status,@CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@EmployeeId INT,@LeaveType TINYINT,@FromDate DATE,@ToDate DATE,@TotalDays INT,
          @Reason NVARCHAR(500),@Status TINYINT,@CreatedAt DATETIME,@CreatedBy INT',
        @EmployeeId,@LeaveType,@FromDate,@ToDate,@TotalDays,@Reason,@Status,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.LeaveRequests';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Leave_GetByEmployee
    @DatabaseName NVARCHAR(100),
    @EmployeeId   INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.LeaveRequests WHERE EmployeeId=@EmployeeId AND IsDeleted=0 ORDER BY FromDate DESC';
    EXEC sp_executesql @sql, N'@EmployeeId INT', @EmployeeId;
END
GO

CREATE OR ALTER PROCEDURE sp_Leave_GetPending
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT l.*, e.FirstName, e.LastName, e.Department, e.Designation
        FROM [' + @DatabaseName + N'].dbo.LeaveRequests l
        INNER JOIN [' + @DatabaseName + N'].dbo.Employees e ON l.EmployeeId = e.Id
        WHERE l.Status=0 AND l.IsDeleted=0 ORDER BY l.CreatedAt';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Leave_UpdateStatus
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @Status          TINYINT,
    @ApprovedById    INT,
    @ApproverRemarks NVARCHAR(500) = NULL,
    @ActionDate      DATETIME      = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @ActionDate = ISNULL(@ActionDate, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.LeaveRequests SET
            Status=@Status,ApprovedById=@ApprovedById,ApproverRemarks=@ApproverRemarks,
            ActionDate=@ActionDate,UpdatedAt=GETUTCDATE()
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@Status TINYINT,@ApprovedById INT,@ApproverRemarks NVARCHAR(500),@ActionDate DATETIME',
        @Id,@Status,@ApprovedById,@ApproverRemarks,@ActionDate;
END
GO

-- ============================================================
-- VISA PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Visa_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT v.*, c.Name AS CustomerName, c.PassportNumber
        FROM [' + @DatabaseName + N'].dbo.VisaApplications v
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON v.CustomerId = c.Id
        WHERE v.Id=@Id AND v.IsDeleted=0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Visa_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT v.*, c.Name AS CustomerName
        FROM [' + @DatabaseName + N'].dbo.VisaApplications v
        LEFT JOIN [' + @DatabaseName + N'].dbo.Customers c ON v.CustomerId = c.Id
        WHERE v.IsDeleted=0 ORDER BY v.CreatedAt DESC';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Visa_GetByCustomer
    @DatabaseName NVARCHAR(100),
    @CustomerId   INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.VisaApplications WHERE CustomerId=@CustomerId AND IsDeleted=0 ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@CustomerId INT', @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE sp_Visa_Insert
    @DatabaseName     NVARCHAR(100),
    @ApplicationNumber NVARCHAR(20),
    @CustomerId       INT,
    @BookingId        INT           = NULL,
    @VisaType         NVARCHAR(100),
    @Country          NVARCHAR(100),
    @Status           TINYINT       = 0,
    @AppliedOn        DATE          = NULL,
    @HandledById      INT           = NULL,
    @Notes            NVARCHAR(MAX) = NULL,
    @CreatedAt        DATETIME      = NULL,
    @CreatedBy        INT           = NULL,
    @NewId            INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.VisaApplications
            (ApplicationNumber,CustomerId,BookingId,VisaType,Country,Status,
             AppliedOn,HandledById,Notes,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@ApplicationNumber,@CustomerId,@BookingId,@VisaType,@Country,@Status,
             @AppliedOn,@HandledById,@Notes,@CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@ApplicationNumber NVARCHAR(20),@CustomerId INT,@BookingId INT,@VisaType NVARCHAR(100),
          @Country NVARCHAR(100),@Status TINYINT,@AppliedOn DATE,@HandledById INT,
          @Notes NVARCHAR(MAX),@CreatedAt DATETIME,@CreatedBy INT',
        @ApplicationNumber,@CustomerId,@BookingId,@VisaType,@Country,@Status,
        @AppliedOn,@HandledById,@Notes,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.VisaApplications';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Visa_Update
    @DatabaseName    NVARCHAR(100),
    @Id              INT,
    @VisaType        NVARCHAR(100),
    @Country         NVARCHAR(100),
    @Status          TINYINT,
    @AppliedOn       DATE          = NULL,
    @SubmittedOn     DATE          = NULL,
    @ApprovedOn      DATE          = NULL,
    @ExpiryDate      DATE          = NULL,
    @RejectionReason NVARCHAR(500) = NULL,
    @VisaNumber      NVARCHAR(100) = NULL,
    @Notes           NVARCHAR(MAX) = NULL,
    @HandledById     INT           = NULL,
    @UpdatedAt       DATETIME      = NULL,
    @UpdatedBy       INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.VisaApplications SET
            VisaType=@VisaType,Country=@Country,Status=@Status,AppliedOn=@AppliedOn,
            SubmittedOn=@SubmittedOn,ApprovedOn=@ApprovedOn,ExpiryDate=@ExpiryDate,
            RejectionReason=@RejectionReason,VisaNumber=@VisaNumber,Notes=@Notes,
            HandledById=@HandledById,UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@VisaType NVARCHAR(100),@Country NVARCHAR(100),@Status TINYINT,
          @AppliedOn DATE,@SubmittedOn DATE,@ApprovedOn DATE,@ExpiryDate DATE,
          @RejectionReason NVARCHAR(500),@VisaNumber NVARCHAR(100),@Notes NVARCHAR(MAX),
          @HandledById INT,@UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@VisaType,@Country,@Status,@AppliedOn,@SubmittedOn,@ApprovedOn,@ExpiryDate,
        @RejectionReason,@VisaNumber,@Notes,@HandledById,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Visa_UpdateStatus
    @DatabaseName NVARCHAR(100),
    @Id           INT,
    @Status       TINYINT,
    @Notes        NVARCHAR(MAX) = NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.VisaApplications
        SET Status=@Status,Notes=ISNULL(@Notes,Notes),UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT,@Status TINYINT,@Notes NVARCHAR(MAX)', @Id,@Status,@Notes;
END
GO

CREATE OR ALTER PROCEDURE sp_Document_Insert
    @DatabaseName   NVARCHAR(100),
    @CustomerId     INT,
    @BookingId      INT           = NULL,
    @DocumentType   TINYINT,
    @DocumentNumber NVARCHAR(100),
    @IssueDate      DATE          = NULL,
    @ExpiryDate     DATE          = NULL,
    @IssuingCountry NVARCHAR(100) = NULL,
    @FileUrl        NVARCHAR(500) = NULL,
    @Notes          NVARCHAR(500) = NULL,
    @CreatedAt      DATETIME      = NULL,
    @CreatedBy      INT           = NULL,
    @NewId          INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.PassengerDocuments
            (CustomerId,BookingId,DocumentType,DocumentNumber,IssueDate,ExpiryDate,
             IssuingCountry,FileUrl,Notes,CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@CustomerId,@BookingId,@DocumentType,@DocumentNumber,@IssueDate,@ExpiryDate,
             @IssuingCountry,@FileUrl,@Notes,@CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@CustomerId INT,@BookingId INT,@DocumentType TINYINT,@DocumentNumber NVARCHAR(100),
          @IssueDate DATE,@ExpiryDate DATE,@IssuingCountry NVARCHAR(100),@FileUrl NVARCHAR(500),
          @Notes NVARCHAR(500),@CreatedAt DATETIME,@CreatedBy INT',
        @CustomerId,@BookingId,@DocumentType,@DocumentNumber,@IssueDate,@ExpiryDate,
        @IssuingCountry,@FileUrl,@Notes,@CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.PassengerDocuments';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Document_GetByCustomer
    @DatabaseName NVARCHAR(100),
    @CustomerId   INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.PassengerDocuments WHERE CustomerId=@CustomerId AND IsDeleted=0 ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@CustomerId INT', @CustomerId;
END
GO

CREATE OR ALTER PROCEDURE sp_Document_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'UPDATE [' + @DatabaseName + N'].dbo.PassengerDocuments SET IsDeleted=1,UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

-- ============================================================
-- SUPPLIER PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Supplier_GetById
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Suppliers WHERE Id=@Id AND IsDeleted=0';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_GetAll
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Suppliers WHERE IsDeleted=0 ORDER BY Name';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_GetByCategory
    @DatabaseName NVARCHAR(100),
    @Category     NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT * FROM [' + @DatabaseName + N'].dbo.Suppliers WHERE Category=@Category AND IsDeleted=0 ORDER BY Name';
    EXEC sp_executesql @sql, N'@Category NVARCHAR(100)', @Category;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_Insert
    @DatabaseName   NVARCHAR(100),
    @SupplierCode   NVARCHAR(20),
    @Name           NVARCHAR(150),
    @Category       NVARCHAR(100),
    @ContactPerson  NVARCHAR(150) = NULL,
    @Email          NVARCHAR(150) = NULL,
    @Phone          NVARCHAR(30),
    @AlternatePhone NVARCHAR(30)  = NULL,
    @Address        NVARCHAR(300) = NULL,
    @City           NVARCHAR(100) = NULL,
    @Country        NVARCHAR(100) = NULL,
    @Website        NVARCHAR(300) = NULL,
    @TaxNumber      NVARCHAR(100) = NULL,
    @BankDetails    NVARCHAR(MAX) = NULL,
    @IsActive       BIT           = 1,
    @Notes          NVARCHAR(MAX) = NULL,
    @CreditLimit    DECIMAL(12,2) = NULL,
    @CreditDays     INT           = NULL,
    @CreatedAt      DATETIME      = NULL,
    @CreatedBy      INT           = NULL,
    @NewId          INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SET @CreatedAt = ISNULL(@CreatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO [' + @DatabaseName + N'].dbo.Suppliers
            (SupplierCode,Name,Category,ContactPerson,Email,Phone,AlternatePhone,Address,
             City,Country,Website,TaxNumber,BankDetails,IsActive,Notes,CreditLimit,CreditDays,
             CreatedAt,CreatedBy,IsDeleted)
        VALUES
            (@SupplierCode,@Name,@Category,@ContactPerson,@Email,@Phone,@AlternatePhone,@Address,
             @City,@Country,@Website,@TaxNumber,@BankDetails,@IsActive,@Notes,@CreditLimit,@CreditDays,
             @CreatedAt,@CreatedBy,0)';

    EXEC sp_executesql @sql,
        N'@SupplierCode NVARCHAR(20),@Name NVARCHAR(150),@Category NVARCHAR(100),
          @ContactPerson NVARCHAR(150),@Email NVARCHAR(150),@Phone NVARCHAR(30),
          @AlternatePhone NVARCHAR(30),@Address NVARCHAR(300),@City NVARCHAR(100),
          @Country NVARCHAR(100),@Website NVARCHAR(300),@TaxNumber NVARCHAR(100),
          @BankDetails NVARCHAR(MAX),@IsActive BIT,@Notes NVARCHAR(MAX),
          @CreditLimit DECIMAL(12,2),@CreditDays INT,@CreatedAt DATETIME,@CreatedBy INT',
        @SupplierCode,@Name,@Category,@ContactPerson,@Email,@Phone,@AlternatePhone,@Address,
        @City,@Country,@Website,@TaxNumber,@BankDetails,@IsActive,@Notes,@CreditLimit,@CreditDays,
        @CreatedAt,@CreatedBy;

    DECLARE @idSql NVARCHAR(MAX) = N'SELECT @NewId = MAX(Id) FROM [' + @DatabaseName + N'].dbo.Suppliers';
    EXEC sp_executesql @idSql, N'@NewId INT OUTPUT', @NewId OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_Update
    @DatabaseName   NVARCHAR(100),
    @Id             INT,
    @Name           NVARCHAR(150),
    @Category       NVARCHAR(100),
    @ContactPerson  NVARCHAR(150) = NULL,
    @Email          NVARCHAR(150) = NULL,
    @Phone          NVARCHAR(30),
    @AlternatePhone NVARCHAR(30)  = NULL,
    @Address        NVARCHAR(300) = NULL,
    @City           NVARCHAR(100) = NULL,
    @Country        NVARCHAR(100) = NULL,
    @Website        NVARCHAR(300) = NULL,
    @TaxNumber      NVARCHAR(100) = NULL,
    @BankDetails    NVARCHAR(MAX) = NULL,
    @IsActive       BIT,
    @Notes          NVARCHAR(MAX) = NULL,
    @CreditLimit    DECIMAL(12,2) = NULL,
    @CreditDays     INT           = NULL,
    @UpdatedAt      DATETIME      = NULL,
    @UpdatedBy      INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    SET @UpdatedAt = ISNULL(@UpdatedAt, GETUTCDATE());

    DECLARE @sql NVARCHAR(MAX) = N'
        UPDATE [' + @DatabaseName + N'].dbo.Suppliers SET
            Name=@Name,Category=@Category,ContactPerson=@ContactPerson,Email=@Email,Phone=@Phone,
            AlternatePhone=@AlternatePhone,Address=@Address,City=@City,Country=@Country,
            Website=@Website,TaxNumber=@TaxNumber,BankDetails=@BankDetails,IsActive=@IsActive,
            Notes=@Notes,CreditLimit=@CreditLimit,CreditDays=@CreditDays,
            UpdatedAt=@UpdatedAt,UpdatedBy=@UpdatedBy
        WHERE Id=@Id';

    EXEC sp_executesql @sql,
        N'@Id INT,@Name NVARCHAR(150),@Category NVARCHAR(100),@ContactPerson NVARCHAR(150),
          @Email NVARCHAR(150),@Phone NVARCHAR(30),@AlternatePhone NVARCHAR(30),
          @Address NVARCHAR(300),@City NVARCHAR(100),@Country NVARCHAR(100),
          @Website NVARCHAR(300),@TaxNumber NVARCHAR(100),@BankDetails NVARCHAR(MAX),
          @IsActive BIT,@Notes NVARCHAR(MAX),@CreditLimit DECIMAL(12,2),@CreditDays INT,
          @UpdatedAt DATETIME,@UpdatedBy INT',
        @Id,@Name,@Category,@ContactPerson,@Email,@Phone,@AlternatePhone,@Address,
        @City,@Country,@Website,@TaxNumber,@BankDetails,@IsActive,@Notes,
        @CreditLimit,@CreditDays,@UpdatedAt,@UpdatedBy;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_Delete
    @DatabaseName NVARCHAR(100),
    @Id           INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'UPDATE [' + @DatabaseName + N'].dbo.Suppliers SET IsDeleted=1,UpdatedAt=GETUTCDATE() WHERE Id=@Id';
    EXEC sp_executesql @sql, N'@Id INT', @Id;
END
GO

CREATE OR ALTER PROCEDURE sp_Supplier_GenerateCode
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @count INT;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT @count = COUNT(1) FROM [' + @DatabaseName + N'].dbo.Suppliers';
    EXEC sp_executesql @sql, N'@count INT OUTPUT', @count OUTPUT;
    SELECT 'SUP' + RIGHT('00000' + CAST(@count + 1 AS VARCHAR), 5);
END
GO

-- ============================================================
-- DASHBOARD PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_Dashboard_GetStats
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Customers   WHERE IsDeleted=0) AS TotalCustomers,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings     WHERE IsDeleted=0) AS TotalBookings,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Bookings     WHERE IsDeleted=0 AND Status IN (1,2)) AS ActiveBookings,
            (SELECT ISNULL(SUM(TotalAmount),0) FROM [' + @DatabaseName + N'].dbo.Bookings WHERE IsDeleted=0 AND Status!=3) AS TotalRevenue,
            (SELECT ISNULL(SUM(TotalAmount),0) FROM [' + @DatabaseName + N'].dbo.Bookings
                WHERE IsDeleted=0 AND Status!=3
                AND MONTH(CreatedAt)=MONTH(GETDATE()) AND YEAR(CreatedAt)=YEAR(GETDATE())) AS MonthlyRevenue,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.TourPackages WHERE IsDeleted=0 AND Status=0) AS TotalPackages,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.Employees    WHERE IsDeleted=0 AND Status=0) AS TotalEmployees,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.VisaApplications WHERE IsDeleted=0 AND Status IN (1,2)) AS PendingVisas,
            (SELECT COUNT(1) FROM [' + @DatabaseName + N'].dbo.LeaveRequests WHERE IsDeleted=0 AND Status=0) AS PendingLeaves,
            (SELECT ISNULL(SUM(TotalAmount-PaidAmount),0) FROM [' + @DatabaseName + N'].dbo.Invoices WHERE IsDeleted=0 AND Status!=2) AS OutstandingAmount';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Dashboard_GetMonthlyRevenue
    @DatabaseName NVARCHAR(100),
    @Year         INT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        WITH Months AS (SELECT n AS MonthNum FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v(n))
        SELECT m.MonthNum AS Month,
               DATENAME(MONTH, DATEFROMPARTS(@Year, m.MonthNum, 1)) AS MonthName,
               ISNULL(SUM(b.TotalAmount), 0) AS Revenue,
               COUNT(b.Id) AS BookingCount
        FROM Months m
        LEFT JOIN [' + @DatabaseName + N'].dbo.Bookings b
            ON MONTH(b.CreatedAt)=m.MonthNum AND YEAR(b.CreatedAt)=@Year
            AND b.IsDeleted=0 AND b.Status!=3
        GROUP BY m.MonthNum
        ORDER BY m.MonthNum';
    EXEC sp_executesql @sql, N'@Year INT', @Year;
END
GO

CREATE OR ALTER PROCEDURE sp_Dashboard_GetBookingStatusChart
    @DatabaseName NVARCHAR(100)
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT
            CASE Status WHEN 0 THEN ''Inquiry'' WHEN 1 THEN ''Confirmed'' WHEN 2 THEN ''Pending''
                        WHEN 3 THEN ''Cancelled'' WHEN 4 THEN ''Completed'' WHEN 5 THEN ''Refunded'' END AS Status,
            COUNT(1) AS Count,
            CASE Status WHEN 0 THEN ''#6c757d'' WHEN 1 THEN ''#198754'' WHEN 2 THEN ''#ffc107''
                        WHEN 3 THEN ''#dc3545'' WHEN 4 THEN ''#0d6efd'' WHEN 5 THEN ''#6f42c1'' END AS Color
        FROM [' + @DatabaseName + N'].dbo.Bookings WHERE IsDeleted=0 GROUP BY Status';
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE sp_Dashboard_GetRecentBookings
    @DatabaseName NVARCHAR(100),
    @TopCount     INT = 10
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT TOP (@TopCount)
            b.Id, b.BookingReference,
            c.Name AS CustomerName,
            b.Destination, b.TravelDate, b.TotalAmount,
            CASE b.Status WHEN 0 THEN ''Inquiry'' WHEN 1 THEN ''Confirmed'' WHEN 2 THEN ''Pending''
                          WHEN 3 THEN ''Cancelled'' WHEN 4 THEN ''Completed'' WHEN 5 THEN ''Refunded'' END AS Status,
            CASE b.PaymentStatus WHEN 0 THEN ''Unpaid'' WHEN 1 THEN ''Partial'' WHEN 2 THEN ''Paid''
                                 WHEN 3 THEN ''Refunded'' WHEN 4 THEN ''Overdue'' END AS PaymentStatus
        FROM [' + @DatabaseName + N'].dbo.Bookings b
        INNER JOIN [' + @DatabaseName + N'].dbo.Customers c ON b.CustomerId=c.Id
        WHERE b.IsDeleted=0 ORDER BY b.CreatedAt DESC';
    EXEC sp_executesql @sql, N'@TopCount INT', @TopCount;
END
GO

CREATE OR ALTER PROCEDURE sp_Dashboard_GetTopPackages
    @DatabaseName NVARCHAR(100),
    @TopCount     INT = 5
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT TOP (@TopCount)
            p.Id, p.PackageCode, p.Name, p.Destination,
            COUNT(b.Id) AS BookingCount,
            ISNULL(SUM(b.TotalAmount), 0) AS TotalRevenue
        FROM [' + @DatabaseName + N'].dbo.TourPackages p
        LEFT JOIN [' + @DatabaseName + N'].dbo.Bookings b ON p.Id=b.PackageId AND b.IsDeleted=0
        WHERE p.IsDeleted=0
        GROUP BY p.Id, p.PackageCode, p.Name, p.Destination
        ORDER BY BookingCount DESC';
    EXEC sp_executesql @sql, N'@TopCount INT', @TopCount;
END
GO

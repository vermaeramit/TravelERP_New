-- ============================================================
-- TRAVEL ERP -- TENANT DATABASE SCHEMA
-- This script is run per company. Replace {DBNAME} with actual DB name.
-- ============================================================

-- CREATE DATABASE {DBNAME};
-- GO
-- USE {DBNAME};
-- GO

-- ============================================================
-- BRANCHES
-- ============================================================
CREATE TABLE Branches (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(150) NOT NULL,
    Code        NVARCHAR(20)  NOT NULL,
    Address     NVARCHAR(300) NULL,
    City        NVARCHAR(100) NULL,
    Phone       NVARCHAR(30)  NULL,
    Email       NVARCHAR(150) NULL,
    IsHeadOffice BIT          NOT NULL DEFAULT 0,
    IsActive    BIT           NOT NULL DEFAULT 1,
    CreatedAt   DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME      NULL,
    CreatedBy   INT           NULL,
    UpdatedBy   INT           NULL,
    IsDeleted   BIT           NOT NULL DEFAULT 0
);
GO

-- ============================================================
-- CUSTOMERS
-- ============================================================
CREATE TABLE Customers (
    Id               INT IDENTITY(1,1) PRIMARY KEY,
    CustomerCode     NVARCHAR(20)  NOT NULL UNIQUE,
    Name             NVARCHAR(150) NOT NULL,
    Mobile           NVARCHAR(30)  NOT NULL,
    Email            NVARCHAR(150) NULL,
    Destination      NVARCHAR(200) NULL,
    TravelingDate    DATE          NULL,
    LeavingFrom      NVARCHAR(100) NULL,
    TravelCity       NVARCHAR(100) NULL,
    HotelRecommended NVARCHAR(200) NULL,
    NoOfAdults       TINYINT       NULL,
    NoOfChildren     TINYINT       NULL,
    NoOfDays         TINYINT       NULL,
    AssignedTo       NVARCHAR(150) NULL,
    LeadSource       NVARCHAR(100) NULL,
    Infant           NVARCHAR(50)  NULL,
    Remark           NVARCHAR(MAX) NULL,
    PassportNumber   NVARCHAR(50)  NULL,
    PassportExpiry   DATE          NULL,
    Notes            NVARCHAR(MAX) NULL,
    CreatedAt        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt        DATETIME      NULL,
    CreatedBy        INT           NULL,
    UpdatedBy        INT           NULL,
    IsDeleted        BIT           NOT NULL DEFAULT 0
);
GO

-- ============================================================
-- SUPPLIERS
-- ============================================================
CREATE TABLE Suppliers (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    SupplierCode    NVARCHAR(20)  NOT NULL UNIQUE,
    Name            NVARCHAR(150) NOT NULL,
    Category        NVARCHAR(100) NOT NULL,
    ContactPerson   NVARCHAR(150) NULL,
    Email           NVARCHAR(150) NULL,
    Phone           NVARCHAR(30)  NOT NULL,
    AlternatePhone  NVARCHAR(30)  NULL,
    Address         NVARCHAR(300) NULL,
    City            NVARCHAR(100) NULL,
    Country         NVARCHAR(100) NULL,
    Website         NVARCHAR(300) NULL,
    TaxNumber       NVARCHAR(100) NULL,
    BankDetails     NVARCHAR(MAX) NULL,
    IsActive        BIT           NOT NULL DEFAULT 1,
    Notes           NVARCHAR(MAX) NULL,
    CreditLimit     DECIMAL(12,2) NULL,
    CreditDays      INT           NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0
);
GO

-- ============================================================
-- TOUR PACKAGES
-- ============================================================
CREATE TABLE TourPackages (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    PackageCode     NVARCHAR(20)  NOT NULL UNIQUE,
    Name            NVARCHAR(200) NOT NULL,
    Description     NVARCHAR(MAX) NULL,
    Type            TINYINT       NOT NULL,
    Status          TINYINT       NOT NULL DEFAULT 0,
    Destination     NVARCHAR(200) NOT NULL,
    Origin          NVARCHAR(200) NULL,
    DurationDays    INT           NOT NULL DEFAULT 1,
    DurationNights  INT           NOT NULL DEFAULT 0,
    BasePrice       DECIMAL(12,2) NOT NULL DEFAULT 0,
    ChildPrice      DECIMAL(12,2) NULL,
    InfantPrice     DECIMAL(12,2) NULL,
    Inclusions      NVARCHAR(MAX) NULL,
    Exclusions      NVARCHAR(MAX) NULL,
    Itinerary       NVARCHAR(MAX) NULL,
    ImageUrl        NVARCHAR(500) NULL,
    MaxCapacity     INT           NOT NULL DEFAULT 20,
    ValidFrom       DATE          NULL,
    ValidTo         DATE          NULL,
    IsFeatured      BIT           NOT NULL DEFAULT 0,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0
);
GO

-- ============================================================
-- BOOKINGS
-- ============================================================
CREATE TABLE Bookings (
    Id               INT IDENTITY(1,1) PRIMARY KEY,
    BookingReference NVARCHAR(20)  NOT NULL UNIQUE,
    CustomerId       INT           NOT NULL,
    PackageId        INT           NULL,
    BookingType      TINYINT       NOT NULL DEFAULT 0,
    Status           TINYINT       NOT NULL DEFAULT 0,
    PaymentStatus    TINYINT       NOT NULL DEFAULT 0,
    TravelDate       DATE          NOT NULL,
    ReturnDate       DATE          NULL,
    Adults           INT           NOT NULL DEFAULT 1,
    Children         INT           NOT NULL DEFAULT 0,
    Infants          INT           NOT NULL DEFAULT 0,
    Destination      NVARCHAR(200) NOT NULL,
    TotalAmount      DECIMAL(12,2) NOT NULL DEFAULT 0,
    PaidAmount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    DiscountAmount   DECIMAL(12,2) NOT NULL DEFAULT 0,
    SpecialRequests  NVARCHAR(MAX) NULL,
    InternalNotes    NVARCHAR(MAX) NULL,
    BranchId         INT           NULL,
    AgentId          INT           NULL,
    CreatedAt        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt        DATETIME      NULL,
    CreatedBy        INT           NULL,
    UpdatedBy        INT           NULL,
    IsDeleted        BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Bookings_Customer FOREIGN KEY (CustomerId) REFERENCES Customers(Id),
    CONSTRAINT FK_Bookings_Package  FOREIGN KEY (PackageId) REFERENCES TourPackages(Id)
);
GO

-- ============================================================
-- INVOICES
-- ============================================================
CREATE TABLE Invoices (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNumber   NVARCHAR(20)  NOT NULL UNIQUE,
    BookingId       INT           NOT NULL,
    CustomerId      INT           NOT NULL,
    Status          TINYINT       NOT NULL DEFAULT 0,
    InvoiceDate     DATE          NOT NULL DEFAULT GETUTCDATE(),
    DueDate         DATE          NOT NULL,
    SubTotal        DECIMAL(12,2) NOT NULL DEFAULT 0,
    TaxAmount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    DiscountAmount  DECIMAL(12,2) NOT NULL DEFAULT 0,
    TotalAmount     DECIMAL(12,2) NOT NULL DEFAULT 0,
    PaidAmount      DECIMAL(12,2) NOT NULL DEFAULT 0,
    Notes           NVARCHAR(MAX) NULL,
    TermsAndConditions NVARCHAR(MAX) NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Invoices_Booking  FOREIGN KEY (BookingId)  REFERENCES Bookings(Id),
    CONSTRAINT FK_Invoices_Customer FOREIGN KEY (CustomerId) REFERENCES Customers(Id)
);
GO

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE Payments (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceId       INT           NOT NULL,
    CustomerId      INT           NOT NULL,
    BookingId       INT           NOT NULL,
    Amount          DECIMAL(12,2) NOT NULL,
    Method          TINYINT       NOT NULL DEFAULT 0,
    PaymentDate     DATE          NOT NULL DEFAULT GETUTCDATE(),
    ReferenceNumber NVARCHAR(100) NULL,
    Notes           NVARCHAR(500) NULL,
    ReceivedBy      NVARCHAR(150) NOT NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Payments_Invoice FOREIGN KEY (InvoiceId) REFERENCES Invoices(Id)
);
GO

-- ============================================================
-- EMPLOYEES
-- ============================================================
CREATE TABLE Employees (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeCode    NVARCHAR(20)  NOT NULL UNIQUE,
    FirstName       NVARCHAR(100) NOT NULL,
    LastName        NVARCHAR(100) NOT NULL,
    Email           NVARCHAR(150) NOT NULL,
    Phone           NVARCHAR(30)  NOT NULL,
    Gender          TINYINT       NULL,
    DateOfBirth     DATE          NULL,
    Designation     NVARCHAR(150) NOT NULL,
    Department      NVARCHAR(100) NOT NULL,
    BranchId        INT           NULL,
    JoiningDate     DATE          NOT NULL,
    LeavingDate     DATE          NULL,
    Status          TINYINT       NOT NULL DEFAULT 0,
    BasicSalary     DECIMAL(12,2) NOT NULL DEFAULT 0,
    Address         NVARCHAR(300) NULL,
    EmergencyContact NVARCHAR(200) NULL,
    ProfileImageUrl NVARCHAR(500) NULL,
    MasterUserId    INT           NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0
);
GO

-- ============================================================
-- LEAVE REQUESTS
-- ============================================================
CREATE TABLE LeaveRequests (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId      INT           NOT NULL,
    LeaveType       TINYINT       NOT NULL,
    FromDate        DATE          NOT NULL,
    ToDate          DATE          NOT NULL,
    TotalDays       INT           NOT NULL DEFAULT 1,
    Reason          NVARCHAR(500) NOT NULL,
    Status          TINYINT       NOT NULL DEFAULT 0,
    ApprovedById    INT           NULL,
    ApproverRemarks NVARCHAR(500) NULL,
    ActionDate      DATETIME      NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Leaves_Employee FOREIGN KEY (EmployeeId) REFERENCES Employees(Id)
);
GO

-- ============================================================
-- VISA APPLICATIONS
-- ============================================================
CREATE TABLE VisaApplications (
    Id                INT IDENTITY(1,1) PRIMARY KEY,
    ApplicationNumber NVARCHAR(20)  NOT NULL UNIQUE,
    CustomerId        INT           NOT NULL,
    BookingId         INT           NULL,
    VisaType          NVARCHAR(100) NOT NULL,
    Country           NVARCHAR(100) NOT NULL,
    Status            TINYINT       NOT NULL DEFAULT 0,
    AppliedOn         DATE          NULL,
    SubmittedOn       DATE          NULL,
    ApprovedOn        DATE          NULL,
    ExpiryDate        DATE          NULL,
    RejectionReason   NVARCHAR(500) NULL,
    VisaNumber        NVARCHAR(100) NULL,
    Notes             NVARCHAR(MAX) NULL,
    HandledById       INT           NULL,
    CreatedAt         DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt         DATETIME      NULL,
    CreatedBy         INT           NULL,
    UpdatedBy         INT           NULL,
    IsDeleted         BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Visa_Customer FOREIGN KEY (CustomerId) REFERENCES Customers(Id)
);
GO

-- ============================================================
-- PASSENGER DOCUMENTS
-- ============================================================
CREATE TABLE PassengerDocuments (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId      INT           NOT NULL,
    BookingId       INT           NULL,
    DocumentType    TINYINT       NOT NULL,
    DocumentNumber  NVARCHAR(100) NOT NULL,
    IssueDate       DATE          NULL,
    ExpiryDate      DATE          NULL,
    IssuingCountry  NVARCHAR(100) NULL,
    FileUrl         NVARCHAR(500) NULL,
    Notes           NVARCHAR(500) NULL,
    CreatedAt       DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME      NULL,
    CreatedBy       INT           NULL,
    UpdatedBy       INT           NULL,
    IsDeleted       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_Docs_Customer FOREIGN KEY (CustomerId) REFERENCES Customers(Id)
);
GO

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IX_Customers_Email     ON Customers(Email);
CREATE INDEX IX_Customers_Mobile    ON Customers(Mobile);
CREATE INDEX IX_Bookings_CustomerId ON Bookings(CustomerId);
CREATE INDEX IX_Bookings_TravelDate ON Bookings(TravelDate);
CREATE INDEX IX_Bookings_Status     ON Bookings(Status);
CREATE INDEX IX_Invoices_BookingId  ON Invoices(BookingId);
CREATE INDEX IX_Payments_InvoiceId  ON Payments(InvoiceId);
GO

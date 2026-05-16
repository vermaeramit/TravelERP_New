-- ============================================================
-- LOAD TEST: insert 100,000 leads into TravelERP_Client1
-- LeadNumber prefix "LOAD-2026-*" so they don't collide with
-- real LD-* leads and can be deleted cleanly when done.
-- Run with: sqlcmd -d TravelERP_Client1 -i load_test_leads.sql
-- ============================================================

SET NOCOUNT ON;
DECLARE @t0 DATETIME2 = SYSUTCDATETIME();
DECLARE @start INT = ISNULL((SELECT COUNT(*) FROM Leads WHERE LeadNumber LIKE 'LOAD-%'), 0);
PRINT CONCAT('Existing LOAD-* leads: ', @start);

-- Sample destinations (loop through whatever's in the Destinations table)
DECLARE @destCount INT = (SELECT COUNT(*) FROM Destinations);
DECLARE @minDest INT  = (SELECT MIN(Id) FROM Destinations);
PRINT CONCAT('Destinations available: ', @destCount, ' starting at Id=', @minDest);

DECLARE @defaultStatusId INT = (SELECT TOP 1 Id FROM LeadStatuses WHERE IsDefault = 1 AND IsActive = 1);
IF @defaultStatusId IS NULL SET @defaultStatusId = (SELECT TOP 1 Id FROM LeadStatuses WHERE IsActive = 1);
PRINT CONCAT('Default status Id: ', @defaultStatusId);

-- Numbers table 100k via cross-join of sys.all_columns
;WITH N AS (
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO Leads
    (LeadNumber, StatusId, SourceId, AssignedToUserId, DestinationId,
     Name, Mobile, Email, TravelingDate, LeavingFrom, HotelRecommended,
     Adults, Children, Infants, Days, Remark,
     IsActive, CreatedAt, CreatedBy)
SELECT
    CONCAT('LOAD-2026-', RIGHT('000000' + CAST(n AS NVARCHAR(10)), 6))                              AS LeadNumber,
    @defaultStatusId                                                                                AS StatusId,
    NULL                                                                                            AS SourceId,
    NULL                                                                                            AS AssignedToUserId,
    @minDest + (ABS(CHECKSUM(NEWID())) % @destCount)                                                AS DestinationId,
    CONCAT(
        CHOOSE(1 + (n % 12), N'Aarav', N'Vivaan', N'Aditya', N'Ishaan', N'Rohan',
                            N'Karan', N'Riya', N'Ananya', N'Priya', N'Sneha', N'Meera', N'Kavya'),
        N' ',
        CHOOSE(1 + (n % 10), N'Sharma', N'Verma', N'Gupta', N'Kumar', N'Singh',
                            N'Patel', N'Reddy', N'Iyer', N'Khan', N'Mehta'),
        N' #', CAST(n AS NVARCHAR(10))
    )                                                                                               AS Name,
    CONCAT('+91 ', 90000 + (n % 9999), ' ', RIGHT('00000' + CAST((n * 7919) % 100000 AS NVARCHAR(5)), 5))
                                                                                                    AS Mobile,
    CONCAT('loadtest', n, '@example.com')                                                           AS Email,
    DATEADD(DAY, 30 + (n % 365), CAST(GETUTCDATE() AS DATE))                                        AS TravelingDate,
    CHOOSE(1 + (n % 8), N'Delhi', N'Mumbai', N'Bangalore', N'Hyderabad',
                       N'Chennai', N'Kolkata', N'Pune', N'Ahmedabad')                               AS LeavingFrom,
    CASE (n % 4)
        WHEN 0 THEN N'4-star or above'
        WHEN 1 THEN N'5-star with sea view'
        WHEN 2 THEN N'Budget-friendly'
        ELSE NULL
    END                                                                                             AS HotelRecommended,
    1 + (n % 4)                                                                                     AS Adults,
    (n % 3)                                                                                         AS Children,
    (n % 2)                                                                                         AS Infants,
    3 + (n % 12)                                                                                    AS Days,
    CONCAT(N'[LOADTEST] ',
           CHOOSE(1 + (n % 6),
                  N'Looking for honeymoon package, 4-star hotel preferred',
                  N'Family of 4, kids under 10, beach destination',
                  N'Corporate group booking, need GST invoice',
                  N'Senior citizens, prefer non-stop flights',
                  N'Adventure seekers, want water sports included',
                  N'Budget around ₹1.2L per couple, flexible on dates'))                            AS Remark,
    1                                                                                               AS IsActive,
    DATEADD(MINUTE, -1 * (n % 525600), SYSUTCDATETIME())                                            AS CreatedAt,
    0                                                                                               AS CreatedBy
FROM N;

DECLARE @ins INT = @@ROWCOUNT;
DECLARE @elapsed INT = DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME());
PRINT CONCAT('Inserted: ', @ins, ' rows in ', @elapsed, ' ms');
DECLARE @total INT = (SELECT COUNT(*) FROM Leads);
PRINT CONCAT('Total leads now: ', @total);

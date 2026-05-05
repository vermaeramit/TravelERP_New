namespace TravelERP.Shared.Enums;

public enum CompanyStatus { Active, Suspended, Trial, Expired }
public enum UserRole { SuperAdmin, CompanyAdmin, Manager, Agent, Accountant, HRManager, Viewer }
public enum BookingStatus { Inquiry, Confirmed, Pending, Cancelled, Completed, Refunded }
public enum BookingType { FIT, Group, Corporate, Honeymoon, Family }
public enum PaymentStatus { Unpaid, PartiallyPaid, Paid, Refunded, Overdue }
public enum PaymentMethod { Cash, BankTransfer, CreditCard, DebitCard, OnlinePayment, Cheque }
public enum PackageStatus { Active, Inactive, Seasonal, SoldOut }
public enum PackageType { Domestic, International, Pilgrimage, Adventure, Cruise, Safari }
public enum VisaStatus { NotApplied, Applied, Processing, Approved, Rejected, Expired }
public enum LeaveStatus { Pending, Approved, Rejected, Cancelled }
public enum LeaveType { Annual, Sick, Casual, Maternity, Paternity, Unpaid }
public enum EmploymentStatus { Active, Inactive, Terminated, OnLeave }
public enum InvoiceStatus { Draft, Sent, Paid, Overdue, Cancelled }
public enum DocumentType { Passport, Visa, Insurance, Ticket, Hotel, Transfer, Other }
public enum Gender { Male, Female, Other }
public enum TransactionType { Income, Expense, Refund, Adjustment }

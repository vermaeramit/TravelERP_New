using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Shared.Enums;

namespace TravelERP.Web.Controllers;

[Authorize]
public class BookingsController : Controller
{
    private readonly IBookingRepository _repo;
    private readonly ICustomerRepository _customers;
    private readonly IPackageRepository _packages;
    private readonly IInvoiceRepository _invoices;
    private readonly ITenantContext _tenant;

    public BookingsController(IBookingRepository repo, ICustomerRepository customers,
        IPackageRepository packages, IInvoiceRepository invoices, ITenantContext tenant)
    {
        _repo = repo;
        _customers = customers;
        _packages = packages;
        _invoices = invoices;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index(string? status)
    {
        ViewData["Title"] = "Bookings";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Bookings", null) };
        ViewBag.StatusFilter = status;

        IEnumerable<Booking> bookings;
        if (!string.IsNullOrEmpty(status) && Enum.TryParse<BookingStatus>(status, out var bStatus))
            bookings = await _repo.GetByStatusAsync(bStatus);
        else
            bookings = await _repo.GetAllAsync();

        return View(bookings);
    }

    public async Task<IActionResult> Details(int id)
    {
        var booking = await _repo.GetByIdAsync(id);
        if (booking == null) return NotFound();
        ViewData["Title"] = $"Booking {booking.BookingReference}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Bookings", "/Bookings"), (booking.BookingReference, null) };

        var invoices = await _invoices.GetByBookingAsync(id);
        ViewBag.Invoices = invoices;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        return View(booking);
    }

    public async Task<IActionResult> Create()
    {
        ViewData["Title"] = "New Booking";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Bookings", "/Bookings"), ("New Booking", null) };
        await LoadDropdownsAsync();
        return View(new Booking
        {
            BookingReference = await _repo.GenerateBookingReferenceAsync(),
            TravelDate = DateTime.Today.AddDays(7)
        });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Booking model)
    {
        if (!ModelState.IsValid) { await LoadDropdownsAsync(); return View(model); }

        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        var id = await _repo.InsertAsync(model);

        // Auto-create invoice
        var invoice = new Invoice
        {
            InvoiceNumber = await _invoices.GenerateInvoiceNumberAsync(),
            BookingId = id,
            CustomerId = model.CustomerId,
            Status = InvoiceStatus.Draft,
            InvoiceDate = DateTime.Today,
            DueDate = DateTime.Today.AddDays(7),
            SubTotal = model.TotalAmount - model.DiscountAmount,
            DiscountAmount = model.DiscountAmount,
            TotalAmount = model.TotalAmount,
            CreatedBy = _tenant.UserId,
            CreatedAt = DateTime.UtcNow
        };
        await _invoices.InsertAsync(invoice);

        TempData["Success"] = $"Booking {model.BookingReference} created with invoice.";
        return RedirectToAction(nameof(Details), new { id });
    }

    public async Task<IActionResult> Edit(int id)
    {
        var booking = await _repo.GetByIdAsync(id);
        if (booking == null) return NotFound();
        ViewData["Title"] = $"Edit Booking {booking.BookingReference}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Bookings", "/Bookings"), ("Edit", null) };
        await LoadDropdownsAsync();
        return View(booking);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(Booking model)
    {
        if (!ModelState.IsValid) { await LoadDropdownsAsync(); return View(model); }
        model.UpdatedBy = _tenant.UserId;
        model.UpdatedAt = DateTime.UtcNow;
        await _repo.UpdateAsync(model);
        TempData["Success"] = "Booking updated successfully.";
        return RedirectToAction(nameof(Details), new { id = model.Id });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateStatus(int id, BookingStatus status)
    {
        await _repo.UpdateStatusAsync(id, status);
        TempData["Success"] = $"Booking status updated to {status}.";
        return RedirectToAction(nameof(Details), new { id });
    }

    private async Task LoadDropdownsAsync()
    {
        ViewBag.Customers = await _customers.GetAllAsync();
        ViewBag.Packages  = await _packages.GetAllAsync();
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
    }
}

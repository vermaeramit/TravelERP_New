using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Shared.Enums;

namespace TravelERP.Web.Controllers;

[Authorize]
[Route("[controller]")]
public class FinanceController : Controller
{
    private readonly IInvoiceRepository _invoices;
    private readonly IBookingRepository _bookings;
    private readonly ITenantContext _tenant;

    public FinanceController(IInvoiceRepository invoices, IBookingRepository bookings, ITenantContext tenant)
    {
        _invoices = invoices;
        _bookings = bookings;
        _tenant = tenant;
    }

    [HttpGet("Invoices")]
    public async Task<IActionResult> Invoices()
    {
        ViewData["Title"] = "Invoices";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Finance", null), ("Invoices", null) };
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        return View(await _invoices.GetAllAsync());
    }

    [HttpGet("Invoice/{id}")]
    public async Task<IActionResult> InvoiceDetails(int id)
    {
        var invoice = await _invoices.GetByIdAsync(id);
        if (invoice == null) return NotFound();
        ViewData["Title"] = $"Invoice {invoice.InvoiceNumber}";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Finance", null), ("Invoices", "/Finance/Invoices"), (invoice.InvoiceNumber, null) };

        var payments = await _invoices.GetPaymentsByInvoiceAsync(id);
        ViewBag.Payments = payments;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        return View(invoice);
    }

    [HttpGet("AddPayment/{invoiceId}")]
    public async Task<IActionResult> AddPayment(int invoiceId)
    {
        var invoice = await _invoices.GetByIdAsync(invoiceId);
        if (invoice == null) return NotFound();
        ViewData["Title"] = "Record Payment";
        ViewData["Breadcrumbs"] = new List<(string, string?)> { ("Finance", null), ("Invoices", "/Finance/Invoices"), ("Record Payment", null) };
        ViewBag.Invoice = invoice;
        ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
        return View(new Payment
        {
            InvoiceId = invoiceId,
            CustomerId = invoice.CustomerId,
            BookingId = invoice.BookingId,
            Amount = invoice.TotalAmount - invoice.PaidAmount,
            PaymentDate = DateTime.Today
        });
    }

    [HttpPost("AddPayment/{invoiceId}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddPayment(int invoiceId, Payment model)
    {
        if (!ModelState.IsValid)
        {
            var invoice = await _invoices.GetByIdAsync(invoiceId);
            ViewBag.Invoice = invoice;
            ViewBag.CurrencySymbol = _tenant.CurrencySymbol;
            return View(model);
        }

        model.ReceivedBy = _tenant.UserFullName;
        model.CreatedBy = _tenant.UserId;
        model.CreatedAt = DateTime.UtcNow;
        await _invoices.InsertPaymentAsync(model);

        TempData["Success"] = $"Payment of {_tenant.CurrencySymbol}{model.Amount:N2} recorded.";
        return RedirectToAction(nameof(InvoiceDetails), new { id = invoiceId });
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Web.Services;

namespace TravelERP.Web.Controllers;

[Authorize]
public class BookingsController : Controller
{
    private readonly IBookingRepository _repo;
    private readonly IPackageRepository _packages;
    private readonly ILeadRepository _leads;
    private readonly IDestinationRepository _destinations;
    private readonly IBankAccountRepository _banks;
    private readonly ICompanyRepository _companies;
    private readonly PdfService _pdf;
    private readonly ITenantContext _tenant;

    public BookingsController(
        IBookingRepository repo,
        IPackageRepository packages,
        ILeadRepository leads,
        IDestinationRepository destinations,
        IBankAccountRepository banks,
        ICompanyRepository companies,
        PdfService pdf,
        ITenantContext tenant)
    {
        _repo = repo;
        _packages = packages;
        _leads = leads;
        _destinations = destinations;
        _banks = banks;
        _companies = companies;
        _pdf = pdf;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index(string? search, string? status, int page = 1, int pageSize = 20)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        ViewData["Title"] = "Bookings";
        var paged = await _repo.GetPagedAsync(search, status, page, pageSize);
        ViewBag.Search = search;
        ViewBag.Status = status;
        return View(paged);
    }

    [HttpGet]
    public async Task<IActionResult> Create(int? packageId, int? optionId, int? leadId)
    {
        if (!_tenant.CanAdd(AppModules.Bookings)) return Forbid();
        ViewData["Title"] = "Create Booking";
        await PopulateLookupsAsync();

        var booking = new Booking
        {
            CustomerName = "",
            Adults = 1,
            Status = "Confirmed",
            Currency = "INR",
            Installments = [new BookingInstallment { InstallmentNo = 1, PaymentStatus = "Pending" }]
        };

        if (packageId.HasValue && optionId.HasValue)
        {
            var pkg = await _packages.GetByIdAsync(packageId.Value);
            var opt = pkg?.Options.FirstOrDefault(o => o.Id == optionId.Value);
            if (pkg != null && opt != null)
            {
                booking.LeadId          = pkg.LeadId;
                booking.PackageId       = pkg.Id;
                booking.PackageOptionId = opt.Id;
                booking.OptionName      = opt.OptionName;
                booking.CustomerName    = pkg.CustomerName;
                booking.CustomerMobile  = pkg.CustomerMobile;
                booking.CustomerEmail   = pkg.CustomerEmail;
                booking.Adults          = pkg.Adults;
                booking.Children        = pkg.Children;
                booking.Infants         = pkg.Infants;
                booking.StartDate       = pkg.StartDate;
                booking.Days            = pkg.Days;
                booking.Nights          = pkg.Nights;
                booking.DestinationId   = pkg.DestinationId;
                booking.TotalAmount     = opt.FinalPrice;
                booking.Currency        = pkg.Currency;
                booking.Notes           = $"Booked from package {pkg.PackageNumber} — {opt.OptionName}";
                booking.Installments = [new BookingInstallment
                {
                    InstallmentNo = 1,
                    Amount = opt.FinalPrice,
                    DueDate = DateTime.UtcNow.Date.AddDays(7),
                    PaymentStatus = "Pending"
                }];
            }
        }
        else if (leadId.HasValue)
        {
            var lead = await _leads.GetByIdAsync(leadId.Value);
            if (lead != null)
            {
                booking.LeadId         = lead.Id;
                booking.CustomerName   = lead.Name;
                booking.CustomerMobile = lead.Mobile;
                booking.CustomerEmail  = lead.Email;
                booking.Adults         = lead.Adults;
                booking.Children       = lead.Children;
                booking.Infants        = lead.Infants;
                booking.Days           = lead.Days;
                booking.StartDate      = lead.TravelingDate;
                booking.DestinationId  = lead.DestinationId;
            }
        }

        return View("Form", booking);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(BookingFormVm vm)
    {
        if (!_tenant.CanAdd(AppModules.Bookings)) return Forbid();
        var b = vm.ToBooking();
        if (!Validate(b))
        {
            await PopulateLookupsAsync();
            return View("Form", b);
        }

        var (id, number, _) = await _repo.InsertAsync(b);

        // Snapshot the chosen package option's hotels onto this booking so the
        // voucher stays correct even if the package is edited later.
        if (b.PackageId.HasValue && b.PackageOptionId.HasValue)
        {
            var pkg = await _packages.GetByIdAsync(b.PackageId.Value);
            var opt = pkg?.Options.FirstOrDefault(o => o.Id == b.PackageOptionId.Value);
            if (opt != null)
            {
                await _repo.SnapshotHotelsAsync(id, opt.Hotels);
            }
        }

        TempData["Success"] = $"Booking {number} created.";
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();
        ViewData["Title"] = $"Edit — {b.BookingNumber}";
        await PopulateLookupsAsync();
        return View("Form", b);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(BookingFormVm vm)
    {
        if (!_tenant.CanEdit(AppModules.Bookings)) return Forbid();
        var existing = await _repo.GetByIdAsync(vm.Id);
        if (existing == null) return NotFound();

        var b = vm.ToBooking();
        b.Id              = vm.Id;
        b.BookingNumber   = existing.BookingNumber;
        b.InvoiceNumber   = existing.InvoiceNumber;
        b.LeadId          = existing.LeadId;
        b.PackageId       = existing.PackageId;
        b.PackageOptionId = existing.PackageOptionId;
        b.OptionName      = existing.OptionName;

        if (!Validate(b))
        {
            await PopulateLookupsAsync();
            return View("Form", b);
        }

        await _repo.UpdateAsync(b);
        TempData["Success"] = "Booking updated.";
        return RedirectToAction(nameof(Details), new { id = b.Id });
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id, [FromServices] IEmailLogRepository emailLogs)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();
        ViewData["Title"] = $"Booking {b.BookingNumber}";
        ViewBag.EmailLogs = (await emailLogs.GetByRelatedAsync("Booking", b.Id, 5)).ToList();
        return View(b);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Bookings)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Booking cancelled.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet("Bookings/{id:int}/voucher")]
    public async Task<IActionResult> Voucher(int id)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();

        ViewBag.Company   = await _companies.GetByIdAsync(_tenant.CompanyId);
        ViewData["Title"] = $"Voucher {b.BookingNumber}";
        // Hotel rows now come from b.Hotels (the snapshot stored on the booking).
        return View("Voucher", b);
    }

    [HttpGet("Bookings/{id:int}/voucher/pdf")]
    public async Task<IActionResult> VoucherPdf(int id, CancellationToken ct)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();

        // ?pdf=1 tells the view to hide the internal toolbar.
        var url = $"{Request.Scheme}://{Request.Host}/Bookings/{id}/voucher?pdf=1";
        var cookieHeader = Request.Headers.Cookie.ToString();
        var bytes = await _pdf.RenderUrlAsPdfAsync(url, ct, cookieHeader);

        var fileName = $"Voucher-{b.BookingNumber.Replace(" ", "_")}.pdf";
        return File(bytes, "application/pdf", fileName);
    }

    [HttpGet("Bookings/{id:int}/invoice")]
    public async Task<IActionResult> Invoice(int id)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        ViewBag.Company       = company;
        ViewBag.BankAccounts  = (await _banks.GetAllAsync())
            .Where(x => x.IsActive)
            .OrderByDescending(x => x.IsDefault)
            .ThenBy(x => x.Id)
            .ToList();
        ViewBag.WhyBookWithUs = PublicPackageService.ParseWhyJson(company?.WhyBookWithUs);
        ViewData["Title"] = $"Invoice {b.InvoiceNumber}";
        return View("Invoice", b);
    }

    [HttpGet("Bookings/{id:int}/invoice/pdf")]
    public async Task<IActionResult> InvoicePdf(int id, CancellationToken ct)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();

        // Render the invoice via headless Chromium for pixel-perfect fidelity.
        // Forward the auth cookie so the [Authorize]-protected /invoice route resolves.
        // ?pdf=1 tells the view to hide the internal toolbar.
        var url = $"{Request.Scheme}://{Request.Host}/Bookings/{id}/invoice?pdf=1";
        var cookieHeader = Request.Headers.Cookie.ToString();
        var bytes = await _pdf.RenderUrlAsPdfAsync(url, ct, cookieHeader);

        var fileName = $"Invoice-{b.InvoiceNumber.Replace(" ", "_")}.pdf";
        return File(bytes, "application/pdf", fileName);
    }

    // ───────────────────── send invoice by email ─────────────────────

    public class SendBookingEmailVm
    {
        public string To { get; set; } = "";
        public string? Cc { get; set; }
        public string Subject { get; set; } = "";
        public string Body { get; set; } = "";
        public bool AttachPdf { get; set; } = true;
    }

    [HttpPost("Bookings/{id:int}/SendEmail"), ValidateAntiForgeryToken]
    public async Task<IActionResult> SendEmail(int id, SendBookingEmailVm vm,
        [FromServices] EmailService emailService,
        [FromServices] IEmailLogRepository emailLogs,
        CancellationToken ct)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (company == null) return NotFound();

        EmailService.Attachment[]? attachments = null;
        string? attachmentName = null;
        if (vm.AttachPdf)
        {
            var url = $"{Request.Scheme}://{Request.Host}/Bookings/{id}/invoice?pdf=1";
            var cookieHeader = Request.Headers.Cookie.ToString();
            try
            {
                var bytes = await _pdf.RenderUrlAsPdfAsync(url, ct, cookieHeader);
                attachmentName = $"Invoice-{b.InvoiceNumber.Replace(" ", "_")}.pdf";
                attachments = new[] { new EmailService.Attachment(attachmentName, bytes) };
            }
            catch (Exception ex)
            {
                return Json(new { success = false, error = $"Couldn't generate invoice PDF: {ex.Message}" });
            }
        }

        var result = await emailService.SendAsync(company, vm.To, vm.Subject ?? "", vm.Body ?? "", attachments, vm.Cc, ct);

        await emailLogs.InsertAsync(new EmailLog
        {
            RelatedType = "Booking",
            RelatedId   = b.Id,
            ToEmail     = vm.To,
            CcEmail     = string.IsNullOrWhiteSpace(vm.Cc) ? null : vm.Cc,
            Subject     = vm.Subject ?? "",
            BodyPreview = TextPreview(vm.Body),
            AttachmentNames = attachmentName,
            Status      = result.Success ? "Sent" : "Failed",
            ErrorMessage = result.ErrorMessage
        });

        return Json(new { success = result.Success, error = result.ErrorMessage });
    }

    private static string? TextPreview(string? html)
    {
        if (string.IsNullOrWhiteSpace(html)) return null;
        var stripped = System.Text.RegularExpressions.Regex.Replace(html, "<[^>]+>", " ");
        stripped = System.Net.WebUtility.HtmlDecode(stripped).Trim();
        return stripped.Length > 1000 ? stripped[..1000] : stripped;
    }

    [HttpPost("Bookings/{id:int}/SendVoucherEmail"), ValidateAntiForgeryToken]
    public async Task<IActionResult> SendVoucherEmail(int id, SendBookingEmailVm vm,
        [FromServices] EmailService emailService,
        [FromServices] IEmailLogRepository emailLogs,
        CancellationToken ct)
    {
        if (!_tenant.CanView(AppModules.Bookings)) return Forbid();
        var b = await _repo.GetByIdAsync(id);
        if (b == null) return NotFound();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (company == null) return NotFound();

        EmailService.Attachment[]? attachments = null;
        string? attachmentName = null;
        if (vm.AttachPdf)
        {
            var url = $"{Request.Scheme}://{Request.Host}/Bookings/{id}/voucher?pdf=1";
            var cookieHeader = Request.Headers.Cookie.ToString();
            try
            {
                var bytes = await _pdf.RenderUrlAsPdfAsync(url, ct, cookieHeader);
                attachmentName = $"Voucher-{b.BookingNumber.Replace(" ", "_")}.pdf";
                attachments = new[] { new EmailService.Attachment(attachmentName, bytes) };
            }
            catch (Exception ex)
            {
                return Json(new { success = false, error = $"Couldn't generate voucher PDF: {ex.Message}" });
            }
        }

        var result = await emailService.SendAsync(company, vm.To, vm.Subject ?? "", vm.Body ?? "", attachments, vm.Cc, ct);

        await emailLogs.InsertAsync(new EmailLog
        {
            RelatedType = "Booking",
            RelatedId   = b.Id,
            ToEmail     = vm.To,
            CcEmail     = string.IsNullOrWhiteSpace(vm.Cc) ? null : vm.Cc,
            Subject     = vm.Subject ?? "",
            BodyPreview = TextPreview(vm.Body),
            AttachmentNames = attachmentName,
            Status      = result.Success ? "Sent" : "Failed",
            ErrorMessage = result.ErrorMessage
        });

        return Json(new { success = result.Success, error = result.ErrorMessage });
    }

    // ───────────────────── helpers ─────────────────────

    private bool Validate(Booking b)
    {
        var ok = true;
        if (string.IsNullOrWhiteSpace(b.CustomerName))
        {
            ModelState.AddModelError(nameof(b.CustomerName), "Customer name is required.");
            ok = false;
        }
        if (b.TotalAmount < 0)
        {
            ModelState.AddModelError(nameof(b.TotalAmount), "Total amount cannot be negative.");
            ok = false;
        }
        return ok;
    }

    private async Task PopulateLookupsAsync()
    {
        ViewBag.Destinations = await _destinations.GetAllAsync();
    }

    // ───────────────── Form view-model ─────────────────
    public class BookingFormVm
    {
        public int Id { get; set; }

        // Linkage — preserved through hidden fields so a booking created from a
        // package option keeps its LeadId/PackageId/OptionName when the form posts.
        public int? LeadId { get; set; }
        public int? PackageId { get; set; }
        public int? PackageOptionId { get; set; }
        public string? OptionName { get; set; }

        public string CustomerName { get; set; } = "";
        public string? CustomerMobile { get; set; }
        public string? CustomerEmail { get; set; }
        public int Adults { get; set; } = 1;
        public int Children { get; set; }
        public int Infants { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int? Days { get; set; }
        public int? Nights { get; set; }
        public int? DestinationId { get; set; }
        public decimal TotalAmount { get; set; }
        public string Currency { get; set; } = "INR";
        public string Status { get; set; } = "Confirmed";
        public string? Notes { get; set; }

        // Parallel arrays for installment rows
        public List<int>?       InstNo            { get; set; }
        public List<decimal>?   InstAmount        { get; set; }
        public List<string>?    InstPaymentMode   { get; set; }
        public List<string>?    InstPaymentStatus { get; set; }
        public List<DateTime?>? InstDueDate       { get; set; }
        public List<DateTime?>? InstReceivedDate  { get; set; }
        public List<string>?    InstRemark        { get; set; }

        public Booking ToBooking()
        {
            var b = new Booking
            {
                Id = Id,
                LeadId = LeadId,
                PackageId = PackageId,
                PackageOptionId = PackageOptionId,
                OptionName = OptionName,
                CustomerName  = (CustomerName ?? "").Trim(),
                CustomerMobile = CustomerMobile, CustomerEmail = CustomerEmail,
                Adults = Adults, Children = Children, Infants = Infants,
                StartDate = StartDate, EndDate = EndDate, Days = Days, Nights = Nights,
                DestinationId = DestinationId,
                TotalAmount = TotalAmount,
                Currency = string.IsNullOrWhiteSpace(Currency) ? "INR" : Currency,
                Status = string.IsNullOrWhiteSpace(Status) ? "Confirmed" : Status,
                Notes = Notes
            };

            int count = InstAmount?.Count ?? 0;
            for (int i = 0; i < count; i++)
            {
                var amt = InstAmount![i];
                var mode = InstPaymentMode != null && i < InstPaymentMode.Count ? InstPaymentMode[i] : null;
                if (amt <= 0 && string.IsNullOrWhiteSpace(mode)) continue;

                b.Installments.Add(new BookingInstallment
                {
                    InstallmentNo = InstNo != null && i < InstNo.Count && InstNo[i] > 0 ? InstNo[i] : i + 1,
                    Amount        = amt,
                    PaymentMode   = string.IsNullOrWhiteSpace(mode) ? null : mode,
                    PaymentStatus = InstPaymentStatus != null && i < InstPaymentStatus.Count && !string.IsNullOrWhiteSpace(InstPaymentStatus[i])
                                    ? InstPaymentStatus[i] : "Pending",
                    DueDate       = InstDueDate      != null && i < InstDueDate.Count      ? InstDueDate[i]      : null,
                    ReceivedDate  = InstReceivedDate != null && i < InstReceivedDate.Count ? InstReceivedDate[i] : null,
                    Remark        = InstRemark       != null && i < InstRemark.Count       ? InstRemark[i]       : null
                });
            }

            return b;
        }
    }
}

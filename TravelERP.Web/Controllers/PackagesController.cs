using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Core.Constants;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Web.Services;

namespace TravelERP.Web.Controllers;

[Authorize]
public class PackagesController : Controller
{
    private readonly IPackageRepository _repo;
    private readonly ILeadRepository _leads;
    private readonly IDestinationRepository _destinations;
    private readonly IHotelRepository _hotels;
    private readonly IRoomTypeRepository _roomTypes;
    private readonly IMealPlanRepository _mealPlans;
    private readonly ISightseeingRepository _sightseeings;
    private readonly IItineraryRepository _itineraries;
    private readonly ICompanyRepository _companies;
    private readonly ITenantContext _tenant;

    public PackagesController(
        IPackageRepository repo,
        ILeadRepository leads,
        IDestinationRepository destinations,
        IHotelRepository hotels,
        IRoomTypeRepository roomTypes,
        IMealPlanRepository mealPlans,
        ISightseeingRepository sightseeings,
        IItineraryRepository itineraries,
        ICompanyRepository companies,
        ITenantContext tenant)
    {
        _repo = repo;
        _leads = leads;
        _destinations = destinations;
        _hotels = hotels;
        _roomTypes = roomTypes;
        _mealPlans = mealPlans;
        _sightseeings = sightseeings;
        _itineraries = itineraries;
        _companies = companies;
        _tenant = tenant;
    }

    public async Task<IActionResult> Index(string? search, int page = 1, int pageSize = 20)
    {
        if (!_tenant.CanView(AppModules.Packages)) return Forbid();
        ViewData["Title"] = "Packages";
        var paged = await _repo.GetPagedAsync(search, page, pageSize);
        ViewBag.Search = search;
        return View(paged);
    }

    [HttpGet]
    public async Task<IActionResult> Create(int? leadId)
    {
        if (!_tenant.CanAdd(AppModules.Packages)) return Forbid();
        ViewData["Title"] = leadId.HasValue ? "Create Package from Lead" : "Create Package";
        await PopulateLookupsAsync();

        var pkg = new Package
        {
            CustomerName = "",
            Adults = 1,
            PriceMode = "Total",
            Currency = "INR",
            Options =
            [
                new PackageOption { OptionName = "Option 1", DisplayOrder = 0, IsRecommended = true }
            ]
        };

        if (leadId.HasValue)
        {
            var lead = await _leads.GetByIdAsync(leadId.Value);
            if (lead == null) return NotFound();
            pkg.LeadId         = lead.Id;
            pkg.CustomerName   = lead.Name;
            pkg.CustomerMobile = lead.Mobile;
            pkg.CustomerEmail  = lead.Email;
            pkg.DestinationId  = lead.DestinationId;
            pkg.Adults         = lead.Adults;
            pkg.Children       = lead.Children;
            pkg.Infants        = lead.Infants;
            pkg.Days           = lead.Days;
            pkg.Nights         = lead.Days.HasValue ? lead.Days - 1 : null;
            pkg.StartDate      = lead.TravelingDate;
            pkg.Title          = $"{(lead.DestinationName ?? "Tour")} Package - {lead.Name}";
        }

        return View("Builder", pkg);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(PackageFormVm vm)
    {
        if (!_tenant.CanAdd(AppModules.Packages)) return Forbid();
        var pkg = vm.ToPackage();
        if (!Validate(pkg))
        {
            await PopulateLookupsAsync();
            return View("Builder", pkg);
        }

        var (id, number) = await _repo.InsertAsync(pkg);
        TempData["Success"] = $"Package {number} created.";
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        if (!_tenant.CanEdit(AppModules.Packages)) return Forbid();
        var pkg = await _repo.GetByIdAsync(id);
        if (pkg == null) return NotFound();
        ViewData["Title"] = $"Edit — {pkg.PackageNumber}";
        await PopulateLookupsAsync();
        return View("Builder", pkg);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(PackageFormVm vm)
    {
        if (!_tenant.CanEdit(AppModules.Packages)) return Forbid();
        var existing = await _repo.GetByIdAsync(vm.Id);
        if (existing == null) return NotFound();

        var pkg = vm.ToPackage();
        pkg.Id = vm.Id;
        pkg.PackageNumber = existing.PackageNumber;
        pkg.LeadId = existing.LeadId;

        if (!Validate(pkg))
        {
            await PopulateLookupsAsync();
            return View("Builder", pkg);
        }

        await _repo.UpdateAsync(pkg);
        TempData["Success"] = "Package updated.";
        return RedirectToAction(nameof(Details), new { id = pkg.Id });
    }

    [HttpGet]
    public async Task<IActionResult> Details(int id,
        [FromServices] IBookingRepository bookings,
        [FromServices] IEmailLogRepository emailLogs)
    {
        if (!_tenant.CanView(AppModules.Packages)) return Forbid();
        var pkg = await _repo.GetByIdAsync(id);
        if (pkg == null) return NotFound();
        ViewData["Title"] = $"Package {pkg.PackageNumber}";

        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        ViewBag.CompanySlug = company?.Slug ?? "";

        if (pkg.LeadId.HasValue)
        {
            var leadBookings = (await bookings.GetByLeadAsync(pkg.LeadId.Value)).ToList();
            ViewBag.ExistingBooking = leadBookings.FirstOrDefault(b => b.PackageId == pkg.Id)
                                   ?? leadBookings.FirstOrDefault();
        }

        ViewBag.EmailLogs = (await emailLogs.GetByRelatedAsync("Package", pkg.Id, 5)).ToList();
        return View(pkg);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete(int id)
    {
        if (!_tenant.CanDelete(AppModules.Packages)) return Forbid();
        await _repo.DeleteAsync(id);
        TempData["Success"] = "Package deactivated.";
        return RedirectToAction(nameof(Index));
    }

    // ───────────────────── send quote by email ─────────────────────

    public class SendEmailVm
    {
        public int Id { get; set; }
        public string To { get; set; } = "";
        public string? Cc { get; set; }
        public string Subject { get; set; } = "";
        public string Body { get; set; } = "";
        public bool AttachPdf { get; set; } = true;
    }

    [HttpPost("Packages/{id:int}/SendEmail"), ValidateAntiForgeryToken]
    public async Task<IActionResult> SendEmail(int id, SendEmailVm vm,
        [FromServices] EmailService emailService,
        [FromServices] PdfService pdfService,
        [FromServices] IEmailLogRepository emailLogs,
        CancellationToken ct)
    {
        if (!_tenant.CanView(AppModules.Packages)) return Forbid();
        var pkg = await _repo.GetByIdAsync(id);
        if (pkg == null) return NotFound();
        var company = await _companies.GetByIdAsync(_tenant.CompanyId);
        if (company == null) return NotFound();

        // Generate the public-quote PDF (same engine the customer would download).
        EmailService.Attachment[]? attachments = null;
        string? attachmentName = null;
        if (vm.AttachPdf && !string.IsNullOrEmpty(pkg.ShareToken))
        {
            var url = $"{Request.Scheme}://{Request.Host}/p/{company.Slug}/{pkg.ShareToken}";
            try
            {
                var bytes = await pdfService.RenderUrlAsPdfAsync(url, ct);
                attachmentName = $"Quote-{pkg.PackageNumber.Replace(" ", "_")}.pdf";
                attachments = new[] { new EmailService.Attachment(attachmentName, bytes) };
            }
            catch (Exception ex)
            {
                return Json(new { success = false, error = $"Couldn't generate the PDF: {ex.Message}" });
            }
        }

        var result = await emailService.SendAsync(company, vm.To, vm.Subject ?? "", vm.Body ?? "", attachments, vm.Cc, ct);

        // Log every send attempt — both successes and failures.
        await emailLogs.InsertAsync(new EmailLog
        {
            RelatedType = "Package",
            RelatedId   = pkg.Id,
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

    // ───────────────────── helpers ─────────────────────

    private bool Validate(Package pkg)
    {
        var ok = true;
        if (string.IsNullOrWhiteSpace(pkg.Title))
        {
            ModelState.AddModelError(nameof(pkg.Title), "Title is required.");
            ok = false;
        }
        if (string.IsNullOrWhiteSpace(pkg.CustomerName))
        {
            ModelState.AddModelError(nameof(pkg.CustomerName), "Customer name is required.");
            ok = false;
        }
        if (!pkg.Options.Any(o => !string.IsNullOrWhiteSpace(o.OptionName)))
        {
            ModelState.AddModelError("", "At least one option is required.");
            ok = false;
        }
        return ok;
    }

    private async Task PopulateLookupsAsync()
    {
        ViewBag.Destinations = await _destinations.GetAllAsync();
        ViewBag.Hotels       = await _hotels.GetAllAsync();
        ViewBag.RoomTypes    = await _roomTypes.GetAllAsync();
        ViewBag.MealPlans    = await _mealPlans.GetAllAsync();
        ViewBag.Sightseeings = await _sightseeings.GetAllAsync();
        ViewBag.Itineraries  = await _itineraries.GetAllAsync();
    }

    // ───────────────────── form view-model ─────────────────────
    // The builder posts a flat structure with parallel arrays for options
    // and a JSON blob per option for the hotel rows.

    public class PackageFormVm
    {
        public int Id { get; set; }
        public int? LeadId { get; set; }
        public string Title { get; set; } = "";
        public int? DestinationId { get; set; }
        public string CustomerName { get; set; } = "";
        public string? CustomerMobile { get; set; }
        public string? CustomerEmail { get; set; }
        public int Adults { get; set; } = 1;
        public int Children { get; set; }
        public int Infants { get; set; }
        public int? Days { get; set; }
        public int? Nights { get; set; }
        public DateTime? StartDate { get; set; }
        public string PriceMode { get; set; } = "Total";
        public string Currency { get; set; } = "INR";
        public string? FlightDetails { get; set; }
        public string? Inclusions { get; set; }
        public string? Exclusions { get; set; }
        public string? Notes { get; set; }

        // Parallel arrays — index N = option N
        public List<string>?  OptionNames     { get; set; }
        public List<decimal>? OptionLand      { get; set; }
        public List<decimal>? OptionFlight    { get; set; }
        public List<decimal>? OptionFinal     { get; set; }
        public List<bool>?    OptionRecommend { get; set; }
        public List<string>?  OptionNotes     { get; set; }

        // Hotels per option, encoded as JSON to keep the form simple
        public List<string>? OptionHotelsJson { get; set; }

        // Itinerary days encoded as a single JSON blob
        public string? ItineraryDaysJson { get; set; }

        public Package ToPackage()
        {
            var p = new Package
            {
                Id = Id, LeadId = LeadId,
                Title = (Title ?? "").Trim(),
                DestinationId = DestinationId,
                CustomerName  = (CustomerName ?? "").Trim(),
                CustomerMobile = CustomerMobile, CustomerEmail = CustomerEmail,
                Adults = Adults, Children = Children, Infants = Infants,
                Days = Days, Nights = Nights, StartDate = StartDate,
                PriceMode = string.IsNullOrWhiteSpace(PriceMode) ? "Total" : PriceMode,
                Currency = string.IsNullOrWhiteSpace(Currency) ? "INR" : Currency,
                FlightDetails = FlightDetails, Inclusions = Inclusions, Exclusions = Exclusions,
                Notes = Notes
            };

            var count = OptionNames?.Count ?? 0;
            for (int i = 0; i < count; i++)
            {
                var name = OptionNames![i];
                if (string.IsNullOrWhiteSpace(name)) continue;
                var opt = new PackageOption
                {
                    OptionName    = name.Trim(),
                    DisplayOrder  = i,
                    LandPrice     = OptionLand     != null && i < OptionLand.Count     ? OptionLand[i]     : 0,
                    FlightPrice   = OptionFlight   != null && i < OptionFlight.Count   ? OptionFlight[i]   : 0,
                    FinalPrice    = OptionFinal    != null && i < OptionFinal.Count    ? OptionFinal[i]    : 0,
                    IsRecommended = OptionRecommend!= null && i < OptionRecommend.Count&& OptionRecommend[i],
                    Notes         = OptionNotes    != null && i < OptionNotes.Count    ? OptionNotes[i]    : null
                };

                if (OptionHotelsJson != null && i < OptionHotelsJson.Count
                    && !string.IsNullOrWhiteSpace(OptionHotelsJson[i]))
                {
                    try
                    {
                        var hotels = System.Text.Json.JsonSerializer.Deserialize<List<HotelRowDto>>(
                            OptionHotelsJson[i],
                            new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                        if (hotels != null)
                        {
                            opt.Hotels = hotels.Select(h => new PackageOptionHotel
                            {
                                Nights     = h.Nights <= 0 ? 1 : h.Nights,
                                HotelId    = h.HotelId,
                                RoomTypeId = h.RoomTypeId,
                                MealPlanId = h.MealPlanId,
                                OtherText  = string.IsNullOrWhiteSpace(h.OtherText) ? null : h.OtherText.Trim(),
                                Rooms      = h.Rooms <= 0 ? 1 : h.Rooms,
                                ExtraBeds  = h.ExtraBeds < 0 ? 0 : h.ExtraBeds,
                                HotelCnfNo = string.IsNullOrWhiteSpace(h.HotelCnfNo) ? null : h.HotelCnfNo.Trim()
                            }).ToList();
                        }
                    }
                    catch { /* ignore malformed JSON */ }
                }

                p.Options.Add(opt);
            }

            // Itinerary days
            if (!string.IsNullOrWhiteSpace(ItineraryDaysJson))
            {
                try
                {
                    var days = System.Text.Json.JsonSerializer.Deserialize<List<DayDto>>(
                        ItineraryDaysJson,
                        new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (days != null)
                    {
                        int n = 1;
                        foreach (var d in days)
                        {
                            p.ItineraryDays.Add(new PackageDay
                            {
                                DayNumber      = n++,
                                Title          = string.IsNullOrWhiteSpace(d.Title) ? $"Day {n - 1}" : d.Title.Trim(),
                                Description    = d.Description,
                                SightseeingIds = d.SightseeingIds ?? []
                            });
                        }
                    }
                }
                catch { /* ignore malformed JSON */ }
            }

            return p;
        }

        public class HotelRowDto
        {
            public int Nights { get; set; } = 1;
            public int? HotelId { get; set; }
            public int? RoomTypeId { get; set; }
            public int? MealPlanId { get; set; }
            public string? OtherText { get; set; }
            public int Rooms { get; set; } = 1;
            public int ExtraBeds { get; set; }
            public string? HotelCnfNo { get; set; }
        }

        public class DayDto
        {
            public string? Title { get; set; }
            public string? Description { get; set; }
            public List<int>? SightseeingIds { get; set; }
        }
    }
}

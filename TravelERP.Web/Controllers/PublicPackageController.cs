using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TravelERP.Web.Services;

namespace TravelERP.Web.Controllers;

[AllowAnonymous]
[Route("p")]
public class PublicPackageController : Controller
{
    private readonly PublicPackageService _service;
    private readonly PdfService _pdf;

    public PublicPackageController(PublicPackageService service, PdfService pdf)
    {
        _service = service;
        _pdf = pdf;
    }

    [HttpGet("{slug}/{token}")]
    public async Task<IActionResult> View(string slug, string token)
    {
        var result = await _service.GetByShareTokenAsync(slug, token);
        if (result == null) return NotFound();

        ViewData["Title"] = result.Package.Title;
        ViewBag.Company       = result.Company;
        ViewBag.Agent         = result.Agent;
        ViewBag.GreetingHtml  = result.GreetingHtml;
        ViewBag.WhyBookWithUs = result.WhyBookWithUs;
        ViewBag.BankAccounts  = result.BankAccounts;
        ViewBag.GoogleReviews = result.GoogleReviews;
        return View("PackageView", result.Package);
    }

    [HttpGet("{slug}/{token}/pdf")]
    public async Task<IActionResult> Pdf(string slug, string token, CancellationToken ct)
    {
        var result = await _service.GetByShareTokenAsync(slug, token);
        if (result == null) return NotFound();

        var url = $"{Request.Scheme}://{Request.Host}/p/{slug}/{token}";
        var bytes = await _pdf.RenderUrlAsPdfAsync(url, ct);

        var safeNumber = result.Package.PackageNumber.Replace(" ", "_");
        var fileName = $"Quote-{safeNumber}.pdf";
        return File(bytes, "application/pdf", fileName);
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TravelERP.Web.Controllers;

[Authorize]
[Route("[controller]")]
public class FinanceController : Controller
{
    [HttpGet("Invoices")]
    public IActionResult Invoices() => View();
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TravelERP.Web.Controllers;

[Authorize]
[Route("[controller]")]
public class HRController : Controller
{
    [HttpGet("Employees")]
    public IActionResult Employees() => View();
}

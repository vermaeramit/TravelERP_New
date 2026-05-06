using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TravelERP.Web.Controllers;

[Authorize]
public class ReportsController : Controller
{
    public IActionResult Index() => View();
}

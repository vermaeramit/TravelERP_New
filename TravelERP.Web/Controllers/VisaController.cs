using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TravelERP.Web.Controllers;

[Authorize]
public class VisaController : Controller
{
    public IActionResult Index() => View();
}

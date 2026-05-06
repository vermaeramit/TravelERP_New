using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TravelERP.Web.Controllers;

[Authorize]
public class CustomersController : Controller
{
    public IActionResult Index() => View();
}

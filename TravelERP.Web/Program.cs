using Microsoft.AspNetCore.Authentication.Cookies;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;
using TravelERP.Infrastructure.Repositories;
using TravelERP.Web.Services;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// SERVICES
// ============================================================
builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor();

// DB connection factory (singleton — holds the connection string)
var masterConnStr = builder.Configuration.GetConnectionString("MasterConnection")!;
builder.Services.AddSingleton(new DbConnectionFactory(masterConnStr));

// Tenant context (scoped — one per request, reads from cookie claims)
builder.Services.AddScoped<ITenantContext, TenantContext>();

// Tenant DB provisioning
builder.Services.AddScoped<TenantDbProvisioningService>();

// Master repositories
builder.Services.AddScoped<ICompanyRepository, CompanyRepository>();
builder.Services.AddScoped<IUserRepository, UserRepository>();

// Tenant repositories
builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();
builder.Services.AddScoped<IPackageRepository, PackageRepository>();
builder.Services.AddScoped<IBookingRepository, BookingRepository>();
builder.Services.AddScoped<IInvoiceRepository, InvoiceRepository>();
builder.Services.AddScoped<IEmployeeRepository, EmployeeRepository>();
builder.Services.AddScoped<ISupplierRepository, SupplierRepository>();
builder.Services.AddScoped<IVisaRepository, VisaRepository>();
builder.Services.AddScoped<IDashboardRepository, DashboardRepository>();

// Cookie authentication
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/login";
        options.LogoutPath = "/logout";
        options.AccessDeniedPath = "/login";
        options.ExpireTimeSpan = TimeSpan.FromHours(12);
        options.SlidingExpiration = true;
        options.Cookie.Name = "TravelERP.Auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    });

builder.Services.AddAuthorization();

// Session (for flash messages fallback)
builder.Services.AddSession(o => { o.IdleTimeout = TimeSpan.FromMinutes(30); o.Cookie.HttpOnly = true; });

var app = builder.Build();

// ============================================================
// MIDDLEWARE PIPELINE
// ============================================================
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}
else
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

// ============================================================
// ROUTES
// ============================================================
app.MapControllerRoute("areas", "{area:exists}/{controller=Dashboard}/{action=Index}/{id?}");
app.MapControllerRoute("default", "{controller=Dashboard}/{action=Index}/{id?}");

// Redirect root to dashboard (or login)
app.MapGet("/", ctx =>
{
    ctx.Response.Redirect(ctx.User.Identity?.IsAuthenticated == true ? "/Dashboard" : "/login");
    return Task.CompletedTask;
});

app.Run();

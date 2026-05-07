using PuppeteerSharp;
using PuppeteerSharp.Media;

namespace TravelERP.Web.Services;

/// <summary>
/// Generates PDFs by driving a single cached headless Chromium instance via PuppeteerSharp.
/// Registered as a singleton so we don't pay the Chromium boot cost (~500 ms) on every request.
/// </summary>
public sealed class PdfService : IAsyncDisposable
{
    private readonly ILogger<PdfService> _log;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private IBrowser? _browser;
    private bool _chromiumDownloaded;

    public PdfService(ILogger<PdfService> log) => _log = log;

    public async Task<byte[]> RenderUrlAsPdfAsync(string url, CancellationToken ct = default, string? cookieHeader = null)
    {
        var browser = await GetBrowserAsync();
        await using var page = await browser.NewPageAsync();

        // Forward the caller's auth cookie so [Authorize]-protected pages (like the
        // Invoice view) resolve when Chromium fetches them.
        if (!string.IsNullOrWhiteSpace(cookieHeader))
        {
            await page.SetExtraHttpHeadersAsync(new Dictionary<string, string>
            {
                ["Cookie"] = cookieHeader
            });
        }

        // Use the SCREEN media so colors, gradients and rounded cards render exactly
        // as on screen, not the stripped-down @media print CSS.
        await page.EmulateMediaTypeAsync(MediaType.Screen);
        await page.SetViewportAsync(new ViewPortOptions { Width = 1180, Height = 1600 });

        var nav = new NavigationOptions
        {
            WaitUntil = [WaitUntilNavigation.Networkidle0],
            Timeout   = 30_000
        };
        await page.GoToAsync(url, nav);

        return await page.PdfDataAsync(new PdfOptions
        {
            Format          = PaperFormat.A4,
            PrintBackground = true,
            PreferCSSPageSize = false,
            MarginOptions = new MarginOptions
            {
                Top    = "8mm",
                Bottom = "8mm",
                Left   = "0mm",
                Right  = "0mm"
            }
        });
    }

    private async Task<IBrowser> GetBrowserAsync()
    {
        if (_browser is { IsConnected: true }) return _browser;

        await _gate.WaitAsync();
        try
        {
            if (_browser is { IsConnected: true }) return _browser;

            if (!_chromiumDownloaded)
            {
                _log.LogInformation("PdfService: ensuring Chromium is downloaded (first-run only)…");
                var fetcher = new BrowserFetcher();
                await fetcher.DownloadAsync();
                _chromiumDownloaded = true;
            }

            _log.LogInformation("PdfService: launching headless Chromium");
            _browser = await Puppeteer.LaunchAsync(new LaunchOptions
            {
                Headless = true,
                Args     = ["--no-sandbox", "--disable-dev-shm-usage"]
            });
            return _browser;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_browser is { IsConnected: true })
        {
            try { await _browser.CloseAsync(); }
            catch { /* shutting down — ignore */ }
        }
        _browser?.Dispose();
        _gate.Dispose();
    }
}

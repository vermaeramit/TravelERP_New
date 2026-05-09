using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;
using TravelERP.Core.Entities.Master;

namespace TravelERP.Web.Services;

/// <summary>
/// Sends emails using each company's per-tenant SMTP credentials. Stateless;
/// callers pass the Company (so the right tenant settings are used).
/// </summary>
public class EmailService
{
    private readonly ILogger<EmailService> _log;

    public EmailService(ILogger<EmailService> log) => _log = log;

    public record Attachment(string FileName, byte[] Content, string MimeType = "application/pdf");
    public record SendResult(bool Success, string? ErrorMessage = null);

    public async Task<SendResult> SendAsync(
        Company company,
        string toEmail,
        string subject,
        string htmlBody,
        IEnumerable<Attachment>? attachments = null,
        string? cc = null,
        CancellationToken ct = default)
    {
        if (!company.IsSmtpConfigured)
            return new SendResult(false, "SMTP is not configured for this company. Configure it in Company Setup → Email Settings.");
        if (string.IsNullOrWhiteSpace(toEmail))
            return new SendResult(false, "Recipient email is required.");

        var msg = new MimeMessage();
        msg.From.Add(new MailboxAddress(
            string.IsNullOrWhiteSpace(company.SmtpFromName) ? company.Name : company.SmtpFromName!,
            company.SmtpFromEmail!));
        foreach (var addr in SplitEmails(toEmail))   msg.To.Add(MailboxAddress.Parse(addr));
        if (!string.IsNullOrWhiteSpace(cc))
            foreach (var addr in SplitEmails(cc))    msg.Cc.Add(MailboxAddress.Parse(addr));

        msg.Subject = subject ?? "(no subject)";

        var builder = new BodyBuilder { HtmlBody = htmlBody ?? "" };
        if (attachments != null)
        {
            foreach (var a in attachments)
            {
                if (a.Content == null || a.Content.Length == 0) continue;
                builder.Attachments.Add(a.FileName, a.Content, ContentType.Parse(a.MimeType));
            }
        }
        msg.Body = builder.ToMessageBody();

        try
        {
            using var smtp = new SmtpClient();
            // SecureSocketOptions.Auto picks the right STARTTLS / SSL based on port + UseTls.
            var secure = company.SmtpUseTls
                ? (company.SmtpPort == 465 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTlsWhenAvailable)
                : SecureSocketOptions.None;

            await smtp.ConnectAsync(company.SmtpHost!, company.SmtpPort ?? 587, secure, ct);
            if (!string.IsNullOrWhiteSpace(company.SmtpUsername))
                await smtp.AuthenticateAsync(company.SmtpUsername, company.SmtpPassword ?? "", ct);
            await smtp.SendAsync(msg, ct);
            await smtp.DisconnectAsync(true, ct);

            return new SendResult(true);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "EmailService: send failed to {to}", toEmail);
            // Trim the message — SMTP servers often return novel-length error reports.
            var err = ex.Message.Length > 400 ? ex.Message[..400] + "…" : ex.Message;
            return new SendResult(false, err);
        }
    }

    private static IEnumerable<string> SplitEmails(string raw) =>
        raw.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

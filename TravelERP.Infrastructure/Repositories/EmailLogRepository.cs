using System.Data;
using Dapper;
using TravelERP.Core.Entities.Tenant;
using TravelERP.Core.Interfaces;
using TravelERP.Infrastructure.Data;

namespace TravelERP.Infrastructure.Repositories;

public class EmailLogRepository : IEmailLogRepository
{
    private readonly DbConnectionFactory _factory;
    private readonly ITenantContext _tenant;

    public EmailLogRepository(DbConnectionFactory factory, ITenantContext tenant)
    {
        _factory = factory;
        _tenant = tenant;
    }

    public async Task<int> InsertAsync(EmailLog log)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.ExecuteAsync(
            "sp_EmailLog_Insert",
            new
            {
                DatabaseName = _tenant.DatabaseName,
                log.RelatedType,
                log.RelatedId,
                log.ToEmail,
                log.CcEmail,
                log.Subject,
                log.BodyPreview,
                log.AttachmentNames,
                log.Status,
                log.ErrorMessage,
                SentBy = _tenant.UserId
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<EmailLog>> GetByRelatedAsync(string relatedType, int relatedId, int top = 10)
    {
        using var conn = _factory.CreateMasterConnection();
        return await conn.QueryAsync<EmailLog>(
            "sp_EmailLog_GetByRelated",
            new { DatabaseName = _tenant.DatabaseName, RelatedType = relatedType, RelatedId = relatedId, Top = top },
            commandType: CommandType.StoredProcedure);
    }
}

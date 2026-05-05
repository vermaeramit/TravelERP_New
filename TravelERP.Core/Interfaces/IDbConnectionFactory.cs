using System.Data;

namespace TravelERP.Core.Interfaces;

public interface IDbConnectionFactory
{
    IDbConnection CreateMasterConnection();
    IDbConnection CreateTenantConnection(string databaseName);
}

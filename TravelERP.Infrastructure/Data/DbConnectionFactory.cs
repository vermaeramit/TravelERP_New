using System.Data;
using Microsoft.Data.SqlClient;
using TravelERP.Core.Interfaces;

namespace TravelERP.Infrastructure.Data;

public class DbConnectionFactory : IDbConnectionFactory
{
    private readonly string _masterConnectionString;
    private readonly string _serverConnectionString;

    public DbConnectionFactory(string masterConnectionString)
    {
        _masterConnectionString = masterConnectionString;
        var builder = new SqlConnectionStringBuilder(masterConnectionString);
        builder.InitialCatalog = string.Empty;
        _serverConnectionString = builder.ConnectionString;
    }

    public IDbConnection CreateMasterConnection()
    {
        return new SqlConnection(_masterConnectionString);
    }

    public IDbConnection CreateTenantConnection(string databaseName)
    {
        var builder = new SqlConnectionStringBuilder(_masterConnectionString)
        {
            InitialCatalog = databaseName
        };
        return new SqlConnection(builder.ConnectionString);
    }

    public IDbConnection CreateServerConnection()
    {
        return new SqlConnection(_serverConnectionString);
    }
}

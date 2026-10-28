using Microsoft.Extensions.Configuration;
using Na.Application;
using Oracle.ManagedDataAccess.Client;

namespace Na.Infrastructure.Database;

public sealed class OracleExecutor(IConfiguration configuration)
{
    private readonly string _connectionString =
        configuration.GetConnectionString("Oracle") is { Length: > 0 } cs
            ? cs
            : throw new InvalidOperationException("Missing ConnectionStrings:Oracle configuration.");

    public async Task<T> InTransactionAsync<T>(
        Func<OracleConnection, Task<T>> work, CancellationToken ct)
    {
        try
        {
            await using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync(ct);
            await using var transaction = connection.BeginTransaction();
            var result = await work(connection);
            await transaction.CommitAsync(ct);
            return result;
        }
        catch (OracleException ex) when (OracleErrorTranslator.TryTranslate(ex) is { } translated)
        {
            throw translated;
        }
    }

    public static OracleCommand Procedure(OracleConnection connection, string name) =>
        new(name, connection) { CommandType = System.Data.CommandType.StoredProcedure, BindByName = true };
}

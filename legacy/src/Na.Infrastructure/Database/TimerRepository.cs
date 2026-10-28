using System.Data;
using Na.Application.Abstractions;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Na.Infrastructure.Database;

public sealed class TimerRepository(OracleExecutor db) : ITimerRepository
{
    public Task<int> FireDueAsync(CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_TIMERS.FN_FIRE_DUE");
            var result = new OracleParameter("result", OracleDbType.Decimal) { Direction = ParameterDirection.ReturnValue };
            command.Parameters.Add(result);
            await command.ExecuteNonQueryAsync(ct);
            return ((OracleDecimal)result.Value).ToInt32();
        }, ct);
}

using System.Data;
using System.Text.Json;
using Na.Application;
using Na.Application.Abstractions;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Na.Infrastructure.Database;

public sealed class OutboxRepository(OracleExecutor db) : IOutboxRepository
{
    public Task<OutboxMessage?> ClaimNextAsync(CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_OUTBOX.PR_CLAIM_NEXT");
            var id = Out("p_id", OracleDbType.Decimal);
            var activationId = Out("p_activation_id", OracleDbType.Decimal);
            var code = Out("p_notification_code", OracleDbType.Varchar2, 40);
            var audience = Out("p_audience", OracleDbType.Varchar2, 10);
            var channel = Out("p_channel", OracleDbType.Varchar2, 10);
            var payload = Out("p_payload", OracleDbType.Varchar2, 1000);
            command.Parameters.AddRange(new[] { id, activationId, code, audience, channel, payload });
            await command.ExecuteNonQueryAsync(ct);

            if (((OracleDecimal)id.Value).IsNull)
            {
                return null;
            }

            using var json = JsonDocument.Parse(payload.Value.ToString()!);
            return new OutboxMessage(
                Id: ((OracleDecimal)id.Value).ToInt64(),
                ActivationId: ((OracleDecimal)activationId.Value).ToInt64(),
                Msisdn: json.RootElement.GetProperty("msisdn").GetString()!,
                NotificationCode: code.Value.ToString()!,
                Audience: Enum.Parse<NotificationAudience>(audience.Value.ToString()!, ignoreCase: true),
                Channel: channel.Value.ToString()!);
        }, ct);

    public Task MarkPublishedAsync(long id, CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_OUTBOX.PR_MARK_PUBLISHED");
            command.Parameters.Add("p_id", OracleDbType.Int64).Value = id;
            await command.ExecuteNonQueryAsync(ct);
            return true;
        }, ct);

    public Task MarkFailedAsync(long id, string error, CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_OUTBOX.PR_MARK_FAILED");
            command.Parameters.Add("p_id", OracleDbType.Int64).Value = id;
            command.Parameters.Add("p_error", OracleDbType.Varchar2).Value = error;
            await command.ExecuteNonQueryAsync(ct);
            return true;
        }, ct);

    private static OracleParameter Out(string name, OracleDbType type, int size = 0) =>
        new(name, type, size, null, ParameterDirection.Output);
}

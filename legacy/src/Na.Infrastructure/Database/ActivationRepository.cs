using System.Data;
using Na.Application;
using Na.Application.Abstractions;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace Na.Infrastructure.Database;

public sealed class ActivationRepository(OracleExecutor db) : IActivationRepository
{
    public Task<long> SubmitAsync(SubmitActivationRequest request, CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_ACTIVATIONS.FN_SUBMIT");
            var result = new OracleParameter("result", OracleDbType.Decimal) { Direction = ParameterDirection.ReturnValue };
            command.Parameters.Add(result);
            command.Parameters.Add("p_msisdn", OracleDbType.Varchar2).Value = (object?)request.Msisdn ?? DBNull.Value;
            command.Parameters.Add("p_customer_id", OracleDbType.Varchar2).Value = (object?)request.CustomerId ?? DBNull.Value;
            command.Parameters.Add("p_customer_type", OracleDbType.Varchar2).Value = (object?)request.CustomerType ?? DBNull.Value;
            command.Parameters.Add("p_id_verified", OracleDbType.Varchar2).Value =
                request.IdVerified is { } verified ? (verified ? "Y" : "N") : DBNull.Value;
            command.Parameters.Add("p_plan_code", OracleDbType.Varchar2).Value = (object?)request.PlanCode ?? DBNull.Value;

            await command.ExecuteNonQueryAsync(ct);
            return ((OracleDecimal)result.Value).ToInt64();
        }, ct);

    public Task RaiseEventAsync(long activationId, string eventType, string? context, CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_ACTIVATIONS.PR_RAISE_EVENT");
            command.Parameters.Add("p_activation_id", OracleDbType.Int64).Value = activationId;
            command.Parameters.Add("p_event_type", OracleDbType.Varchar2).Value = eventType;
            command.Parameters.Add("p_context", OracleDbType.Varchar2).Value = (object?)context ?? DBNull.Value;
            await command.ExecuteNonQueryAsync(ct);
            return true;
        }, ct);

    public Task<Activation> GetAsync(long activationId, CancellationToken ct) =>
        db.InTransactionAsync(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_ACTIVATIONS.PR_GET");
            command.Parameters.Add("p_activation_id", OracleDbType.Int64).Value = activationId;
            var cursor = new OracleParameter("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            command.Parameters.Add(cursor);
            await command.ExecuteNonQueryAsync(ct);

            await using var reader = ((OracleRefCursor)cursor.Value).GetDataReader();
            if (!await reader.ReadAsync(ct))
            {
                throw new BusinessRuleViolationException(20003, $"Activation {activationId} not found.");
            }

            return new Activation(
                Id: reader.GetInt64(0),
                Msisdn: reader.GetString(1),
                CustomerId: reader.GetString(2),
                CustomerType: reader.GetString(3),
                IdVerified: reader.GetString(4) == "Y",
                PlanCode: reader.GetString(5),
                Status: ActivationStatusNames.Parse(reader.GetString(6)),
                RejectionReasons: SplitList(reader, 7),
                RiskScore: reader.IsDBNull(8) ? null : reader.GetInt32(8),
                RiskFactors: SplitList(reader, 9),
                RiskDecision: reader.IsDBNull(10) ? null : reader.GetString(10),
                Escalated: reader.GetString(11) == "Y",
                CreatedAt: reader.GetFieldValue<DateTimeOffset>(12),
                UpdatedAt: reader.GetFieldValue<DateTimeOffset>(13));
        }, ct);

    public Task<IReadOnlyList<AuditEntry>> GetAuditAsync(long activationId, CancellationToken ct) =>
        db.InTransactionAsync<IReadOnlyList<AuditEntry>>(async connection =>
        {
            await using var command = OracleExecutor.Procedure(connection, "PKG_ACTIVATIONS.PR_GET_AUDIT");
            command.Parameters.Add("p_activation_id", OracleDbType.Int64).Value = activationId;
            var cursor = new OracleParameter("p_cursor", OracleDbType.RefCursor, ParameterDirection.Output);
            command.Parameters.Add(cursor);
            await command.ExecuteNonQueryAsync(ct);

            var entries = new List<AuditEntry>();
            await using var reader = ((OracleRefCursor)cursor.Value).GetDataReader();
            while (await reader.ReadAsync(ct))
            {
                entries.Add(new AuditEntry(
                    EventType: reader.GetString(0),
                    FromStatus: ActivationStatusNames.Parse(reader.GetString(1)),
                    ToStatus: ActivationStatusNames.Parse(reader.GetString(2)),
                    Detail: reader.IsDBNull(3) ? null : reader.GetString(3),
                    OccurredAt: reader.GetFieldValue<DateTimeOffset>(4)));
            }

            return entries;
        }, ct);

    private static string[] SplitList(OracleDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal)
            ? []
            : reader.GetString(ordinal).Split(',', StringSplitOptions.RemoveEmptyEntries);
}

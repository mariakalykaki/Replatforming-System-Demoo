using System.Data;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Na.Application;
using Na.Application.Abstractions;
using Na.Application.Services;
using Na.Infrastructure.Database;
using Oracle.ManagedDataAccess.Client;

namespace Na.IntegrationTests;

internal sealed class TestWorld
{
    private static readonly Random Random = new();
    private readonly string _connectionString = Environment.GetEnvironmentVariable(OracleFactAttribute.EnvironmentVariable)!;

    public ActivationService Activations { get; }
    public StubCarrier Carrier { get; } = new();
    public RecordingCustomerNotifications Customer { get; } = new();
    private readonly OutboxRelayService _relay;
    private readonly TimerSweepService _sweep;

    public TestWorld()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:Oracle"] = _connectionString })
            .Build();
        var executor = new OracleExecutor(config);
        var activationRepo = new ActivationRepository(executor);

        Activations = new ActivationService(activationRepo);
        _relay = new OutboxRelayService(new OutboxRepository(executor), activationRepo, Carrier, Customer,
            NullLogger<OutboxRelayService>.Instance);
        _sweep = new TimerSweepService(new TimerRepository(executor), NullLogger<TimerSweepService>.Instance);
    }


    public async Task<string> NewCustomer(decimal balance = 0, int ageDays = 400)
    {
        var id = "T-" + Guid.NewGuid().ToString("N")[..10];
        await Execute(
            "INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) " +
            "VALUES (:id, 'Test', :balance, SYSTIMESTAMP - NUMTODSINTERVAL(:age, 'DAY'))",
            ("id", id), ("balance", balance), ("age", ageDays));
        return id;
    }

    public async Task<string> NewNumber(string suffix = "01", bool premium = false, string poolStatus = "AVAILABLE")
    {
        var prefix = premium ? "+30699" : "+30690";
        for (var attempt = 0; attempt < 20; attempt++)
        {
            var msisdn = $"{prefix}{Random.Next(0, 100000):D5}{suffix}";
            try
            {
                await Execute("INSERT INTO na_number_pool (msisdn, status) VALUES (:m, :s)", ("m", msisdn), ("s", poolStatus));
                return msisdn;
            }
            catch (OracleException ex) when (ex.Number == 1) {  }
        }
        throw new InvalidOperationException("Could not allocate a unique test number.");
    }

    public Task GiveActiveLines(string customerId, int count) => HistoricRequests(customerId, count, "ACTIVE", "30");

    public Task GiveRecentRequests(string customerId, int count) => HistoricRequests(customerId, count, "CANCELLED", null);

    private Task HistoricRequests(string customerId, int count, string status, string? daysAgo) =>
        Execute(
            "INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) " +
            "SELECT '+30698' || TO_CHAR(DBMS_RANDOM.VALUE(1000000, 9999999), 'FM9999999'), :c, 'POSTPAID', 'Y', 'PRO', :s, " +
            "       SYSTIMESTAMP - " + (daysAgo is null ? "NUMTODSINTERVAL(2, 'HOUR')" : $"NUMTODSINTERVAL({daysAgo}, 'DAY')") +
            "  FROM dual CONNECT BY LEVEL <= :n",
            ("c", customerId), ("s", status), ("n", count));


    public Task<ActivationDetail> Submit(
        string msisdn, string customerId, string customerType = "POSTPAID", bool idVerified = true, string plan = "PRO") =>
        Activations.SubmitAsync(new SubmitActivationRequest(msisdn, customerId, customerType, idVerified, plan), default);

    public async Task DrainOutbox()
    {
        var guard = 0;
        while (await _relay.ProcessNextAsync(default))
        {
            if (++guard > 500) throw new InvalidOperationException("Outbox did not drain.");
        }
    }

    public Task MakeTimerDue(long activationId, string timerCode) =>
        Execute("UPDATE na_timers SET due_at = SYSTIMESTAMP - NUMTODSINTERVAL(1, 'SECOND') " +
                "WHERE activation_id = :id AND timer_code = :code AND status = 'PENDING'",
            ("id", activationId), ("code", timerCode));

    public Task Sweep() => _sweep.SweepAsync(default);


    public async Task<ActivationDetail> Get(long id) => await Activations.GetAsync(id, default);

    public async Task<string> PoolStatus(string msisdn) =>
        (string)(await Scalar("SELECT status FROM na_number_pool WHERE msisdn = :m", ("m", msisdn)))!;

    public async Task<long> PendingTimers(long activationId) =>
        Convert.ToInt64(await Scalar("SELECT COUNT(*) FROM na_timers WHERE activation_id = :id AND status = 'PENDING'", ("id", activationId)));

    public async Task<IReadOnlyList<string>> Notifications(long activationId) =>
        await Column("SELECT notification_code FROM na_outbox WHERE activation_id = :id ORDER BY id", ("id", activationId));

    public static IReadOnlyList<string> Events(ActivationDetail detail) => detail.Audit.Select(a => a.EventType).ToList();


    private async Task Execute(string sql, params (string Name, object Value)[] binds)
    {
        await using var connection = new OracleConnection(_connectionString);
        await connection.OpenAsync();
        await using var command = Command(connection, sql, binds);
        await command.ExecuteNonQueryAsync();
    }

    private async Task<object?> Scalar(string sql, params (string Name, object Value)[] binds)
    {
        await using var connection = new OracleConnection(_connectionString);
        await connection.OpenAsync();
        await using var command = Command(connection, sql, binds);
        return await command.ExecuteScalarAsync();
    }

    private async Task<IReadOnlyList<string>> Column(string sql, params (string Name, object Value)[] binds)
    {
        await using var connection = new OracleConnection(_connectionString);
        await connection.OpenAsync();
        await using var command = Command(connection, sql, binds);
        var values = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) values.Add(reader.GetString(0));
        return values;
    }

    private static OracleCommand Command(OracleConnection connection, string sql, (string Name, object Value)[] binds)
    {
        var command = new OracleCommand(sql, connection) { BindByName = true };
        foreach (var (name, value) in binds) command.Parameters.Add(name, value);
        return command;
    }
}

internal sealed class StubCarrier : ICarrierClient
{
    public List<string> Calls { get; } = [];

    public Task<AllocationResult> AllocateAsync(string msisdn, CancellationToken ct)
    {
        Calls.Add(msisdn);
        return Task.FromResult(msisdn switch
        {
            _ when msisdn.EndsWith("00") => new AllocationResult(false, "Carrier unavailable (504)"),
            _ when msisdn.EndsWith("99") => new AllocationResult(false, "Carrier rejected the number"),
            _ => new AllocationResult(true)
        });
    }
}

internal sealed class RecordingCustomerNotifications : ICustomerNotificationClient
{
    public List<OutboxMessage> Sent { get; } = [];

    public Task SendAsync(OutboxMessage message, CancellationToken ct)
    {
        Sent.Add(message);
        return Task.CompletedTask;
    }
}

using Na.Application;
using Na.Application.Abstractions;

namespace Na.Application.Tests;

internal sealed class FakeOutboxRepository : IOutboxRepository
{
    public Queue<OutboxMessage> Pending { get; } = new();
    public List<long> Published { get; } = [];
    public List<(long Id, string Error)> Failed { get; } = [];

    public Task<OutboxMessage?> ClaimNextAsync(CancellationToken ct) =>
        Task.FromResult(Pending.TryDequeue(out var message) ? message : null);

    public Task MarkPublishedAsync(long id, CancellationToken ct) { Published.Add(id); return Task.CompletedTask; }
    public Task MarkFailedAsync(long id, string error, CancellationToken ct) { Failed.Add((id, error)); return Task.CompletedTask; }
}

internal sealed class FakeActivationRepository : IActivationRepository
{
    public List<(long Id, string Event, string? Context)> RaisedEvents { get; } = [];
    public Exception? RaiseThrows { get; set; }

    public Task<long> SubmitAsync(SubmitActivationRequest request, CancellationToken ct) => Task.FromResult(42L);

    public Task RaiseEventAsync(long activationId, string eventType, string? context, CancellationToken ct)
    {
        if (RaiseThrows is not null) throw RaiseThrows;
        RaisedEvents.Add((activationId, eventType, context));
        return Task.CompletedTask;
    }

    public Task<Activation> GetAsync(long activationId, CancellationToken ct) =>
        Task.FromResult(new Activation(activationId, "+306900000101", "C-1001", "POSTPAID", true, "PRO",
            ActivationStatus.Allocating, [], 0, [], "AUTO_APPROVE", false, DateTimeOffset.UtcNow, DateTimeOffset.UtcNow));

    public Task<IReadOnlyList<AuditEntry>> GetAuditAsync(long activationId, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<AuditEntry>>([]);
}

internal sealed class FakeCarrierClient(AllocationResult result) : ICarrierClient
{
    public List<string> Calls { get; } = [];

    public Task<AllocationResult> AllocateAsync(string msisdn, CancellationToken ct)
    {
        Calls.Add(msisdn);
        return Task.FromResult(result);
    }
}

internal sealed class FakeCustomerNotificationClient : ICustomerNotificationClient
{
    public List<OutboxMessage> Sent { get; } = [];
    public bool Throws { get; set; }

    public Task SendAsync(OutboxMessage message, CancellationToken ct)
    {
        if (Throws) throw new HttpRequestException("gateway down");
        Sent.Add(message);
        return Task.CompletedTask;
    }
}

namespace Na.Application.Abstractions;

public interface IActivationRepository
{
    Task<long> SubmitAsync(SubmitActivationRequest request, CancellationToken ct);
    Task RaiseEventAsync(long activationId, string eventType, string? context, CancellationToken ct);
    Task<Activation> GetAsync(long activationId, CancellationToken ct);
    Task<IReadOnlyList<AuditEntry>> GetAuditAsync(long activationId, CancellationToken ct);
}

public interface IOutboxRepository
{
    Task<OutboxMessage?> ClaimNextAsync(CancellationToken ct);
    Task MarkPublishedAsync(long id, CancellationToken ct);
    Task MarkFailedAsync(long id, string error, CancellationToken ct);
}

public interface ITimerRepository
{
    Task<int> FireDueAsync(CancellationToken ct);
}

public interface ICarrierClient
{
    Task<AllocationResult> AllocateAsync(string msisdn, CancellationToken ct);
}

public interface ICustomerNotificationClient
{
    Task SendAsync(OutboxMessage message, CancellationToken ct);
}

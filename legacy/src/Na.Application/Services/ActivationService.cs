using Na.Application.Abstractions;

namespace Na.Application.Services;

public enum ReviewDecision { Approve, Reject }

public sealed class ActivationService(IActivationRepository repository)
{
    public async Task<ActivationDetail> SubmitAsync(SubmitActivationRequest request, CancellationToken ct)
    {
        var id = await repository.SubmitAsync(request, ct);
        return await GetAsync(id, ct);
    }

    public Task<ActivationDetail> ReviewAsync(long id, ReviewDecision decision, CancellationToken ct) =>
        RaiseAsync(id, decision == ReviewDecision.Approve
            ? ActivationEvents.ReviewApproved
            : ActivationEvents.ReviewRejected, ct);

    public Task<ActivationDetail> ConfirmAsync(long id, CancellationToken ct) =>
        RaiseAsync(id, ActivationEvents.SimConfirmed, ct);

    public Task<ActivationDetail> CancelAsync(long id, CancellationToken ct) =>
        RaiseAsync(id, ActivationEvents.CustomerCancelled, ct);

    public async Task<ActivationDetail> GetAsync(long id, CancellationToken ct) =>
        new(await repository.GetAsync(id, ct), await repository.GetAuditAsync(id, ct));

    private async Task<ActivationDetail> RaiseAsync(long id, string eventType, CancellationToken ct)
    {
        await repository.RaiseEventAsync(id, eventType, null, ct);
        return await GetAsync(id, ct);
    }
}

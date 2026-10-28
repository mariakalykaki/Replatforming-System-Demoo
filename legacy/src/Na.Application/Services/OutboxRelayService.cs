using Microsoft.Extensions.Logging;
using Na.Application.Abstractions;

namespace Na.Application.Services;

public sealed class OutboxRelayService(
    IOutboxRepository outbox,
    IActivationRepository activations,
    ICarrierClient carrier,
    ICustomerNotificationClient customerNotifications,
    ILogger<OutboxRelayService> logger)
{
    public async Task<bool> ProcessNextAsync(CancellationToken ct)
    {
        var message = await outbox.ClaimNextAsync(ct);
        if (message is null)
        {
            return false;
        }

        try
        {
            switch (message.Audience)
            {
                case NotificationAudience.Carrier:
                    await AllocateAsync(message, ct);
                    break;
                case NotificationAudience.Customer:
                    await customerNotifications.SendAsync(message, ct);
                    break;
                case NotificationAudience.Operations:
                    logger.LogWarning("OPS {Notification} for activation {ActivationId} ({Msisdn})",
                        message.NotificationCode, message.ActivationId, message.Msisdn);
                    break;
                default:
                    throw new InvalidOperationException($"Unhandled audience {message.Audience}");
            }

            await outbox.MarkPublishedAsync(message.Id, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogError(ex, "Outbox message {Id} ({Notification}) failed", message.Id, message.NotificationCode);
            await outbox.MarkFailedAsync(message.Id, ex.Message, ct);
        }

        return true;
    }

    private async Task AllocateAsync(OutboxMessage message, CancellationToken ct)
    {
        var result = await carrier.AllocateAsync(message.Msisdn, ct);
        await activations.RaiseEventAsync(
            message.ActivationId,
            result.Succeeded ? ActivationEvents.AllocationSucceeded : ActivationEvents.AllocationFailed,
            result.Reason, ct);
    }
}

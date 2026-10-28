using System.Net.Http.Json;
using Na.Application;
using Na.Application.Abstractions;

namespace Na.Infrastructure.ExternalApis;

public sealed class CustomerNotificationClient(HttpClient http) : ICustomerNotificationClient
{
    public async Task SendAsync(OutboxMessage message, CancellationToken ct)
    {
        using var response = await http.PostAsJsonAsync("notifications/customer", new
        {
            channel = message.Channel,
            notification = message.NotificationCode,
            activationId = message.ActivationId,
            msisdn = message.Msisdn
        }, ct);
        response.EnsureSuccessStatusCode();
    }
}

using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Logging;
using Na.Application;
using Na.Application.Abstractions;

namespace Na.Infrastructure.ExternalApis;

public sealed class CarrierClient(HttpClient http, ILogger<CarrierClient> logger) : ICarrierClient
{
    public async Task<AllocationResult> AllocateAsync(string msisdn, CancellationToken ct)
    {
        try
        {
            using var response = await http.PostAsJsonAsync("carrier/allocate", new { msisdn }, ct);

            if (response.IsSuccessStatusCode)
            {
                return new AllocationResult(true);
            }

            var reason = response.StatusCode == HttpStatusCode.UnprocessableEntity
                ? "Carrier rejected the number"
                : $"Carrier unavailable ({(int)response.StatusCode})";
            return new AllocationResult(false, reason);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException
                                       or Polly.CircuitBreaker.BrokenCircuitException
                                       or Polly.Timeout.TimeoutRejectedException)
        {
            logger.LogWarning(ex, "Carrier allocation for {Msisdn} failed", msisdn);
            return new AllocationResult(false, "Carrier unreachable");
        }
    }
}

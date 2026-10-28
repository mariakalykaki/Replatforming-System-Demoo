using Microsoft.Extensions.Logging;
using Na.Application.Abstractions;

namespace Na.Application.Services;

public sealed class TimerSweepService(ITimerRepository timers, ILogger<TimerSweepService> logger)
{
    public async Task<int> SweepAsync(CancellationToken ct)
    {
        var fired = await timers.FireDueAsync(ct);
        if (fired > 0)
        {
            logger.LogInformation("Fired {Count} due timer(s)", fired);
        }

        return fired;
    }
}

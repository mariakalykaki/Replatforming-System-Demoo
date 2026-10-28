using Microsoft.Extensions.Options;
using Na.Application.Services;

namespace Na.Worker;

public sealed class WorkerOptions
{
    public const string SectionName = "Worker";

    public int OutboxPollSeconds { get; init; } = 2;
    public int TimerSweepSeconds { get; init; } = 5;
}

public sealed class OutboxRelayWorker(
    OutboxRelayService relay, IOptions<WorkerOptions> options, ILogger<OutboxRelayWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.Value.OutboxPollSeconds));
        do
        {
            try
            {
                while (await relay.ProcessNextAsync(stoppingToken)) { }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Outbox relay tick failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}

public sealed class TimerSweepWorker(
    TimerSweepService sweep, IOptions<WorkerOptions> options, ILogger<TimerSweepWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.Value.TimerSweepSeconds));
        do
        {
            try
            {
                await sweep.SweepAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Timer sweep tick failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}

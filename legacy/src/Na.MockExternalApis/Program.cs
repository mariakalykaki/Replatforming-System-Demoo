using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var attempts = new ConcurrentDictionary<string, int>();

app.MapPost("/carrier/allocate", (AllocateRequest request, ILogger<Program> logger) =>
{
    var msisdn = request.Msisdn ?? string.Empty;
    var attempt = attempts.AddOrUpdate(msisdn, 1, (_, n) => n + 1);
    logger.LogInformation("Carrier allocate {Msisdn} attempt {Attempt}", msisdn, attempt);

    if (msisdn.EndsWith("00")) return Results.StatusCode(StatusCodes.Status504GatewayTimeout);
    if (msisdn.EndsWith("99")) return Results.UnprocessableEntity(new { error = "NUMBER_REJECTED" });
    if (msisdn.EndsWith("50") && attempt <= 2) return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
    return Results.Ok(new { msisdn, allocated = true });
});

app.MapPost("/notifications/customer", (CustomerNotification notification, ILogger<Program> logger) =>
{
    logger.LogInformation("{Channel} to customer of activation {ActivationId} ({Msisdn}): {Notification}",
        notification.Channel, notification.ActivationId, notification.Msisdn, notification.Notification);
    return Results.Accepted();
});

app.Run();

internal sealed record AllocateRequest(string? Msisdn);
internal sealed record CustomerNotification(string? Channel, string? Notification, long ActivationId, string? Msisdn);

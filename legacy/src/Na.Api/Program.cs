using System.Text.Json;
using System.Text.Json.Serialization;
using Na.Api;
using Na.Application;
using Na.Application.Services;
using Na.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddNaDatabase();
builder.Services.AddSingleton<ActivationService>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    o.SerializerOptions.Converters.Add(new ActivationStatusConverter());
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseUpper));
});

var app = builder.Build();
app.UseExceptionHandler();

var activations = app.MapGroup("/api/activations");

activations.MapPost("/", async (SubmitActivationRequest request, ActivationService service, CancellationToken ct) =>
{
    var detail = await service.SubmitAsync(request, ct);
    return Results.Created($"/api/activations/{detail.Activation.Id}", detail);
});

activations.MapGet("/{id:long}", async (long id, ActivationService service, CancellationToken ct) =>
    Results.Ok(await service.GetAsync(id, ct)));

activations.MapPost("/{id:long}/review", async (long id, ReviewRequest body, ActivationService service, CancellationToken ct) =>
    Results.Ok(await service.ReviewAsync(id, body.Decision, ct)));

activations.MapPost("/{id:long}/confirm", async (long id, ActivationService service, CancellationToken ct) =>
    Results.Ok(await service.ConfirmAsync(id, ct)));

activations.MapPost("/{id:long}/cancel", async (long id, ActivationService service, CancellationToken ct) =>
    Results.Ok(await service.CancelAsync(id, ct)));

app.Run();

internal sealed record ReviewRequest(ReviewDecision Decision);

using System.Net;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Na.Application.Abstractions;
using Na.Infrastructure;

namespace Na.Application.Tests;

public class CarrierClientTests
{
    private sealed class ScriptedHandler(params HttpStatusCode[] responses) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var status = responses[Math.Min(Calls, responses.Length - 1)];
            Calls++;
            return Task.FromResult(new HttpResponseMessage(status));
        }
    }

    private static ICarrierClient Create(ScriptedHandler handler)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Carrier:BaseUrl"] = "http://carrier.test/",
            ["CustomerNotifications:BaseUrl"] = "http://notify.test/"
        }).Build();

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddNaExternalApis(config);
        services.AddHttpClient<ICarrierClient, Na.Infrastructure.ExternalApis.CarrierClient>()
            .ConfigurePrimaryHttpMessageHandler(() => handler);
        services.Configure<Microsoft.Extensions.Http.Resilience.HttpStandardResilienceOptions>(
            "ICarrierClient-standard", o => o.Retry.Delay = TimeSpan.Zero);

        return services.BuildServiceProvider().GetRequiredService<ICarrierClient>();
    }

    [Fact]
    public async Task TransientFailures_AreRetried_ThenSucceed()
    {
        var handler = new ScriptedHandler(HttpStatusCode.ServiceUnavailable, HttpStatusCode.ServiceUnavailable, HttpStatusCode.OK);

        var result = await Create(handler).AllocateAsync("+306900000150", default);

        Assert.True(result.Succeeded);
        Assert.Equal(3, handler.Calls);
    }

    [Fact]
    public async Task PersistentTimeout_ExhaustsRetries_AndFails()
    {
        var handler = new ScriptedHandler(HttpStatusCode.GatewayTimeout);

        var result = await Create(handler).AllocateAsync("+306900000100", default);

        Assert.False(result.Succeeded);
        Assert.Equal("Carrier unavailable (504)", result.Reason);
        Assert.Equal(4, handler.Calls);
    }

    [Fact]
    public async Task HardRefusal_IsNotRetried()
    {
        var handler = new ScriptedHandler(HttpStatusCode.UnprocessableEntity);

        var result = await Create(handler).AllocateAsync("+306900000199", default);

        Assert.False(result.Succeeded);
        Assert.Equal("Carrier rejected the number", result.Reason);
        Assert.Equal(1, handler.Calls);
    }
}

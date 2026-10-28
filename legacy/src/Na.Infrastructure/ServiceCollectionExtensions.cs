using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Na.Application.Abstractions;
using Na.Infrastructure.Database;
using Na.Infrastructure.ExternalApis;

namespace Na.Infrastructure;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddNaDatabase(this IServiceCollection services)
    {
        services.AddSingleton<OracleExecutor>();
        services.AddSingleton<IActivationRepository, ActivationRepository>();
        services.AddSingleton<IOutboxRepository, OutboxRepository>();
        services.AddSingleton<ITimerRepository, TimerRepository>();
        return services;
    }

    public static IServiceCollection AddNaExternalApis(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CarrierOptions>()
            .Bind(configuration.GetSection(CarrierOptions.SectionName))
            .ValidateDataAnnotations().ValidateOnStart();
        services.AddOptions<CustomerNotificationOptions>()
            .Bind(configuration.GetSection(CustomerNotificationOptions.SectionName))
            .ValidateDataAnnotations().ValidateOnStart();

        services.AddHttpClient<ICarrierClient, CarrierClient>((sp, client) =>
                client.BaseAddress = sp.GetRequiredService<IOptions<CarrierOptions>>().Value.BaseUrl)
            .AddStandardResilienceHandler();
        services.AddHttpClient<ICustomerNotificationClient, CustomerNotificationClient>((sp, client) =>
                client.BaseAddress = sp.GetRequiredService<IOptions<CustomerNotificationOptions>>().Value.BaseUrl)
            .AddStandardResilienceHandler();
        return services;
    }
}

using System.ComponentModel.DataAnnotations;

namespace Na.Infrastructure.ExternalApis;

public sealed class CarrierOptions
{
    public const string SectionName = "Carrier";

    [Required]
    public Uri? BaseUrl { get; init; }
}

public sealed class CustomerNotificationOptions
{
    public const string SectionName = "CustomerNotifications";

    [Required]
    public Uri? BaseUrl { get; init; }
}

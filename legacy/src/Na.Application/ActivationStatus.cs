using System.Text.RegularExpressions;

namespace Na.Application;

public enum ActivationStatus
{
    Requested, Eligible, ManualReview, Allocating, AwaitingActivation,
    Active, Rejected, Expired, Failed, Cancelled
}

public static partial class ActivationStatusNames
{
    public static string ToWireName(this ActivationStatus status) =>
        WordBoundary().Replace(status.ToString(), "_$1").ToUpperInvariant();

    public static ActivationStatus Parse(string wireName) =>
        Enum.Parse<ActivationStatus>(wireName.Replace("_", string.Empty), ignoreCase: true);

    [GeneratedRegex("(?<!^)([A-Z])")]
    private static partial Regex WordBoundary();
}

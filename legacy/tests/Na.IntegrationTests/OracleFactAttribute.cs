[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace Na.IntegrationTests;

public sealed class OracleFactAttribute : FactAttribute
{
    public const string EnvironmentVariable = "ConnectionStrings__Oracle";

    public OracleFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(EnvironmentVariable)))
        {
            Skip = $"Set {EnvironmentVariable} to run against Oracle (see CLAUDE.md).";
        }
    }
}

using Na.Infrastructure.Database;

namespace Na.Application.Tests;

public class MappingTests
{
    [Theory]
    [InlineData(ActivationStatus.Requested, "REQUESTED")]
    [InlineData(ActivationStatus.ManualReview, "MANUAL_REVIEW")]
    [InlineData(ActivationStatus.AwaitingActivation, "AWAITING_ACTIVATION")]
    public void StatusNames_RoundTrip(ActivationStatus status, string wireName)
    {
        Assert.Equal(wireName, status.ToWireName());
        Assert.Equal(status, ActivationStatusNames.Parse(wireName));
    }

    [Fact]
    public void ExtractMessage_StripsOraPrefixAndCallStack()
    {
        var text = "ORA-20010: Event X is not valid.\nORA-06512: at \"NA_APP.PKG\", line 5";
        Assert.Equal("Event X is not valid.", OracleErrorTranslator.ExtractMessage(text));
    }
}

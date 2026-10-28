using Na.Application.Services;

namespace Na.Application.Tests;

public class ActivationServiceTests
{
    private readonly FakeActivationRepository _repository = new();

    [Theory]
    [InlineData(ReviewDecision.Approve, ActivationEvents.ReviewApproved)]
    [InlineData(ReviewDecision.Reject, ActivationEvents.ReviewRejected)]
    public async Task ReviewAsync_RaisesTheMatchingEvent(ReviewDecision decision, string expectedEvent)
    {
        await new ActivationService(_repository).ReviewAsync(42, decision, default);
        Assert.Equal([(42L, expectedEvent, (string?)null)], _repository.RaisedEvents);
    }

    [Fact]
    public async Task ConfirmAsync_RaisesSimConfirmed()
    {
        await new ActivationService(_repository).ConfirmAsync(42, default);
        Assert.Equal(ActivationEvents.SimConfirmed, Assert.Single(_repository.RaisedEvents).Event);
    }

    [Fact]
    public async Task CancelAsync_RaisesCustomerCancelled()
    {
        await new ActivationService(_repository).CancelAsync(42, default);
        Assert.Equal(ActivationEvents.CustomerCancelled, Assert.Single(_repository.RaisedEvents).Event);
    }

    [Fact]
    public async Task SubmitAsync_ReadsBackWhatTheDatabaseDecided()
    {
        var detail = await new ActivationService(_repository)
            .SubmitAsync(new SubmitActivationRequest("+306900000101", "C-1001", "POSTPAID", true, "PRO"), default);

        Assert.Equal(42, detail.Activation.Id);
        Assert.Equal(ActivationStatus.Allocating, detail.Activation.Status);
    }
}

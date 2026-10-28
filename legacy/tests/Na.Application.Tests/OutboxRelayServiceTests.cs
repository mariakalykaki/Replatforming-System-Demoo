using Microsoft.Extensions.Logging.Abstractions;
using Na.Application.Services;

namespace Na.Application.Tests;

public class OutboxRelayServiceTests
{
    private readonly FakeOutboxRepository _outbox = new();
    private readonly FakeActivationRepository _activations = new();
    private readonly FakeCustomerNotificationClient _customer = new();

    private OutboxRelayService Create(AllocationResult carrierResult, out FakeCarrierClient carrier)
    {
        carrier = new FakeCarrierClient(carrierResult);
        return new OutboxRelayService(_outbox, _activations, carrier, _customer,
            NullLogger<OutboxRelayService>.Instance);
    }

    private static OutboxMessage Message(NotificationAudience audience, string code = "X") =>
        new(1, 42, "+306900000101", code, audience, "SMS");

    [Fact]
    public async Task ProcessNextAsync_ReturnsFalse_WhenOutboxEmpty()
    {
        var service = Create(new AllocationResult(true), out _);
        Assert.False(await service.ProcessNextAsync(default));
    }

    [Fact]
    public async Task CarrierSuccess_RaisesAllocationSucceeded_AndMarksPublished()
    {
        var service = Create(new AllocationResult(true), out var carrier);
        _outbox.Pending.Enqueue(Message(NotificationAudience.Carrier, "ALLOCATE_NUMBER"));

        Assert.True(await service.ProcessNextAsync(default));

        Assert.Equal(["+306900000101"], carrier.Calls);
        Assert.Equal([(42L, ActivationEvents.AllocationSucceeded, (string?)null)], _activations.RaisedEvents);
        Assert.Equal([1L], _outbox.Published);
    }

    [Fact]
    public async Task CarrierRefusal_RaisesAllocationFailed_WithReason()
    {
        var service = Create(new AllocationResult(false, "Carrier rejected the number"), out _);
        _outbox.Pending.Enqueue(Message(NotificationAudience.Carrier));

        await service.ProcessNextAsync(default);

        Assert.Equal([(42L, ActivationEvents.AllocationFailed, (string?)"Carrier rejected the number")],
            _activations.RaisedEvents);
        Assert.Equal([1L], _outbox.Published);
    }

    [Fact]
    public async Task CustomerMessage_IsSent_AndMarkedPublished()
    {
        var service = Create(new AllocationResult(true), out _);
        _outbox.Pending.Enqueue(Message(NotificationAudience.Customer));

        await service.ProcessNextAsync(default);

        Assert.Single(_customer.Sent);
        Assert.Equal([1L], _outbox.Published);
    }

    [Fact]
    public async Task DeliveryFailure_MarksFailed_AndDoesNotThrow()
    {
        var service = Create(new AllocationResult(true), out _);
        _customer.Throws = true;
        _outbox.Pending.Enqueue(Message(NotificationAudience.Customer));

        Assert.True(await service.ProcessNextAsync(default));

        Assert.Empty(_outbox.Published);
        Assert.Equal("gateway down", Assert.Single(_outbox.Failed).Error);
    }

    [Fact]
    public async Task DatabaseRefusingTheEvent_MarksMessageFailed()
    {
        var service = Create(new AllocationResult(true), out _);
        _activations.RaiseThrows = new BusinessRuleViolationException(20010, "Event not valid");
        _outbox.Pending.Enqueue(Message(NotificationAudience.Carrier));

        await service.ProcessNextAsync(default);

        Assert.Equal("Event not valid", Assert.Single(_outbox.Failed).Error);
    }

    [Fact]
    public async Task OperationsMessage_IsLoggedOnly_AndMarkedPublished()
    {
        var service = Create(new AllocationResult(true), out var carrier);
        _outbox.Pending.Enqueue(Message(NotificationAudience.Operations));

        await service.ProcessNextAsync(default);

        Assert.Empty(carrier.Calls);
        Assert.Empty(_customer.Sent);
        Assert.Equal([1L], _outbox.Published);
    }
}

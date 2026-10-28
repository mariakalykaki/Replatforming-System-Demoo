using Na.Application;
using Na.Application.Services;

namespace Na.IntegrationTests;

public class ScenarioTests
{
    private readonly TestWorld _w = new();

    private static IReadOnlyList<string> Events(ActivationDetail d) => TestWorld.Events(d);

    private async Task<(ActivationDetail Detail, string Msisdn)> SubmitClean(
        string suffix = "01", string customerType = "POSTPAID", bool verified = true, string plan = "PRO")
    {
        var customer = await _w.NewCustomer();
        var msisdn = await _w.NewNumber(suffix);
        return (await _w.Submit(msisdn, customer, customerType, verified, plan), msisdn);
    }


    [OracleFact]
    public async Task S01_HappyPath_ReachesActive()
    {
        var (submitted, msisdn) = await SubmitClean();
        var id = submitted.Activation.Id;

        Assert.Equal(ActivationStatus.Allocating, submitted.Activation.Status);
        Assert.Equal(0, submitted.Activation.RiskScore);
        Assert.Equal("RESERVED", await _w.PoolStatus(msisdn));

        await _w.DrainOutbox();
        Assert.Equal(ActivationStatus.AwaitingActivation, (await _w.Get(id)).Activation.Status);
        Assert.Contains(msisdn, _w.Carrier.Calls);

        var final = await _w.Activations.ConfirmAsync(id, default);
        Assert.Equal(ActivationStatus.Active, final.Activation.Status);
        Assert.Equal("ACTIVE", await _w.PoolStatus(msisdn));
        Assert.Equal(["REQUEST_RECEIVED", "RISK_SCORED", "ALLOCATION_SUCCEEDED", "SIM_CONFIRMED"], Events(final));
        Assert.Contains("ACTIVATION_COMPLETE", await _w.Notifications(id));
    }

    [OracleFact]
    public async Task S02_ReviewApproved_ReachesActive()
    {
        var customer = await _w.NewCustomer();
        await _w.GiveRecentRequests(customer, 3);
        var msisdn = await _w.NewNumber();

        var submitted = await _w.Submit(msisdn, customer);
        var id = submitted.Activation.Id;
        Assert.Equal(ActivationStatus.ManualReview, submitted.Activation.Status);
        Assert.Equal(40, submitted.Activation.RiskScore);
        Assert.Equal(["R1"], submitted.Activation.RiskFactors);
        Assert.Equal(2, await _w.PendingTimers(id));

        var approved = await _w.Activations.ReviewAsync(id, ReviewDecision.Approve, default);
        Assert.Equal(ActivationStatus.Allocating, approved.Activation.Status);
        Assert.Equal(0, await _w.PendingTimers(id));

        await _w.DrainOutbox();
        var final = await _w.Activations.ConfirmAsync(id, default);
        Assert.Equal(ActivationStatus.Active, final.Activation.Status);
    }

    [OracleFact]
    public async Task S03_ReviewIgnored_EscalatesThenExpires()
    {
        var customer = await _w.NewCustomer(ageDays: 1);
        var msisdn = await _w.NewNumber(premium: true);

        var submitted = await _w.Submit(msisdn, customer);
        var id = submitted.Activation.Id;
        Assert.Equal(ActivationStatus.ManualReview, submitted.Activation.Status);
        Assert.Equal(40, submitted.Activation.RiskScore);
        Assert.Equal(["R2", "R3"], submitted.Activation.RiskFactors);

        await _w.MakeTimerDue(id, "REVIEW_ESCALATION");
        await _w.Sweep();
        var escalated = (await _w.Get(id)).Activation;
        Assert.Equal(ActivationStatus.ManualReview, escalated.Status);
        Assert.True(escalated.Escalated);

        await _w.MakeTimerDue(id, "REVIEW_EXPIRY");
        await _w.Sweep();
        Assert.Equal(ActivationStatus.Expired, (await _w.Get(id)).Activation.Status);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
        Assert.Contains("REVIEW_ESCALATED", await _w.Notifications(id));
        Assert.Contains("ACTIVATION_EXPIRED", await _w.Notifications(id));
    }

    [OracleFact]
    public async Task S05a_CarrierTimeout_Fails_AndReleasesNumber()
    {
        var (submitted, msisdn) = await SubmitClean(suffix: "00");
        await _w.DrainOutbox();

        var final = await _w.Get(submitted.Activation.Id);
        Assert.Equal(ActivationStatus.Failed, final.Activation.Status);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
        Assert.Contains("Carrier unavailable", final.Audit.Last().Detail);
        var notes = await _w.Notifications(submitted.Activation.Id);
        Assert.Contains("ACTIVATION_FAILED", notes);
        Assert.Contains("ACTIVATION_FAILED_OPS", notes);
    }

    [OracleFact]
    public async Task S05b_CarrierRefusal_Fails()
    {
        var (submitted, msisdn) = await SubmitClean(suffix: "99");
        await _w.DrainOutbox();

        var final = await _w.Get(submitted.Activation.Id);
        Assert.Equal(ActivationStatus.Failed, final.Activation.Status);
        Assert.Contains("rejected", final.Audit.Last().Detail);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
    }

    [OracleFact]
    public async Task S06_MultiReasonRejection()
    {
        var customer = await _w.NewCustomer(balance: 25m);
        var msisdn = await _w.NewNumber();

        var result = await _w.Submit(msisdn, customer, "PREPAID", idVerified: false, plan: "PRO");

        Assert.Equal(ActivationStatus.Rejected, result.Activation.Status);
        Assert.Equal(["OUTSTANDING_BALANCE", "ID_REQUIRED"], result.Activation.RejectionReasons);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
        Assert.Contains("ACTIVATION_REJECTED", await _w.Notifications(result.Activation.Id));
    }

    [OracleFact]
    public async Task S07_PrepaidStarterUnverified_GoesToReviewViaR4()
    {
        var (result, _) = await SubmitClean(customerType: "PREPAID", verified: false, plan: "STARTER");

        Assert.Equal(ActivationStatus.ManualReview, result.Activation.Status);
        Assert.Equal(30, result.Activation.RiskScore);
        Assert.Equal(["R4"], result.Activation.RiskFactors);
    }

    [OracleFact]
    public async Task S08_CustomerCancels_ReleasesNumber()
    {
        var (submitted, msisdn) = await SubmitClean();
        var id = submitted.Activation.Id;
        await _w.DrainOutbox();

        var cancelled = await _w.Activations.CancelAsync(id, default);

        Assert.Equal(ActivationStatus.Cancelled, cancelled.Activation.Status);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
        Assert.Equal(0, await _w.PendingTimers(id));
        Assert.Contains("ACTIVATION_CANCELLED", await _w.Notifications(id));
    }

    [OracleFact]
    public async Task S09_ActivationWindowExpires()
    {
        var (submitted, msisdn) = await SubmitClean();
        var id = submitted.Activation.Id;
        await _w.DrainOutbox();
        Assert.Equal(1, await _w.PendingTimers(id));

        await _w.MakeTimerDue(id, "ACTIVATION_WINDOW");
        await _w.Sweep();

        Assert.Equal(ActivationStatus.Expired, (await _w.Get(id)).Activation.Status);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
    }


    [OracleFact]
    public async Task S10_LineLimit_Rejected()
    {
        var customer = await _w.NewCustomer();
        await _w.GiveActiveLines(customer, 5);

        var result = await _w.Submit(await _w.NewNumber(), customer);

        Assert.Equal(ActivationStatus.Rejected, result.Activation.Status);
        Assert.Equal(["LINE_LIMIT_EXCEEDED"], result.Activation.RejectionReasons);
    }

    [OracleFact]
    public async Task S11_NumberAlreadyActive_Rejected()
    {
        var customer = await _w.NewCustomer();
        var msisdn = await _w.NewNumber(poolStatus: "ACTIVE");

        var result = await _w.Submit(msisdn, customer);

        Assert.Equal(["NUMBER_UNAVAILABLE"], result.Activation.RejectionReasons);
    }

    [OracleFact]
    public async Task S12_UnsupportedRange_ReportsBothReasons()
    {
        var customer = await _w.NewCustomer();

        var result = await _w.Submit("+447700900123", customer);

        Assert.Equal(ActivationStatus.Rejected, result.Activation.Status);
        Assert.Equal(["INVALID_NUMBER", "NUMBER_UNAVAILABLE"], result.Activation.RejectionReasons);
    }

    [OracleFact]
    public async Task S13_DuplicateOpenRequest_Rejected()
    {
        var customer = await _w.NewCustomer();
        var msisdn = await _w.NewNumber();
        var first = await _w.Submit(msisdn, customer);

        var second = await _w.Submit(msisdn, customer);

        Assert.Equal(ActivationStatus.Allocating, first.Activation.Status);
        Assert.Equal(ActivationStatus.Rejected, second.Activation.Status);
        Assert.Contains("DUPLICATE_REQUEST", second.Activation.RejectionReasons);
        Assert.Contains("NUMBER_UNAVAILABLE", second.Activation.RejectionReasons);
        Assert.Equal("RESERVED", await _w.PoolStatus(msisdn));
    }

    [OracleFact]
    public async Task S14_ReviewRejected_ReleasesNumber()
    {
        var customer = await _w.NewCustomer();
        await _w.GiveRecentRequests(customer, 3);
        var msisdn = await _w.NewNumber();
        var submitted = await _w.Submit(msisdn, customer);

        var rejected = await _w.Activations.ReviewAsync(submitted.Activation.Id, ReviewDecision.Reject, default);

        Assert.Equal(ActivationStatus.Rejected, rejected.Activation.Status);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
        Assert.Equal(0, await _w.PendingTimers(submitted.Activation.Id));
    }

    [OracleFact]
    public async Task S15_HighRisk_Rejected()
    {
        var customer = await _w.NewCustomer();
        await _w.GiveRecentRequests(customer, 3);
        var msisdn = await _w.NewNumber(premium: true);

        var result = await _w.Submit(msisdn, customer, "PREPAID", idVerified: false, plan: "STARTER");

        Assert.Equal(ActivationStatus.Rejected, result.Activation.Status);
        Assert.Equal(90, result.Activation.RiskScore);
        Assert.Equal(["R1", "R3", "R4"], result.Activation.RiskFactors);
        Assert.Equal("AVAILABLE", await _w.PoolStatus(msisdn));
    }

    [OracleFact]
    public async Task S16_ConfirmWhileInReview_IsRefused()
    {
        var customer = await _w.NewCustomer();
        await _w.GiveRecentRequests(customer, 3);
        var submitted = await _w.Submit(await _w.NewNumber(), customer);

        var ex = await Assert.ThrowsAsync<BusinessRuleViolationException>(
            () => _w.Activations.ConfirmAsync(submitted.Activation.Id, default));

        Assert.Equal(20010, ex.ErrorCode);
        Assert.Equal(ActivationStatus.ManualReview, (await _w.Get(submitted.Activation.Id)).Activation.Status);
    }

    [OracleFact]
    public async Task S17_CancelWhileAllocating_IsRefused()
    {
        var (submitted, _) = await SubmitClean();

        var ex = await Assert.ThrowsAsync<BusinessRuleViolationException>(
            () => _w.Activations.CancelAsync(submitted.Activation.Id, default));

        Assert.Equal(20010, ex.ErrorCode);
    }

    [OracleFact]
    public async Task S18_UnknownActivation_NotFound()
    {
        var ex = await Assert.ThrowsAsync<BusinessRuleViolationException>(() => _w.Activations.GetAsync(999_999_999, default));
        Assert.Equal(20003, ex.ErrorCode);
    }

    [OracleFact]
    public async Task S19_MalformedInput_Refused()
    {
        var customer = await _w.NewCustomer();

        var ex = await Assert.ThrowsAsync<BusinessRuleViolationException>(() =>
            _w.Activations.SubmitAsync(new SubmitActivationRequest("+306900000101", customer, null, true, "PRO"), default));

        Assert.Equal(20001, ex.ErrorCode);
    }

    [OracleFact]
    public async Task S20_ReleasedNumber_CanBeReused()
    {
        var (first, msisdn) = await SubmitClean();
        await _w.DrainOutbox();
        await _w.Activations.CancelAsync(first.Activation.Id, default);

        var second = await _w.Submit(msisdn, await _w.NewCustomer());

        Assert.Equal(ActivationStatus.Allocating, second.Activation.Status);
    }

    [OracleFact]
    public async Task S21_UnknownCustomer_NotFound()
    {
        var msisdn = await _w.NewNumber();
        var ex = await Assert.ThrowsAsync<BusinessRuleViolationException>(
            () => _w.Submit(msisdn, "NO-SUCH-CUSTOMER"));
        Assert.Equal(20003, ex.ErrorCode);
    }
}

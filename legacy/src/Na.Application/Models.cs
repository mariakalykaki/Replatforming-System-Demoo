namespace Na.Application;

public sealed record SubmitActivationRequest(
    string? Msisdn, string? CustomerId, string? CustomerType, bool? IdVerified, string? PlanCode);

public sealed record Activation(
    long Id, string Msisdn, string CustomerId, string CustomerType, bool IdVerified, string PlanCode,
    ActivationStatus Status, IReadOnlyList<string> RejectionReasons,
    int? RiskScore, IReadOnlyList<string> RiskFactors, string? RiskDecision,
    bool Escalated, DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public sealed record AuditEntry(
    string EventType, ActivationStatus FromStatus, ActivationStatus ToStatus, string? Detail, DateTimeOffset OccurredAt);

public sealed record ActivationDetail(Activation Activation, IReadOnlyList<AuditEntry> Audit);

public enum NotificationAudience { Customer, Operations, Carrier }

public sealed record OutboxMessage(
    long Id, long ActivationId, string Msisdn, string NotificationCode,
    NotificationAudience Audience, string Channel);

public sealed record AllocationResult(bool Succeeded, string? Reason = null);

public static class ActivationEvents
{
    public const string ReviewApproved = "REVIEW_APPROVED";
    public const string ReviewRejected = "REVIEW_REJECTED";
    public const string SimConfirmed = "SIM_CONFIRMED";
    public const string CustomerCancelled = "CUSTOMER_CANCELLED";
    public const string AllocationSucceeded = "ALLOCATION_SUCCEEDED";
    public const string AllocationFailed = "ALLOCATION_FAILED";
}

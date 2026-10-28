namespace Na.Application;

public sealed class BusinessRuleViolationException(int errorCode, string message, Exception? inner = null)
    : Exception(message, inner)
{
    public int ErrorCode { get; } = errorCode;
}

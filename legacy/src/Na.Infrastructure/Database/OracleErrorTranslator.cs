using Na.Application;
using Oracle.ManagedDataAccess.Client;

namespace Na.Infrastructure.Database;

public static class OracleErrorTranslator
{
    public static BusinessRuleViolationException? TryTranslate(OracleException exception) =>
        exception.Number is >= 20001 and <= 20099
            ? new BusinessRuleViolationException(exception.Number, ExtractMessage(exception.Message), exception)
            : null;

    public static string ExtractMessage(string oracleMessage)
    {
        var firstLine = oracleMessage.Split('\n', 2)[0].Trim();
        var separator = firstLine.IndexOf(": ", StringComparison.Ordinal);
        return firstLine.StartsWith("ORA-", StringComparison.Ordinal) && separator >= 0
            ? firstLine[(separator + 2)..]
            : firstLine;
    }
}

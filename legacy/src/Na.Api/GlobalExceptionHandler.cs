using Microsoft.AspNetCore.Diagnostics;
using Na.Application;

namespace Na.Api;

internal sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is BusinessRuleViolationException violation)
        {
            logger.LogWarning("Refused by rule ORA-{Code}: {Reason}", violation.ErrorCode, violation.Message);

            var status = violation.ErrorCode == 20003 ? StatusCodes.Status404NotFound : StatusCodes.Status400BadRequest;
            await Results.Problem(
                title: "The request was refused.",
                detail: violation.Message,
                statusCode: status,
                extensions: new Dictionary<string, object?> { ["errorCode"] = violation.ErrorCode }
            ).ExecuteAsync(httpContext);
            return true;
        }

        logger.LogError(exception, "Unhandled exception. TraceId: {TraceId}", httpContext.TraceIdentifier);
        await Results.Problem(
            title: "An unexpected error occurred.",
            statusCode: StatusCodes.Status500InternalServerError,
            extensions: new Dictionary<string, object?> { ["traceId"] = httpContext.TraceIdentifier }
        ).ExecuteAsync(httpContext);
        return true;
    }
}

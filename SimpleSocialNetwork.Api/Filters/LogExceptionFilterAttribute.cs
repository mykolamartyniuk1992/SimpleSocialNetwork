using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace SimpleSocialNetwork;

public sealed class LogExceptionFilterAttribute : ExceptionFilterAttribute
{
    private static readonly NLog.Logger Logger = NLog.LogManager.GetCurrentClassLogger();

    public override void OnException(ExceptionContext context)
    {
        // логируем
        Logger.Error(context.Exception, "Unhandled exception");

        // опционально — отдать 500 с минимальным body
        context.Result = new ObjectResult(new { error = "Internal Server Error" })
        {
            StatusCode = StatusCodes.Status500InternalServerError
        };

        context.ExceptionHandled = true;
    }
}

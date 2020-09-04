using System.Web.Http.Filters;

namespace SimpleSocialNetwork
{
    public class LogExceptionFilterAttribute : ExceptionFilterAttribute
    {
        private readonly NLog.Logger logger = NLog.LogManager.GetCurrentClassLogger();
        public override void OnException(HttpActionExecutedContext context)
        {
            logger.Error(context.Exception);
        }
    }
}
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection;
using SimpleSocialNetwork.Service.ModelProfileService; // <-- твой namespace с сервисом

namespace SimpleSocialNetwork;

public sealed class IsAuthenticatedAttribute : Attribute, IAsyncActionFilter
{
    private readonly IModelProfileService _profiles;

    public IsAuthenticatedAttribute(IModelProfileService profiles) => _profiles = profiles;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var http = context.HttpContext;

        if (!http.Request.Cookies.TryGetValue("name", out var name) ||
            !http.Request.Cookies.TryGetValue("token", out var token))
        {
            context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
            return;
        }

        if (!_profiles.IsAuthenticated(name, token))
        {
            context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
            return;
        }

        await next();
    }
}

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
        string? token = null;
        int? userId = null;

        // Check Authorization header first (Bearer token)
        var authHeader = http.Request.Headers["Authorization"].FirstOrDefault();
        if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = authHeader.Substring("Bearer ".Length).Trim();
        }

        // Fallback to cookies if no Bearer token
        if (string.IsNullOrEmpty(token))
        {
            if (!http.Request.Cookies.TryGetValue("name", out var name) ||
                !http.Request.Cookies.TryGetValue("token", out token))
            {
                context.Result = new StatusCodeResult(StatusCodes.Status401Unauthorized);
                return;
            }

            if (!_profiles.IsAuthenticated(name, token))
            {
                context.Result = new StatusCodeResult(StatusCodes.Status401Unauthorized);
                return;
            }
        }
        else
        {
            // For Bearer token, validate it
            userId = _profiles.GetUserIdByToken(token);
            if (userId == null || userId == 0)
            {
                context.Result = new StatusCodeResult(StatusCodes.Status401Unauthorized);
                return;
            }

            // Store userId in HttpContext for controllers to use
            http.Items["UserId"] = userId;
            
            // Store IsAdmin status for admin-only endpoints
            http.Items["IsAdmin"] = _profiles.GetIsAdminByToken(token);
        }

        await next();
    }
}

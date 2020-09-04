using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using System.Web.Mvc;
using System.Web.Routing;
using SimpleSocialNetwork.Service.ModelProfileService;
using ActionFilterAttribute = System.Web.Http.Filters.ActionFilterAttribute;

namespace SimpleSocialNetwork
{
    public class IsAuthenticated : ActionFilterAttribute
    {
        public override void OnActionExecuting(HttpActionContext actionContext)
        {
            var cookies = actionContext.Request.Headers.GetCookies().FirstOrDefault();
            var response = actionContext.Request.CreateResponse(HttpStatusCode.Forbidden);
            if (cookies != null)
            {
                var name = cookies["name"];
                var token = cookies["token"];
                bool isAuthenticated = new ModelProfileService().IsAuthenticated(name.Value, token.Value);
                if (!isAuthenticated)
                {
                    actionContext.Response = response;
                }

                return;
            }

            actionContext.Response = response;
        }
    }
}
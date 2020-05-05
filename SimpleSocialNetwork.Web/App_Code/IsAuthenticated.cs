using System.Linq;
using System.Net.Http;
using System.Web;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork
{
    public class IsAuthenticated : ActionFilterAttribute
    {
        public override void OnActionExecuting(HttpActionContext actionContext)
        {
            var cookies = actionContext.Request.Headers.GetCookies().FirstOrDefault();
            if (cookies != null)
            {
                var name = cookies["name"];
                var token = cookies["token"];
                bool isAuthenticated = new ModelProfileService().IsAuthenticated(name.Value, token.Value);
                if (!isAuthenticated)
                {
                    throw new HttpException("no such user!");
                }
            }
            else throw new HttpException("cookies is empty!");
        }
    }
}
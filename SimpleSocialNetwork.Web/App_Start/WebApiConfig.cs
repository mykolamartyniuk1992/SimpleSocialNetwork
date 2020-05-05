using System.Web.Http;

namespace SimpleSocialNetwork
{
    public class WebApiConfig
    {
        public static void Register(HttpConfiguration config)
        {
            config.MapHttpAttributeRoutes();
            config.Routes.MapHttpRoute(
            name: "FeedApi",
            routeTemplate: "api/{controller}/{action}/{id}",
            defaults: new { id = RouteParameter.Optional, action = RouteParameter.Optional });
        }
    }
}

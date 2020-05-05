using System.Net.Http.Formatting;
using System.Web.Http;
using Microsoft.AspNet.SignalR;
using Microsoft.Owin;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using Owin;
[assembly: OwinStartup(typeof(SimpleSocialNetwork.Startup))]

namespace SimpleSocialNetwork
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            app.MapSignalR();

            //var httpConfiguration = new HttpConfiguration();

            //httpConfiguration.Formatters.Clear();
            //httpConfiguration.Formatters.Add(new JsonMediaTypeFormatter());

            //httpConfiguration.Formatters.JsonFormatter.SerializerSettings =
            //    new JsonSerializerSettings
            //    {
            //        ContractResolver = new CamelCasePropertyNamesContractResolver()
            //    };

            //httpConfiguration.Routes.MapHttpRoute(
            //    name: "test",
            //    routeTemplate: "{*all}",
            //    defaults: new { });

            //app.UseWebApi(httpConfiguration);
        }
    }
}
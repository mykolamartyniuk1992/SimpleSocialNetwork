using System;
using System.Web.Http;
using SimpleSocialNetwork;

namespace SimpleSocialNetwork
{
    public class WebApiApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);
            GlobalConfiguration.Configuration.Filters.Add(new LogExceptionFilterAttribute());
        }

        //in global.asax or global.asax.cs
        protected void Application_Error(object sender, EventArgs e)
        {
            Exception ex = Server.GetLastError();
            throw ex;
        }
    }
}

using System;
using System.Web.Http;
using System.Web.Mvc;
using Ninject;
using Ninject.Modules;
using Ninject.Web.Mvc;
using SimpleSocialNetwork.App_Code;

namespace SimpleSocialNetwork
{
    public class WebApiApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);
            GlobalConfiguration.Configuration.Filters.Add(new LogExceptionFilterAttribute());
            NinjectModule registrations = new NinjectRegistrations();
            var kernel = new StandardKernel(registrations);
            DependencyResolver.SetResolver(new NinjectDependencyResolver(kernel));
        }

        //in global.asax or global.asax.cs
        protected void Application_Error(object sender, EventArgs e)
        {
            Exception ex = Server.GetLastError();
            throw ex;
        }
    }
}

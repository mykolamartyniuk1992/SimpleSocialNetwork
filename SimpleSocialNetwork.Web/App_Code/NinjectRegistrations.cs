using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Ninject.Modules;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork.App_Code
{
    public class NinjectRegistrations : NinjectModule
    {
        public override void Load()
        {
            Bind<IModelFeedService>().To<ModelFeedService>();
            Bind<IModelProfileService>().To<ModelProfileService>();
        }
    }
}
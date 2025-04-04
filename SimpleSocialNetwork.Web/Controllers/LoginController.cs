using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using Ninject;
using SimpleSocialNetwork.App_Code;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork.Controllers
{
    [RoutePrefix("api/login")]
    public class LoginController : ApiController
    {
        private readonly IModelProfileService modelProfileService = new ModelProfileService();

        public LoginController()
        {
            try
            {
                //var kernel = new StandardKernel(new NinjectRegistrations());
                //this.modelProfileService = kernel.Get<IModelProfileService>();
            }
            catch (Exception e)
            {

                throw e;
            }
            
        }

        [HttpPost]
        [Route("login")]
        public DtoProfile Login(DtoProfile profile)
        {
            try
            {
                profile.token = this.modelProfileService.Login(profile.name, profile.password).ToString();
                return profile;
            }
            catch (Exception e)
            {
                throw new HttpResponseException(new HttpResponseMessage(HttpStatusCode.Forbidden) { Content = new StringContent(e.Message) });
            }
        }

        [HttpPost]
        [Route("isregistered")]
        public bool IsRegistered(DtoProfile profile)
        {
            return new ModelProfileService().IsRegistered(profile.name, profile.password);
        }

        [HttpPost]
        [Route("isauthenticated")]
        public bool IsAuthenticated(DtoProfile profile)
        {
            return new ModelProfileService().IsAuthenticated(profile.name, profile.token);
        }
    }
}

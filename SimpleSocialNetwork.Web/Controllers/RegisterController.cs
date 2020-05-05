using System;
using System.Web.Http;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork.Controllers
{
    public class RegisterController : ApiController
    {
        [HttpPost]
        public void Register(DtoProfile newProfile)
        {
            new ModelProfileService().Register(newProfile);
        }
    }
}

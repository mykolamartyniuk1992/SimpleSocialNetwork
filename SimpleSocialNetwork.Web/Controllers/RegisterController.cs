using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using SimpleSocialNetwork.App_Code;
using SimpleSocialNetwork.App_Code.Database;
using SimpleSocialNetwork.Database.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Controllers
{
    public class RegisterController : ApiController
    {
        [HttpPost]
        public void Register(DtoProfile newProfile)
        {
            ModelProfile modelProfile = new ModelProfile()
            {
                DateAdd = DateTime.Now,
                Name = newProfile.name,
                Password = newProfile.password
            };
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.profiles.Add(modelProfile);
                context.SaveChanges();
            }
        }
    }
}

using System;
using System.Web.Http;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Dto;
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

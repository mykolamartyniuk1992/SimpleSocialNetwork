using SimpleSocialNetwork.App_Code;
using SimpleSocialNetwork.App_Code.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using SimpleSocialNetwork.Database.Dto;

namespace SimpleSocialNetwork.Controllers
{
    public class LoginController : ApiController
    {
        [HttpPost]
        public DtoProfile Login(DtoProfile profile)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var profileFounded = context.profiles.Where(p => p.Name == profile.name && p.Password == profile.password).FirstOrDefault();
                if (profileFounded != null)
                {
                    profileFounded.Token = profile.token = Guid.NewGuid().ToString();
                    context.SaveChanges();
                    return profile;
                }
                else throw new HttpResponseException(new HttpResponseMessage(HttpStatusCode.Forbidden) { Content = new StringContent("user not found!") });
            }
        }

        [HttpPost]
        public bool IsLoggedIn(DtoProfile profile)
        {
            using ( 
                    var context = new SimpleSocialNetworkDbContext())
            {
                var profileFounded = context.profiles.Where(p => p.Name == profile.name && p.Token == profile.token).FirstOrDefault();
                if (profileFounded != null)
                {
                    return true;
                }
                else return false;
            }
        }
    }
}

using System;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork.Controllers
{
    [ApiController]
    [Route("api/login")]
    public class LoginController : ControllerBase
    {
        private readonly IModelProfileService _profiles;

        public LoginController(IModelProfileService profiles)
        {
            _profiles = profiles;
        }

        [HttpPost("login")]
        public ActionResult<DtoProfile> Login([FromBody] DtoProfile profile)
        {
            try
            {
                var token = _profiles.Login(profile.name, profile.password).ToString();

                // Если используешь куки для фильтра IsAuthenticated — пишем их тут
                var cookie = new CookieOptions
                {
                    HttpOnly = true,
                    SameSite = SameSiteMode.Strict,
                    Secure = Request.IsHttps,      // true за HTTPS
                    Expires = DateTimeOffset.UtcNow.AddDays(7)
                };
                Response.Cookies.Append("name",  profile.name, cookie);
                Response.Cookies.Append("token", token,       cookie);

                profile.token = token;
                return Ok(profile);
            }
            catch (Exception e)
            {
                // Аналог HttpResponseException(HttpStatusCode.Forbidden)
                return Problem(e.Message, statusCode: 403);
            }
        }

        [HttpPost("isregistered")]
        public ActionResult<bool> IsRegistered([FromBody] DtoProfile profile)
            => Ok(_profiles.IsRegistered(profile.name, profile.password));

        [HttpPost("isauthenticated")]
        public ActionResult<bool> IsAuthenticated([FromBody] DtoProfile profile)
            => Ok(_profiles.IsAuthenticated(profile.name, profile.token));
    }
}

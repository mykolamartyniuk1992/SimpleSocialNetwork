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
        public async Task<ActionResult> Login([FromBody] DtoProfile profile)
        {
            var result = await _profiles.LoginAsync(profile.email, profile.password);
            
            if (result == null)
            {
                return Unauthorized(new { message = "Invalid email or password" });
            }

            return Ok(new { id = result.Value.Id, token = result.Value.Token, isAdmin = result.Value.IsAdmin, name = result.Value.Name, photoUrl = result.Value.PhotoPath, verified = result.Value.Verified, messagesLeft = result.Value.MessagesLeft });
        }

        [HttpPost("isregistered")]
        public ActionResult<bool> IsRegistered([FromBody] DtoProfile profile)
            => Ok(_profiles.IsRegistered(profile.name, profile.password));

        [HttpPost("isauthenticated")]
        public ActionResult<bool> IsAuthenticated([FromBody] DtoProfile profile)
            => Ok(_profiles.IsAuthenticated(profile.name, profile.token));

        [HttpGet("getadmincredentials")]
        public async Task<ActionResult> GetAdminCredentials()
        {
            // Only available in development
            var isDevelopment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Development";
            if (!isDevelopment)
            {
                return NotFound();
            }

            var adminCredentials = await _profiles.GetAdminCredentialsAsync();
            if (adminCredentials == null)
            {
                return NotFound(new { message = "No admin user found" });
            }

            return Ok(new { email = adminCredentials.Value.Email, password = adminCredentials.Value.Password });
        }
    }
}

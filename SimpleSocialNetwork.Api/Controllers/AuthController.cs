using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using SimpleSocialNetwork.Service.ModelProfileService;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]/[action]")]
    public class AuthController : ControllerBase
    {
        private readonly IModelProfileService _profileService;

        public AuthController(IModelProfileService profileService)
        {
            _profileService = profileService;
        }

        [HttpPost]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<IActionResult> Logout()
        {
            var userId = HttpContext.Items["UserId"] as int?;
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            await _profileService.ClearUserTokenAsync(userId.Value);
            return Ok(new { message = "Logged out successfully" });
        }
    }
}

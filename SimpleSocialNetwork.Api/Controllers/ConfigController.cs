using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using SimpleSocialNetwork.Service.ModelProfileService;

namespace SimpleSocialNetwork.Controllers;

[ApiController]
[Route("api/[controller]/[action]")]
public class ConfigController : ControllerBase
{
    private readonly IModelProfileService _profileService;

    public ConfigController(IModelProfileService profileService)
    {
        _profileService = profileService;
    }

    [HttpGet]
    public IActionResult GetDefaultMessageLimit()
    {
        var defaultLimit = _profileService.GetDefaultMessageLimitAsync().Result;
        return Ok(new { defaultMessageLimit = defaultLimit });
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> SetDefaultMessageLimit([FromBody] SetDefaultMessageLimitRequest request)
    {
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (!isAdmin.HasValue || !isAdmin.Value)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        if (request.DefaultMessageLimit < 0)
        {
            return BadRequest(new { message = "Message limit cannot be negative" });
        }

        await _profileService.SetDefaultMessageLimitAsync(request.DefaultMessageLimit);
        return Ok(new { message = "Default message limit updated successfully" });
    }

    public class SetDefaultMessageLimitRequest
    {
        public int DefaultMessageLimit { get; set; }
    }
}

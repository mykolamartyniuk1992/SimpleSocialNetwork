using Microsoft.AspNetCore.Mvc;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Service.ModelProfileService;

[ApiController]
[Route("api/[controller]/[action]")]
public class RegisterController : ControllerBase
{
    private readonly IModelProfileService _profileService;

    public RegisterController(IModelProfileService profileService)
        => _profileService = profileService;

    [HttpPost]                      // POST /api/register
    public async Task<IActionResult> Register([FromBody] DtoProfile newProfile,
        CancellationToken ct)
    {
        await _profileService.RegisterAsync(newProfile);
        return Ok();
    }
}
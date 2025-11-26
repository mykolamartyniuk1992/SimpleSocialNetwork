using Microsoft.AspNetCore.Mvc;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Service.ModelProfileService;
using SimpleSocialNetwork.Api.Services;

[ApiController]
[Route("api/[controller]/[action]")]

public class RegisterController : ControllerBase
{
    private readonly IModelProfileService _profileService;
    private readonly EmailService _emailService;

    public RegisterController(IModelProfileService profileService, EmailService emailService)
    {
        _profileService = profileService;
        _emailService = emailService;
    }

    [HttpPost]                      // POST /api/register
    public async Task<IActionResult> Register([FromBody] DtoProfile newProfile,
        CancellationToken ct)
    {
        // Validate email
        if (string.IsNullOrWhiteSpace(newProfile.email))
        {
            return BadRequest(new { message = "Email is required" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(newProfile.email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
        {
            return BadRequest(new { message = "Invalid email format" });
        }

        // Validate password
        if (string.IsNullOrWhiteSpace(newProfile.password))
        {
            return BadRequest(new { message = "Password is required" });
        }

        if (newProfile.password.Length < 8)
        {
            return BadRequest(new { message = "Password must be at least 8 characters long" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(newProfile.password, @"[A-Z]"))
        {
            return BadRequest(new { message = "Password must contain at least one uppercase letter" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(newProfile.password, @"\d"))
        {
            return BadRequest(new { message = "Password must contain at least one digit" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(newProfile.password, @"[@$!%*?&]"))
        {
            return BadRequest(new { message = "Password must contain at least one special character (@$!%*?&)" });
        }

        var (profileId, token, isAdmin, name, photoPath, verified, messagesLeft, verifyHash) = await _profileService.RegisterAsync(newProfile);

        // Сформировать ссылку для верификации
        var request = HttpContext.Request;
        var baseUrl = $"{request.Scheme}://{request.Host}";
        var verifyLink = $"{baseUrl}/api/profile/verify/{newProfile.email}/{verifyHash}";
        await _emailService.SendVerificationEmailAsync(newProfile.email, verifyLink);

        return Ok(new { id = profileId, token = token, isAdmin = isAdmin, name = name, photoUrl = photoPath, verified = verified, messagesLeft = messagesLeft });
    }
}
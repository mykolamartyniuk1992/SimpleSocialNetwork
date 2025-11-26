using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Service.ModelProfileService;
using SimpleSocialNetwork;
using static SimpleSocialNetwork.Service.ModelProfileService.IModelProfileService;

[ApiController]
[Route("api/[controller]/[action]")]
public class ProfileController : ControllerBase
{
    private readonly IWebHostEnvironment _environment;
    private readonly IModelProfileService _profileService;
    private readonly IHubContext<FeedHub> _hubContext;

    public ProfileController(IWebHostEnvironment environment, IModelProfileService profileService, IHubContext<FeedHub> hubContext)
    {
        _environment = environment;
        _profileService = profileService;
        _hubContext = hubContext;
    }

    [HttpPost]
    public async Task<IActionResult> UploadPhoto([FromForm] IFormFile photo, [FromForm] int profileId,
        CancellationToken ct)
    {
        if (photo == null || photo.Length == 0)
            return BadRequest("No photo provided");

        // Create uploads directory if it doesn't exist
        var uploadsPath = Path.Combine(_environment.ContentRootPath, "uploads", "profiles");
        Directory.CreateDirectory(uploadsPath);

        // Save file with profile ID as name
        var extension = Path.GetExtension(photo.FileName);
        var fileName = $"{profileId}{extension}";
        var filePath = Path.Combine(uploadsPath, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await photo.CopyToAsync(stream, ct);
        }

        // Update profile with photo path
        var photoPath = $"/api/profile/getphoto?profileId={profileId}";
        await _profileService.UpdatePhotoPathAsync(profileId, photoPath);

        return Ok(new { fileName, photoPath });
    }

    [HttpGet]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> GetCurrentUserMessagesLeft()
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        var messagesLeft = await _profileService.GetMessagesLeftAsync(userId.Value);
        return Ok(new { messagesLeft });
    }

    [HttpGet]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> GetAllUsers()
    {
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (isAdmin != true)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        try
        {
            var users = await _profileService.GetAllUsersAsync();
            return Ok(users);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR in GetAllUsers: {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            Console.WriteLine($"Inner Exception: {ex.InnerException?.Message}");
            Console.WriteLine($"Inner Stack Trace: {ex.InnerException?.StackTrace}");
            return StatusCode(500, new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> SetVerified([FromBody] SetVerifiedRequest request)
    {
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (isAdmin != true)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        try
        {
            // Get user token before updating
            var userToken = await _profileService.GetUserTokenAsync(request.ProfileId);
            
            // Update verification status
            await _profileService.SetVerifiedAsync(request.ProfileId, request.Verified);
            
            // Notify the specific user about verification change via SignalR
            if (!string.IsNullOrEmpty(userToken))
            {
                await _hubContext.Clients.All.SendAsync("UserVerificationChanged", userToken, request.Verified);
            }

            return Ok(new { message = $"User verification status updated to {request.Verified}" });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet]
    [AllowAnonymous]
    public IActionResult GetPhoto([FromQuery] int profileId)
    {
        var uploadsPath = Path.Combine(_environment.ContentRootPath, "uploads", "profiles");
        
        // Try different extensions
        var extensions = new[] { ".png", ".jpg", ".jpeg" };
        foreach (var ext in extensions)
        {
            var filePath = Path.Combine(uploadsPath, $"{profileId}{ext}");
            if (System.IO.File.Exists(filePath))
            {
                var contentType = ext == ".png" ? "image/png" : "image/jpeg";
                return PhysicalFile(filePath, contentType);
            }
        }

        return NotFound();
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> UpdateProfile([FromForm] string name, [FromForm] IFormFile? photo)
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        string? photoPath = null;
        if (photo != null && photo.Length > 0)
        {
            // Create uploads directory if it doesn't exist
            var uploadsPath = Path.Combine(_environment.ContentRootPath, "uploads", "profiles");
            Directory.CreateDirectory(uploadsPath);

            // Delete old photo files with any extension to avoid duplicates
            var extensions = new[] { ".png", ".jpg", ".jpeg", ".gif" };
            foreach (var ext in extensions)
            {
                var oldFilePath = Path.Combine(uploadsPath, $"{userId.Value}{ext}");
                if (System.IO.File.Exists(oldFilePath))
                {
                    System.IO.File.Delete(oldFilePath);
                }
            }

            // Always save as PNG to standardize format
            var fileName = $"{userId.Value}.png";
            var filePath = Path.Combine(uploadsPath, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await photo.CopyToAsync(stream);
            }

            photoPath = $"/api/profile/getphoto?profileId={userId.Value}";
        }

        // Update profile with name and photo path in single transaction
        var updatedPhotoPath = await _profileService.UpdateProfileAsync(userId.Value, name, photoPath);

        return Ok(new { name, photoPath = updatedPhotoPath });
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        // Validate new password
        if (string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return BadRequest(new { message = "New password is required" });
        }

        if (request.NewPassword.Length < 8)
        {
            return BadRequest(new { message = "Password must be at least 8 characters long" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(request.NewPassword, @"[A-Z]"))
        {
            return BadRequest(new { message = "Password must contain at least one uppercase letter" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(request.NewPassword, @"\d"))
        {
            return BadRequest(new { message = "Password must contain at least one digit" });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(request.NewPassword, @"[@$!%*?&]"))
        {
            return BadRequest(new { message = "Password must contain at least one special character (@$!%*?&)" });
        }

        var result = await _profileService.ChangePasswordAsync(userId.Value, request.OldPassword, request.NewPassword);
        if (!result)
        {
            return BadRequest(new { message = "Invalid old password" });
        }

        return Ok(new { message = "Password changed successfully" });
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> UpdateMessageLimits([FromBody] UpdateMessageLimitRequest request)
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        // Check if user is admin
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (!isAdmin.HasValue || !isAdmin.Value)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        if (request.MessageLimit < 0)
        {
            return BadRequest(new { message = "Message limit cannot be negative" });
        }

        try
        {
            await _profileService.UpdateAllUnverifiedMessagesLeftAsync(request.MessageLimit);

            // Notify all connected clients to refresh their message limits from server
            await _hubContext.Clients.All.SendAsync("RefreshMessageLimit");

            return Ok(new { message = $"Message limits updated for all unverified users to {request.MessageLimit}" });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR in UpdateMessageLimits: {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            Console.WriteLine($"Inner Exception: {ex.InnerException?.Message}");
            Console.WriteLine($"Inner Stack Trace: {ex.InnerException?.StackTrace}");
            return StatusCode(500, new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    [HttpPost]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> UpdateUserMessageLimit([FromBody] UpdateUserMessageLimitRequest request)
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        // Check if user is admin
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (!isAdmin.HasValue || !isAdmin.Value)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        if (request.MessageLimit < 0)
        {
            return BadRequest(new { message = "Message limit cannot be negative" });
        }

        try
        {
            await _profileService.UpdateUserMessageLimitAsync(request.ProfileId, request.MessageLimit);

            // Get user's token to notify them specifically
            var userToken = await _profileService.GetUserTokenAsync(request.ProfileId);
            if (!string.IsNullOrEmpty(userToken))
            {
                await _hubContext.Clients.All.SendAsync("MessageLimitUpdated", userToken, request.MessageLimit);
            }

            return Ok(new { message = $"Message limit updated to {request.MessageLimit} for user {request.ProfileId}" });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR in UpdateUserMessageLimit: {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            Console.WriteLine($"Inner Exception: {ex.InnerException?.Message}");
            Console.WriteLine($"Inner Stack Trace: {ex.InnerException?.StackTrace}");
            return StatusCode(500, new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    public class ChangePasswordRequest
    {
        public string OldPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }

    public class UpdateMessageLimitRequest
    {
        public int MessageLimit { get; set; }
    }

    public class UpdateUserMessageLimitRequest
    {
        public int ProfileId { get; set; }
        public int MessageLimit { get; set; }
    }

    [HttpDelete]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> DeleteOwnAccount()
    {
        var userId = HttpContext.Items["UserId"] as int?;
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            // Delete user and all their content
            await _profileService.DeleteUserAsync(userId.Value);

            return Ok(new { message = "Account deleted successfully" });
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"ERROR in DeleteOwnAccount (InvalidOperationException): {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            return BadRequest(new { message = ex.Message, stackTrace = ex.StackTrace });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR in DeleteOwnAccount (Exception): {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            Console.WriteLine($"Inner Exception: {ex.InnerException?.Message}");
            Console.WriteLine($"Inner Stack Trace: {ex.InnerException?.StackTrace}");
            return StatusCode(500, new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    [HttpDelete]
    [ServiceFilter(typeof(IsAuthenticatedAttribute))]
    public async Task<IActionResult> DeleteUser([FromQuery] int profileId)
    {
        var isAdmin = HttpContext.Items["IsAdmin"] as bool?;
        if (isAdmin != true)
        {
            return StatusCode(403, new { message = "Admin access required" });
        }

        try
        {
            // Clear user's token to force logout before deletion
            var userToken = await _profileService.ClearUserTokenAsync(profileId);
            
            // Notify the specific user their account was deleted via SignalR
            if (!string.IsNullOrEmpty(userToken))
            {
                await _hubContext.Clients.All.SendAsync("AccountDeleted", userToken);
            }

            // Delete user and all their content
            await _profileService.DeleteUserAsync(profileId);

            return Ok(new { message = "User deleted successfully" });
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"ERROR in DeleteUser (InvalidOperationException): {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            return BadRequest(new { message = ex.Message, stackTrace = ex.StackTrace });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR in DeleteUser (Exception): {ex.Message}");
            Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            Console.WriteLine($"Inner Exception: {ex.InnerException?.Message}");
            Console.WriteLine($"Inner Stack Trace: {ex.InnerException?.StackTrace}");
            return StatusCode(500, new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    [HttpGet("{email}/{hash}")]
    [AllowAnonymous]
    public async Task<IActionResult> Verify(string email, string hash)
    {
        var result = await _profileService.VerifyEmailAsync(email, hash);
        if (result)
        {
            // Получить токен пользователя для SignalR (если есть)
            var profile = await _profileService.GetAllUsersAsync();
            var user = profile.FirstOrDefault(p => p.Email == email);
            if (user != null)
            {
                // Получить токен пользователя
                var token = await _profileService.GetUserTokenAsync(user.Id);
                if (!string.IsNullOrEmpty(token))
                {
                    await _hubContext.Clients.All.SendAsync("UserVerificationChanged", token, true);
                }
            }
            return Content("Email verified successfully!", "text/html");
        }
        else
        {
            return Content("Verification failed. Invalid or expired link.", "text/html");
        }
    }

    public class SetVerifiedRequest
    {
        public int ProfileId { get; set; }
        public bool Verified { get; set; }
    }
}

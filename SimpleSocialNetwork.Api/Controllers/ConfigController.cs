using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Text.Json;

namespace SimpleSocialNetwork.Controllers;

[ApiController]
[Route("api/[controller]/[action]")]
public class ConfigController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public ConfigController(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
    }

    [HttpGet]
    public IActionResult GetDefaultMessageLimit()
    {
        var defaultLimit = _configuration.GetValue<int>("AppSettings:DefaultMessageLimit", 100);
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

        // Update appsettings.json
        var appSettingsPath = Path.Combine(_environment.ContentRootPath, "appsettings.json");
        var json = await System.IO.File.ReadAllTextAsync(appSettingsPath);
        
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        
        var settings = new Dictionary<string, object>();
        foreach (var property in root.EnumerateObject())
        {
            if (property.Name == "AppSettings")
            {
                var appSettings = new Dictionary<string, object>();
                foreach (var appProperty in property.Value.EnumerateObject())
                {
                    if (appProperty.Name == "DefaultMessageLimit")
                    {
                        appSettings[appProperty.Name] = request.DefaultMessageLimit;
                    }
                    else
                    {
                        appSettings[appProperty.Name] = JsonSerializer.Deserialize<object>(appProperty.Value.GetRawText())!;
                    }
                }
                settings[property.Name] = appSettings;
            }
            else
            {
                settings[property.Name] = JsonSerializer.Deserialize<object>(property.Value.GetRawText())!;
            }
        }

        var options = new JsonSerializerOptions { WriteIndented = true };
        var updatedJson = JsonSerializer.Serialize(settings, options);
        await System.IO.File.WriteAllTextAsync(appSettingsPath, updatedJson);

        return Ok(new { message = "Default message limit updated successfully" });
    }

    public class SetDefaultMessageLimitRequest
    {
        public int DefaultMessageLimit { get; set; }
    }
}

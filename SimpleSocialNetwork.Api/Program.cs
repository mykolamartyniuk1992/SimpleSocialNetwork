using Microsoft.AspNetCore.HttpOverrides;
using SimpleSocialNetwork.Api.Services;
using Microsoft.EntityFrameworkCore;
using SimpleSocialNetwork;
using SimpleSocialNetwork.Data;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Models;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Service.ModelProfileService;

var builder = WebApplication.CreateBuilder(args);

// Поддержка кастомного окружения Local
var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
if (string.Equals(env, "Local", StringComparison.OrdinalIgnoreCase))
{
    builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);
}
builder.Services.AddScoped<EmailService>();

builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add(new SimpleSocialNetwork.LogExceptionFilterAttribute());
});

// DbContext
builder.Services.AddDbContext<SimpleSocialNetworkDbContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Репозитории/сервисы
builder.Services.AddScoped<IRepository<ModelProfile>, ModelProfileRepository>();
builder.Services.AddScoped<IRepository<ModelFeed>, ModelFeedRepository>();
builder.Services.AddScoped<IRepository<ModelLike>, ModelLikeRepository>();
builder.Services.AddScoped<IModelProfileService, ModelProfileService>();
builder.Services.AddScoped<IModelFeedService, ModelFeedService>();
builder.Services.AddScoped<IsAuthenticatedAttribute>();

builder.Services.AddSignalR();

// CORS configuration
var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>() 
    ?? new[] { "http://localhost:4200", "http://localhost:60328", "http://127.0.0.1:60328" };

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAngular", policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

// ОТКЛЮЧАЕМ автоматическую 400 ошибку
builder.Services.Configure<Microsoft.AspNetCore.Mvc.ApiBehaviorOptions>(options =>
{
    options.SuppressModelStateInvalidFilter = true;
});

// Tell .NET to accept headers from Caddy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        
    // !!! ВАЖНО: Доверяем всем прокси
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();

// 1. MUST BE FIRST
app.UseForwardedHeaders();

var isLocal = app.Environment.EnvironmentName.Equals(
    "Local",
    StringComparison.OrdinalIgnoreCase);

if (!app.Environment.IsDevelopment() && !isLocal)
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
    // Redirect отключен верно, не включайте его
    // app.UseHttpsRedirection();
}

app.UseRouting();
app.UseCors("AllowAngular");
app.UseStaticFiles();

app.MapControllers();

// Маршруты MVC (для Home контроллера и т.д.)
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<FeedHub>("/hubs/feed").RequireCors("AllowAngular");

app.Run();
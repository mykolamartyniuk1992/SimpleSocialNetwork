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
builder.Services.AddScoped<EmailService>();

builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add(new SimpleSocialNetwork.LogExceptionFilterAttribute());
});

builder.Services.AddControllersWithViews();

builder.Services.AddControllersWithViews();

// DbContext
builder.Services.AddDbContext<SimpleSocialNetworkDbContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Репозитории
builder.Services.AddScoped<IRepository<ModelProfile>, ModelProfileRepository>();
builder.Services.AddScoped<IRepository<ModelFeed>,    ModelFeedRepository>();
builder.Services.AddScoped<IRepository<ModelLike>,    ModelLikeRepository>();

// Сервисы домена
builder.Services.AddScoped<IModelProfileService, ModelProfileService>();
builder.Services.AddScoped<IModelFeedService, ModelFeedService>();

builder.Services.AddScoped<IsAuthenticatedAttribute>();

// SignalR (пример):
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

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseStaticFiles();

app.UseRouting();

app.UseCors("AllowAngular");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<FeedHub>("/hubs/feed").RequireCors("AllowAngular");

app.Run();

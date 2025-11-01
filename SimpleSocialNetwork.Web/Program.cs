using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using SimpleSocialNetwork;
using SimpleSocialNetwork.Data;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Models;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Service.ModelProfileService;

var builder = WebApplication.CreateBuilder(args);

// MVC + твой фильтр логирования
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

var app = builder.Build();

// Авто-миграции
if (Environment.GetEnvironmentVariable("AUTO_MIGRATE") == "true")
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<SimpleSocialNetworkDbContext>();
    db.Database.Migrate();
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// ⚠️ В контейнере HTTPS обычно не нужен (за него отвечает балансер/ingress)
// Если оставить, будет лишний редирект и предупреждения.
//// app.UseHttpsRedirection();

// Статика из wwwroot + выбрать login.html как дефолтный
app.UseDefaultFiles(new DefaultFilesOptions
{
    DefaultFileNames = { "login.html", "index.html" }
});
app.UseStaticFiles();

// Простой health
app.MapGet("/health", () => Results.Ok("OK"));

app.UseRouting();

// Маршруты MVC (если нужны контроллеры)
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// SignalR
app.MapHub<FeedHub>("/hubs/feed");

// SPA-фоллбек: на все неизвестные пути — login.html
app.MapFallbackToFile("login.html");

app.Run();
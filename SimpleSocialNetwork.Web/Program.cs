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

// using Microsoft.EntityFrameworkCore; // если БД
// using SimpleSocialNetwork.Data;     // твой DbContext
// using SimpleSocialNetwork.Hubs;     // если есть SignalR Hub

var builder = WebApplication.CreateBuilder(args);

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

var app = builder.Build();

if (Environment.GetEnvironmentVariable("AUTO_MIGRATE") == "true")
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<SimpleSocialNetworkDbContext>();
    db.Database.Migrate(); // применит все pending-миграции, создаст БД если её нет
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();
// app.UseAuthentication();
// app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<FeedHub>("/hubs/feed");

app.Run();

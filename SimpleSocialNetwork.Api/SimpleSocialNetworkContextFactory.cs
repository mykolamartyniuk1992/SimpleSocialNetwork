using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using SimpleSocialNetwork.Data;
using System.IO;

namespace SimpleSocialNetwork.Api
{
    public class SimpleSocialNetworkContextFactory : IDesignTimeDbContextFactory<SimpleSocialNetworkDbContext>
    {
        public SimpleSocialNetworkDbContext CreateDbContext(string[] args)
        {
            // 1. Читаем конфигурацию из текущей директории
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")}.json", optional: true)
                .Build();

            // 2. Создаем опции для DbContext
            var builder = new DbContextOptionsBuilder<SimpleSocialNetworkDbContext>();
            var connectionString = configuration.GetConnectionString("Default");

            builder.UseSqlServer(connectionString);

            // 3. Возвращаем новый контекст
            return new SimpleSocialNetworkDbContext(builder.Options);
        }
    }
}
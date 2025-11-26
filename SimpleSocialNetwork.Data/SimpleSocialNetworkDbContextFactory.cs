using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using System.IO;

namespace SimpleSocialNetwork.Data;

public class SimpleSocialNetworkDbContextFactory : IDesignTimeDbContextFactory<SimpleSocialNetworkDbContext>
{
    public SimpleSocialNetworkDbContext CreateDbContext(string[] args)
    {
        // Build configuration from the API project's appsettings
        var configuration = new ConfigurationBuilder()
            .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(), "../SimpleSocialNetwork.Api"))
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .Build();

        var optionsBuilder = new DbContextOptionsBuilder<SimpleSocialNetworkDbContext>();
        var connectionString = configuration.GetConnectionString("Default");
        
        optionsBuilder.UseSqlServer(connectionString);

        return new SimpleSocialNetworkDbContext(optionsBuilder.Options);
    }
}

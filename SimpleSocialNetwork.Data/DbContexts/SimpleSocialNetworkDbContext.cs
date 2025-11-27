using Microsoft.EntityFrameworkCore;
using SimpleSocialNetwork.Data.EntityConfigurations;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data;

public class SimpleSocialNetworkDbContext : DbContext
{
    public SimpleSocialNetworkDbContext(DbContextOptions<SimpleSocialNetworkDbContext> options)
        : base(options) { }

    // Таблицы
    public DbSet<ModelProfile> profiles => Set<ModelProfile>();
    public DbSet<ModelFeed>    feed     => Set<ModelFeed>();
    public DbSet<ModelLike>    likes    => Set<ModelLike>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Применяем конфигурации сущностей
        // Убедитесь, что классы конфигураций (ConfigProfile и др.) существуют в проекте
        modelBuilder.ApplyConfiguration(new ConfigProfile());
        modelBuilder.ApplyConfiguration(new ConfigFeed());
        modelBuilder.ApplyConfiguration(new ConfigLike());
    }
}
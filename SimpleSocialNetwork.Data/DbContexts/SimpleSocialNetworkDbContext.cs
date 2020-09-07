using System.Data.Entity;
using SimpleSocialNetwork.Data.EntityConfigurations;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.DbContexts
{
    public class SimpleSocialNetworkDbContext : DbContext
    {
        public SimpleSocialNetworkDbContext() : base("name=SimpleSocialNetworkConnectionString")
        {
        }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Configurations.Add(new ConfigProfile());
            modelBuilder.Configurations.Add(new ConfigFeed());
            modelBuilder.Configurations.Add(new ConfigLike());
        }

        public DbSet<ModelProfile> profiles { get; set; }
        public DbSet<ModelFeed> feed { get; set; }
        public DbSet<ModelLike> likes { get; set; }
    }
}
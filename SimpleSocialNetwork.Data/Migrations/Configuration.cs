using System.Data.Entity.Migrations;
using SimpleSocialNetwork.Data.DbContexts;

namespace SimpleSocialNetwork.Data.Migrations
{
    internal sealed class Configuration : DbMigrationsConfiguration<SimpleSocialNetworkDbContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = false;
            ContextKey = "SimpleSocialNetwork.Data.DbContexts.SimpleSocialNetworkDbContext";
        }

        protected override void Seed(SimpleSocialNetworkDbContext context)
        {
            //  This method will be called after migrating to the latest version.

            //  You can use the DbSet<T>.AddOrUpdate() helper extension method 
            //  to avoid creating duplicate seed data.
        }
    }
}

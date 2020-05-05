namespace SimpleSocialNetwork.Migrations
{
    using System;
    using System.Data.Entity;
    using System.Data.Entity.Migrations;
    using System.Linq;

    internal sealed class Configuration : DbMigrationsConfiguration<SimpleSocialNetwork.App_Code.Database.SimpleSocialNetworkDbContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = false;
            ContextKey = "SimpleSocialNetwork.App_Code.Database.SimpleSocialNetworkDbContext";
        }

        protected override void Seed(SimpleSocialNetwork.App_Code.Database.SimpleSocialNetworkDbContext context)
        {
            //  This method will be called after migrating to the latest version.

            //  You can use the DbSet<T>.AddOrUpdate() helper extension method 
            //  to avoid creating duplicate seed data.
        }
    }
}

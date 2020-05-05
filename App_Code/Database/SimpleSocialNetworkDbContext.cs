using SimpleSocialNetwork.App_Code.Database.EntityConfigurations;
using SimpleSocialNetwork.App_Code.Database.Models;
using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database
{
    public class SimpleSocialNetworkDbContext : DbContext
    {
        public SimpleSocialNetworkDbContext() : base("SimpleSocialNetworkConnectionString") { }

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
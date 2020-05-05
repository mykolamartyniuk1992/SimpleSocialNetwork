using SimpleSocialNetwork.App_Code.Database.Models;
using System;
using System.Collections.Generic;
using System.Data.Entity.ModelConfiguration;
using System.Linq;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database.EntityConfigurations
{
    public class ConfigLike : EntityTypeConfiguration<ModelLike>
    {
        public ConfigLike()
        {
            ToTable("likes");
            Property(like => like.Id).HasColumnName("id");
            HasKey(like => like.Id);
            Property(like => like.FeedId).HasColumnName("feed_id");
            HasRequired(like => like.Feed).WithMany(feed => feed.Likes).HasForeignKey(like => like.FeedId).WillCascadeOnDelete(false);
            Property(like => like.ProfileId).HasColumnName("profile_id");
            HasRequired(like => like.Profile).WithMany(profile => profile.Likes).HasForeignKey(like => like.ProfileId).WillCascadeOnDelete(false);
        }
    }
}
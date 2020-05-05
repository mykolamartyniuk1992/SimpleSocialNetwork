using System.Data.Entity.ModelConfiguration;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.EntityConfigurations
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
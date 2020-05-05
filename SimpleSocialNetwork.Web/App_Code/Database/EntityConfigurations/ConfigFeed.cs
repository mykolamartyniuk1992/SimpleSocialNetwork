using System.Data.Entity.ModelConfiguration;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Database.EntityConfigurations
{
    public class ConfigFeed : EntityTypeConfiguration<ModelFeed>
    {
        public ConfigFeed()
        {
            ToTable("feed");
            Property(feed => feed.Id).HasColumnName("id");
            HasKey(feed => feed.Id);
            Property(feed => feed.ParentId).HasColumnName("parent_id").IsOptional();
            HasMany(feed => feed.Children).WithOptional(feed => feed.Parent).HasForeignKey(feed => feed.ParentId).WillCascadeOnDelete(false);
            Property(feed => feed.ProfileId).HasColumnName("profile_id");
            Property(feed => feed.Text).HasColumnName("text");
            Property(feed => feed.DateAdd).HasColumnName("date_add");
            HasRequired(feed => feed.Profile);
        }
    }
}
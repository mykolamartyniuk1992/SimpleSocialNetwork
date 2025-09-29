using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SimpleSocialNetwork.Models;  // где лежит ModelLike, ModelFeed, ModelProfile

namespace SimpleSocialNetwork.Data.EntityConfigurations;

public sealed class ConfigLike : IEntityTypeConfiguration<ModelLike>
{
    public void Configure(EntityTypeBuilder<ModelLike> e)
    {
        e.ToTable("likes");

        e.HasKey(l => l.Id);
        e.Property(l => l.Id).HasColumnName("id");

        e.Property(l => l.FeedId).HasColumnName("feed_id");
        e.Property(l => l.ProfileId).HasColumnName("profile_id");

        e.HasOne(l => l.Feed)
            .WithMany(f => f.Likes)
            .HasForeignKey(l => l.FeedId)
            .OnDelete(DeleteBehavior.NoAction);   // = без каскада (как WillCascadeOnDelete(false))

        e.HasOne(l => l.Profile)
            .WithMany(p => p.Likes)
            .HasForeignKey(l => l.ProfileId)
            .OnDelete(DeleteBehavior.NoAction);

        // Опционально (полезно для планов):
        e.HasIndex(l => l.FeedId);
        e.HasIndex(l => l.ProfileId);
    }
}
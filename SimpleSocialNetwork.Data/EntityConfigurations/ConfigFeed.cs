using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SimpleSocialNetwork.Models;   // где лежит ModelFeed / ModelProfile

namespace SimpleSocialNetwork.Data.EntityConfigurations;

public sealed class ConfigFeed : IEntityTypeConfiguration<ModelFeed>
{
    public void Configure(EntityTypeBuilder<ModelFeed> e)
    {
        e.ToTable("feed");

        e.HasKey(f => f.Id);
        e.Property(f => f.Id).HasColumnName("id");

        // parent_id (nullable) — самоссылка (Many Children -> One Parent) без каскада
        e.Property(f => f.ParentId).HasColumnName("parent_id");
        e.HasOne(f => f.Parent)
            .WithMany(p => p.Children)
            .HasForeignKey(f => f.ParentId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.NoAction);

        // связь с профилем (как в EF6: HasRequired; я отключаю каскад,
        // чтобы не удалялись посты при удалении профиля, как у тебя сделано для likes)
        e.Property(f => f.ProfileId).HasColumnName("profile_id");
        e.HasOne(f => f.Profile)
            .WithMany()            // у Profile должна быть коллекция Feeds; если нет — WithMany()
            .HasForeignKey(f => f.ProfileId)
            .OnDelete(DeleteBehavior.NoAction);

        e.Property(f => f.Text).HasColumnName("text");

        e.Property(f => f.DateAdd)
            .HasColumnName("date_add")
            .HasColumnType("datetime2")
            .HasDefaultValueSql("SYSUTCDATETIME()");

        // Индексы (по желанию, ускоряют выборки)
        e.HasIndex(f => f.ParentId);
        e.HasIndex(f => f.ProfileId);
    }
}
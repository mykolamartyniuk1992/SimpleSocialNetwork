using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data;

public sealed class ConfigProfile : IEntityTypeConfiguration<ModelProfile>
{
    public void Configure(EntityTypeBuilder<ModelProfile> e)
    {
        e.ToTable("profiles");
        e.HasKey(x => x.Id);
        e.Property(x => x.Id).ValueGeneratedOnAdd();

        e.Property(x => x.Email).IsRequired().HasMaxLength(256);
        e.Property(x => x.Name).IsRequired().HasMaxLength(200);
        e.Property(x => x.Password).IsRequired().HasMaxLength(256);
        e.Property(x => x.Token).HasMaxLength(256);
        e.Property(x => x.Verified).HasDefaultValue(false);
        e.Property(x => x.IsAdmin).HasDefaultValue(false);
        e.Property(x => x.IsSystemUser).HasDefaultValue(false);
        e.Property(x => x.MessagesLeft).IsRequired(false);
        e.Property(x => x.PhotoPath).HasMaxLength(500);

        e.Property(x => x.DateAdd)
            .HasColumnType("datetime2")
            .HasDefaultValueSql("SYSUTCDATETIME()");

        // Unique filtered index: only one IsAdmin=true allowed
        e.HasIndex(x => x.IsAdmin)
            .IsUnique()
            .HasFilter("[IsAdmin] = 1");
    }
}
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

        e.Property(x => x.Name).IsRequired().HasMaxLength(200);
        e.Property(x => x.Password).IsRequired().HasMaxLength(256);
        e.Property(x => x.Token).HasMaxLength(256);

        e.Property(x => x.DateAdd)
            .HasColumnType("datetime2")
            .HasDefaultValueSql("SYSUTCDATETIME()");
    }
}
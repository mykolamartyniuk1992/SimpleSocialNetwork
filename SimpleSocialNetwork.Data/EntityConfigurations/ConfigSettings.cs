using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data;

public sealed class ConfigSettings : IEntityTypeConfiguration<ModelSettings>
{
    public void Configure(EntityTypeBuilder<ModelSettings> e)
    {
        e.ToTable("settings");
        e.HasKey(x => x.Id);
        e.Property(x => x.Id).ValueGeneratedOnAdd();
        e.Property(x => x.DefaultMessageLimit).IsRequired();
    }
}

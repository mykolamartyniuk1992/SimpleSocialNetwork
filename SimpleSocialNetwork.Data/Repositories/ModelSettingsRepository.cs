using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelSettingsRepository : Repository<ModelSettings>
    {
        public ModelSettingsRepository(SimpleSocialNetworkDbContext ctx) : base(ctx) { }
    }
}

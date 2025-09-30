using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelProfileRepository : Repository<ModelProfile>
    {
        public ModelProfileRepository(SimpleSocialNetworkDbContext ctx) : base(ctx) { }
    }
}
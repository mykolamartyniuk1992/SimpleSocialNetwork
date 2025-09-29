using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelLikeRepository : Repository<ModelLike>
    {
        public ModelLikeRepository(SimpleSocialNetworkDbContext ctx) : base(ctx) { }
    }
}
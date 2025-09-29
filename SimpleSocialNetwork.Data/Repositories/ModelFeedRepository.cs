using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelFeedRepository : Repository<ModelFeed>
    {
        public ModelFeedRepository(SimpleSocialNetworkDbContext ctx) : base(ctx) { }
        
        public void RecoursiveDelete(int feedId)
        {
            var modelFeed = context.feed.FirstOrDefault(f => f.Id == feedId);
            RecoursiveDelete(modelFeed, context);
            context.SaveChanges();
        }
        
        private void RecoursiveDelete(ModelFeed parent, SimpleSocialNetworkDbContext context)
        {
            if (parent.Children.Count != 0)
            {
                foreach (var child in parent.Children.ToList())
                {
                    RecoursiveDelete(child, context);
                }
            }
            context.likes.RemoveRange(context.likes.Where(l => l.FeedId == parent.Id));
            context.feed.Remove(parent);
        }
    }
}
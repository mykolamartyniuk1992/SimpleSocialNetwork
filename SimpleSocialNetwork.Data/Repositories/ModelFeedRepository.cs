using SimpleSocialNetwork.Models;
using System.Linq;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelFeedRepository : Repository<ModelFeed>
    {
        public ModelFeedRepository(SimpleSocialNetworkDbContext ctx) : base(ctx) { }
        
        public void RecoursiveDelete(int feedId)
        {
            var modelFeed = context.feed.FirstOrDefault(f => f.Id == feedId);
            if (modelFeed == null) return;
            RecoursiveDelete(modelFeed, context);
            context.SaveChanges();
        }
        
        private void RecoursiveDelete(ModelFeed parent, SimpleSocialNetworkDbContext context)
        {
            // Manually load children from database instead of relying on navigation property
            var children = context.feed.Where(f => f.ParentId == parent.Id).ToList();
            
            if (children.Any())
            {
                foreach (var child in children)
                {
                    RecoursiveDelete(child, context);
                }
            }
            
            // Delete likes for this feed
            var likes = context.likes.Where(l => l.FeedId == parent.Id).ToList();
            context.likes.RemoveRange(likes);
            
            // Delete the feed itself
            context.feed.Remove(parent);
        }
    }
}
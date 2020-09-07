using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelFeedRepository : Repository<ModelFeed>
    {
        public override ModelFeed Add(ModelFeed model)
        {
            context.feed.Add(model);
            context.SaveChanges();
            return model;
        }

        public override void Delete(ModelFeed model)
        {
            context.feed.Attach(model);
            context.feed.Remove(model);
            context.SaveChanges();
        }

        public override void Update(ModelFeed model)
        {
            context.feed.Attach(model);
            context.Entry(model).State = EntityState.Modified;
            context.SaveChanges();
        }

        public override ModelFeed FirstOrDefault(Expression<Func<ModelFeed, bool>> predicate)
        {
            return context.feed.FirstOrDefault(predicate);
        }

        public override IQueryable<ModelFeed> GetAll()
        {
            return context.feed;
        }

        public override IQueryable<ModelFeed> Where(Expression<Func<ModelFeed, bool>> predicate)
        {
            return context.feed.Where(predicate);
        }

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

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
    public class ModelFeedRepository : IRepository<ModelFeed>
    {
        public ModelFeed Add(ModelFeed model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.feed.Add(model);
                context.SaveChanges();
                return model;
            }
        }

        public void Delete(ModelFeed model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.feed.Attach(model);
                context.feed.Remove(model);
                context.SaveChanges();
            }
        }

        public void Update(ModelFeed model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.feed.Attach(model);
                context.Entry(model).State = EntityState.Modified;
            }
        }

        public ModelFeed FirstOrDefault(Expression<Func<ModelFeed, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.feed.FirstOrDefault(predicate);
            }
        }

        public IEnumerable<ModelFeed> GetAll()
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.feed.ToList();
            }
        }

        public IEnumerable<ModelFeed> Where(Expression<Func<ModelFeed, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.feed.Where(predicate);
            }
        }

        public void RecoursiveDelete(int feedId)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var modelFeed = context.feed.FirstOrDefault(f => f.Id == feedId);

                RecoursiveDelete(modelFeed, context);

                context.SaveChanges();
            }
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

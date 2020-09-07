using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Test.Stub
{
    public class ModelFeedRepositoryStub : IRepository<ModelFeed>
    {
        private List<ModelFeed> feeds;

        public ModelFeedRepositoryStub()
        {
            this.feeds = new List<ModelFeed>();
        }

        public ModelFeed Add(ModelFeed model)
        {
            model.Id = this.feeds.Any() ? this.feeds.Count + 1 : 1;
            this.feeds.Add(model);
            return model;
        }

        public void Delete(ModelFeed model)
        {
            this.feeds.Remove(model);
        }

        public void Update(ModelFeed model)
        {
            this.feeds[this.feeds.IndexOf(model)] = model;
        }

        public ModelFeed FirstOrDefault(Expression<Func<ModelFeed, bool>> predicate)
        {
            return this.feeds.FirstOrDefault(predicate.Compile());
        }

        public IQueryable<ModelFeed> Where(Expression<Func<ModelFeed, bool>> predicate)
        {
            return this.feeds.Where(predicate.Compile()).AsQueryable();
        }

        public IQueryable<ModelFeed> GetAll()
        {
            return this.feeds.AsQueryable();
        }
    }
}

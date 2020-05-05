using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Linq.Expressions;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelLikeRepository : IRepository<ModelLike>
    {
        public ModelLike Add(ModelLike model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.likes.Add(model);
                context.SaveChanges();
                return model;
            }
        }

        public void Delete(ModelLike model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.likes.Attach(model);
                context.likes.Remove(model);
                context.SaveChanges();
            }
        }

        public void Update(ModelLike model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.likes.Attach(model);
                context.Entry(model).State = EntityState.Modified;
            }
        }

        public ModelLike FirstOrDefault(Expression<Func<ModelLike, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.likes.FirstOrDefault(predicate);
            }
        }

        public IEnumerable<ModelLike> GetAll()
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.likes.ToList();
            }
        }

        public IEnumerable<ModelLike> Where(Expression<Func<ModelLike, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.likes.Where(predicate);
            }
        }
    }
}

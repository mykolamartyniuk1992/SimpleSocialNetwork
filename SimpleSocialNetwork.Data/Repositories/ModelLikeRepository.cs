using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Linq.Expressions;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public class ModelLikeRepository : Repository<ModelLike>
    {
        public override ModelLike Add(ModelLike model)
        {
            context.likes.Add(model);
            context.SaveChanges();
            return model;
        }

        public override void Delete(ModelLike model)
        {
            context.likes.Attach(model);
            context.likes.Remove(model);
            context.SaveChanges();
        }

        public override void Update(ModelLike model)
        {
            context.likes.Attach(model);
            context.Entry(model).State = EntityState.Modified;
        }

        public override ModelLike FirstOrDefault(Expression<Func<ModelLike, bool>> predicate)
        {
            return context.likes.FirstOrDefault(predicate);
        }

        public override IQueryable<ModelLike> GetAll()
        {
            return context.likes;
        }

        public override IQueryable<ModelLike> Where(Expression<Func<ModelLike, bool>> predicate)
        {
            return context.likes.Where(predicate);
        }
    }
}

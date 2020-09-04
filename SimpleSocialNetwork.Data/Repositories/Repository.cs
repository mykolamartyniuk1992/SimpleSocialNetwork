using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public abstract class Repository<TModel> : IRepository<TModel> where TModel : IEntity
    {
        protected readonly SimpleSocialNetworkDbContext context = new SimpleSocialNetworkDbContext();

        public abstract TModel Add(TModel model);

        public abstract void Delete(TModel model);

        public abstract void Update(TModel model);

        public abstract TModel FirstOrDefault(Expression<Func<TModel, bool>> predicate);
        public abstract IQueryable<TModel> Where(Expression<Func<TModel, bool>> predicate);

        public abstract IQueryable<TModel> GetAll();
    }
}

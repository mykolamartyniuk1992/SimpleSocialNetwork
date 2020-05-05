using SimpleSocialNetwork.Models;
using System;
using System.Collections.Generic;
using System.Linq.Expressions;

namespace SimpleSocialNetwork.Data.Repositories
{
    public interface IRepository<TModel> where TModel : IEntity
    {
        TModel Add(TModel model);

        void Delete(TModel model);

        void Update(TModel model);

        TModel FirstOrDefault(Expression<Func<TModel, bool>> predicate);

        IEnumerable<TModel> Where(Expression<Func<TModel, bool>> predicate);

        IEnumerable<TModel> GetAll();
    }
}

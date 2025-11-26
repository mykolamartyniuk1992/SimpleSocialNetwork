using SimpleSocialNetwork.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;

namespace SimpleSocialNetwork.Data.Repositories
{
    public interface IRepository<T> where T : IEntity
    {
        Task<T> AddAsync(T model, CancellationToken ct = default);

        Task DeleteAsync(T model, CancellationToken ct = default);

        Task UpdateAsync(T model, CancellationToken ct = default);

        Task<T?> FirstOrDefaultAsync(
            Expression<Func<T, bool>> predicate,
            CancellationToken ct = default);

        Task<List<T>> WhereAsync(
            Expression<Func<T, bool>> predicate,
            CancellationToken ct = default);

        Task<List<T>> GetAllAsync(CancellationToken ct = default);

        Task UpdateRangeAsync(IEnumerable<T> models, CancellationToken ct = default);
    }
}

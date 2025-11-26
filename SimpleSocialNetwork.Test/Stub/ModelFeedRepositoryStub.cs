using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Test.Stub
{
    public class ModelFeedRepositoryStub : IRepository<ModelFeed>
    {
        private readonly List<ModelFeed> _feeds = new();

        public Task<ModelFeed> AddAsync(ModelFeed model, CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            if (model == null) throw new ArgumentNullException(nameof(model));

            model.Id = _feeds.Count == 0 ? 1 : _feeds.Max(f => f.Id) + 1;
            _feeds.Add(model);
            return Task.FromResult(model);
        }

        public Task UpdateAsync(ModelFeed model, CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            if (model == null) throw new ArgumentNullException(nameof(model));

            var idx = _feeds.FindIndex(f => f.Id == model.Id);
            if (idx >= 0) _feeds[idx] = model;
            return Task.CompletedTask;
        }

        public Task DeleteAsync(ModelFeed model, CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            if (model == null) throw new ArgumentNullException(nameof(model));

            _feeds.RemoveAll(f => f.Id == model.Id);
            return Task.CompletedTask;
        }

        public Task<ModelFeed> FirstOrDefaultAsync(
            Expression<Func<ModelFeed, bool>> predicate,
            CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            var compiled = predicate.Compile();
            var item = _feeds.FirstOrDefault(compiled);
            return Task.FromResult(item);
        }

        public Task<List<ModelFeed>> GetAllAsync(CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            return Task.FromResult(_feeds.ToList());
        }

        public Task<List<ModelFeed>> WhereAsync(
            Expression<Func<ModelFeed, bool>> predicate,
            CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            var compiled = predicate.Compile();
            return Task.FromResult(_feeds.Where(compiled).ToList());
        }

        public Task<bool> AnyAsync(
            Expression<Func<ModelFeed, bool>> predicate,
            CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            var compiled = predicate.Compile();
            return Task.FromResult(_feeds.Any(compiled));
        }

        public Task UpdateRangeAsync(IEnumerable<ModelFeed> models, CancellationToken ct = default)
        {
            if (models == null) throw new ArgumentNullException(nameof(models));
            ct.ThrowIfCancellationRequested();
            foreach (var model in models)
            {
                var idx = _feeds.FindIndex(f => f.Id == model.Id);
                if (idx >= 0) _feeds[idx] = model;
            }
            return Task.CompletedTask;
        }
    }
}

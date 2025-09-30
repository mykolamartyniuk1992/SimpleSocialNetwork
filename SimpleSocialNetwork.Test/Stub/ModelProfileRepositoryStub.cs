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
    public class ModelProfileRepositoryStub : IRepository<ModelProfile>
    {
        private readonly List<ModelProfile> _profiles = new();

        public Task<ModelProfile> AddAsync(ModelProfile model, CancellationToken ct = default)
        {
            if (model == null) throw new ArgumentNullException(nameof(model));
            ct.ThrowIfCancellationRequested();

            model.Id = _profiles.Count == 0 ? 1 : _profiles.Max(p => p.Id) + 1;
            _profiles.Add(model);
            return Task.FromResult(model);
        }

        public Task UpdateAsync(ModelProfile model, CancellationToken ct = default)
        {
            if (model == null) throw new ArgumentNullException(nameof(model));
            ct.ThrowIfCancellationRequested();

            var idx = _profiles.FindIndex(p => p.Id == model.Id);
            if (idx >= 0) _profiles[idx] = model;
            return Task.CompletedTask;
        }

        public Task DeleteAsync(ModelProfile model, CancellationToken ct = default)
        {
            if (model == null) throw new ArgumentNullException(nameof(model));
            ct.ThrowIfCancellationRequested();

            _profiles.RemoveAll(p => p.Id == model.Id);
            return Task.CompletedTask;
        }

        public Task<ModelProfile?> FirstOrDefaultAsync(
            Expression<Func<ModelProfile, bool>> predicate,
            CancellationToken ct = default)
        {
            if (predicate == null) throw new ArgumentNullException(nameof(predicate));
            ct.ThrowIfCancellationRequested();

            var compiled = predicate.Compile();
            var item = _profiles.FirstOrDefault(compiled);
            return Task.FromResult(item);
        }

        public Task<List<ModelProfile>> GetAllAsync(CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            return Task.FromResult(_profiles.ToList());
        }

        public Task<List<ModelProfile>> WhereAsync(
            Expression<Func<ModelProfile, bool>> predicate,
            CancellationToken ct = default)
        {
            if (predicate == null) throw new ArgumentNullException(nameof(predicate));
            ct.ThrowIfCancellationRequested();

            var compiled = predicate.Compile();
            return Task.FromResult(_profiles.Where(compiled).ToList());
        }

        public Task<bool> AnyAsync(
            Expression<Func<ModelProfile, bool>> predicate,
            CancellationToken ct = default)
        {
            if (predicate == null) throw new ArgumentNullException(nameof(predicate));
            ct.ThrowIfCancellationRequested();

            var compiled = predicate.Compile();
            return Task.FromResult(_profiles.Any(compiled));
        }
    }
}

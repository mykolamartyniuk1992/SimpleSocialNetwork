using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Data.Repositories
{
    public abstract class Repository<T> : IRepository<T> where T : class, IEntity
    {
        protected readonly SimpleSocialNetworkDbContext context;
        protected DbSet<T> Set => context.Set<T>();

        protected Repository(SimpleSocialNetworkDbContext ctx) => context = ctx;

        public virtual async Task<T> AddAsync(T model, CancellationToken ct = default)
        {
            var entry = await Set.AddAsync(model, ct);
            await context.SaveChangesAsync(ct);
            return entry.Entity; // (или просто model)
        }

        public virtual async Task UpdateAsync(T model, CancellationToken ct = default)
        {
            Set.Update(model);
            await context.SaveChangesAsync(ct);
        }

        public virtual async Task UpdateRangeAsync(IEnumerable<T> models, CancellationToken ct = default)
        {
            try
            {
                var modelsList = models.ToList();
                Console.WriteLine($"[UpdateRangeAsync] Updating {modelsList.Count} entities");
                
                Set.UpdateRange(modelsList);
                Console.WriteLine($"[UpdateRangeAsync] UpdateRange called, now saving changes");
                
                await context.SaveChangesAsync(ct);
                Console.WriteLine($"[UpdateRangeAsync] SaveChanges completed successfully");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UpdateRangeAsync] ERROR: {ex.Message}");
                Console.WriteLine($"[UpdateRangeAsync] Stack Trace: {ex.StackTrace}");
                Console.WriteLine($"[UpdateRangeAsync] Inner Exception: {ex.InnerException?.Message}");
                Console.WriteLine($"[UpdateRangeAsync] Inner Stack Trace: {ex.InnerException?.StackTrace}");
                throw;
            }
        }

        public virtual async Task DeleteAsync(T model, CancellationToken ct = default)
        {
            // Find if there's already a tracked entity with the same key
            var existingEntry = context.ChangeTracker.Entries<T>()
                .FirstOrDefault(e => e.Entity.Id == model.Id);
            
            if (existingEntry != null)
            {
                // Use the already tracked entity
                Set.Remove(existingEntry.Entity);
            }
            else
            {
                // Entity is not tracked, attach and remove it
                Set.Attach(model);
                Set.Remove(model);
            }
            
            await context.SaveChangesAsync(ct);
        }

        public virtual Task<T?> FirstOrDefaultAsync(
            Expression<Func<T, bool>> predicate,
            CancellationToken ct = default)
            => Set.AsNoTracking().FirstOrDefaultAsync(predicate, ct);

        public virtual Task<List<T>> GetAllAsync(CancellationToken ct = default)
            => Set.AsNoTracking().ToListAsync(ct);

        public virtual Task<List<T>> WhereAsync(
            Expression<Func<T, bool>> predicate,
            CancellationToken ct = default)
            => Set.AsNoTracking().Where(predicate).ToListAsync(ct);

        // Удобно, когда нужно строить сложные запросы наверху
        public virtual IQueryable<T> AsQueryable(bool noTracking = true)
            => noTracking ? Set.AsNoTracking() : Set.AsQueryable();

        public virtual Task<bool> AnyAsync(
            Expression<Func<T, bool>> predicate,
            CancellationToken ct = default)
            => Set.AsNoTracking().AnyAsync(predicate, ct);
    }
}

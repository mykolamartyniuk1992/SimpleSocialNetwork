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
    public class ModelProfileRepository : IRepository<ModelProfile>
    {
        public ModelProfile Add(ModelProfile model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.profiles.Add(model);
            }
        }

        public void Delete(ModelProfile model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.profiles.Attach(model);
                context.profiles.Remove(model);
                context.SaveChanges();
            }
        }

        public void Update(ModelProfile model)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                context.profiles.Attach(model);
                context.Entry(model).State = EntityState.Modified;
                context.SaveChanges();
            }
        }

        public ModelProfile FirstOrDefault(Expression<Func<ModelProfile, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.profiles.FirstOrDefault(predicate);
            }
        }

        public IEnumerable<ModelProfile> GetAll()
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.profiles.ToList();
            }
        }

        public IEnumerable<ModelProfile> Where(Expression<Func<ModelProfile, bool>> predicate)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                return context.profiles.Where(predicate);
            }
        }
    }
}

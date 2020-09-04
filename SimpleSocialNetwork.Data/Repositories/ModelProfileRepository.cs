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
    public class ModelProfileRepository : Repository<ModelProfile>
    {
        public override ModelProfile Add(ModelProfile model)
        {
            var modelProfile = context.profiles.Add(model);
            context.SaveChanges();
            return modelProfile;
        }

        public override void Delete(ModelProfile model)
        {
            context.profiles.Attach(model);
            context.profiles.Remove(model);
            context.SaveChanges();
        }

        public override void Update(ModelProfile model)
        {
            context.profiles.Attach(model);
            context.Entry(model).State = EntityState.Modified;
            context.SaveChanges();
        }

        public override ModelProfile FirstOrDefault(Expression<Func<ModelProfile, bool>> predicate)
        {
            return context.profiles.FirstOrDefault(predicate);
        }

        public override IQueryable<ModelProfile> GetAll()
        {
            return context.profiles;
        }

        public override IQueryable<ModelProfile> Where(Expression<Func<ModelProfile, bool>> predicate)
        {
            return context.profiles.Where(predicate);
        }
    }
}

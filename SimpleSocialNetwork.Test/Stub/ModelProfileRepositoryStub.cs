using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Test.Stub
{
    public class ModelProfileRepositoryStub : IRepository<ModelProfile>
    {
        private List<ModelProfile> profiles;

        public ModelProfileRepositoryStub()
        {
            this.profiles = new List<ModelProfile>();
        }

        public ModelProfile Add(ModelProfile model)
        {
            model.Id = this.profiles.Any() ? this.profiles.Count + 1 : 1;
            this.profiles.Add(model);
            return model;
        }

        public void Delete(ModelProfile model)
        {
            this.profiles.Remove(model);
        }

        public void Update(ModelProfile model)
        {
            this.profiles[this.profiles.IndexOf(model)] = model;
        }

        public ModelProfile FirstOrDefault(Expression<Func<ModelProfile, bool>> predicate)
        {
            return this.profiles.FirstOrDefault(predicate.Compile());
        }

        public IQueryable<ModelProfile> Where(Expression<Func<ModelProfile, bool>> predicate)
        {
            return this.profiles.Where(predicate.Compile()).AsQueryable();
        }

        public IQueryable<ModelProfile> GetAll()
        {
            return this.profiles.AsQueryable();
        }
    }
}

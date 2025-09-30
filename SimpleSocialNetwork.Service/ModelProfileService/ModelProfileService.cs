using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelProfileService
{
    public class ModelProfileService : IModelProfileService
    {
        private IRepository<ModelProfile> profileRepo;

        public ModelProfileService(IRepository<ModelProfile> profileRepo)
        {
            this.profileRepo = profileRepo;
        }
        
        public Guid Login(string name, string password)
        {
            var profileFounded = profileRepo.FirstOrDefaultAsync(p => p.Name == name && p.Password == password).Result;
            if (profileFounded != null)
            {
                var guid = Guid.NewGuid();
                profileFounded.Token = guid.ToString();
                profileRepo.UpdateAsync(profileFounded);
                return guid;
            }
            throw new Exception("user not found");
        }

        public bool IsRegistered(string name, string password)
        {
            var profileFounded = profileRepo.FirstOrDefaultAsync(p => p.Name == name && p.Password == password).Result;
            return profileFounded != null;
        }

        public async Task RegisterAsync(DtoProfile newProfile)
        {
            ModelProfile modelProfile = new ModelProfile()
            {
                DateAdd = DateTime.Now,
                Name = newProfile.name,
                Password = newProfile.password
            };
            await profileRepo.AddAsync(modelProfile);
        }

        public bool IsAuthenticated(string name, string token)
        {
            var profileFounded = profileRepo.FirstOrDefaultAsync(p => p.Name == name && p.Token == token).Result;
            return profileFounded != null;
        }
    }
}

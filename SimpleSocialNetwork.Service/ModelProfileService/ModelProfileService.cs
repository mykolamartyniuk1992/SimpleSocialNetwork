using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelProfileService
{
    public class ModelProfileService : IModelProfileService
    {
        public Guid Login(string name, string password)
        {
            var profileRepo = new ModelProfileRepository();
            var profileFounded = profileRepo.FirstOrDefault(p => p.Name == name && p.Password == password);
            if (profileFounded != null)
            {
                var guid = Guid.NewGuid();
                profileFounded.Token = guid.ToString();
                profileRepo.Update(profileFounded);
                return guid;
            }
            throw new Exception("user not found");
        }

        public bool IsRegistered(string name, string password)
        {
            var profileRepo = new ModelProfileRepository();
            var profileFounded = profileRepo.FirstOrDefault(p => p.Name == name && p.Password == password);
            return profileFounded != null;
        }

        public void Register(DtoProfile newProfile)
        {
            var profileRepo = new ModelProfileRepository();
            ModelProfile modelProfile = new ModelProfile()
            {
                DateAdd = DateTime.Now,
                Name = newProfile.name,
                Password = newProfile.password
            };
            profileRepo.Add(modelProfile);
        }

        public bool IsAuthenticated(string name, string token)
        {
            var profileRepo = new ModelProfileRepository();
            var profileFounded = profileRepo.FirstOrDefault(p => p.Name == name && p.Token == token);
            return profileFounded != null;
        }
    }
}

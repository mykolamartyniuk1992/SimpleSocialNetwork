using SimpleSocialNetwork.Dto;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Service.ModelProfileService
{
    public interface IModelProfileService
    {
        Guid Login(string name, string password);

        bool IsRegistered(string name, string password);

        Task RegisterAsync(DtoProfile newProfile);

        bool IsAuthenticated(string name, string token);
    }
}

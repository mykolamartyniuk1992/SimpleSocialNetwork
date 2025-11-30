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

        Task<SimpleSocialNetwork.Models.ModelSettings> GetSettingsAsync();
        
        
        Task<int> GetDefaultMessageLimitAsync();
        Task SetDefaultMessageLimitAsync(int newLimit);
        Task<(int Id, string Token, bool IsAdmin, string Name, string PhotoPath, bool Verified, int? MessagesLeft)?> LoginAsync(string email, string password);

        bool IsRegistered(string name, string password);

        Task<(int Id, string Token, bool IsAdmin, string Name, string PhotoPath, bool Verified, int? MessagesLeft, string VerifyHash)> RegisterAsync(DtoProfile newProfile);

        bool IsAuthenticated(string name, string token);

        int? GetUserIdByToken(string token);

        bool GetIsAdminByToken(string token);

        Task<(string Email, string Password)?> GetAdminCredentialsAsync();
        Task<(string Email, string Password)?> GetTestUserCredentialsAsync();

        Task UpdatePhotoPathAsync(int profileId, string photoPath);

        Task<string> GetPhotoPathAsync(int profileId);

        Task UpdateProfileNameAsync(int profileId, string name);

        Task<bool> ChangePasswordAsync(int profileId, string oldPassword, string newPassword);

        Task<string> UpdateProfileAsync(int profileId, string name = null, string photoPath = null);

        Task SetVerifiedAsync(int profileId, bool verified);

        Task<string> SetVerifiedAndClearTokenAsync(int profileId, bool verified);

        Task<int?> GetMessagesLeftAsync(int profileId);

        Task<(bool canPost, int? messagesLeft)> DecrementMessagesLeftAsync(int profileId);

        Task SetMessagesLeftAsync(int profileId, int? messagesLeft);

        Task UpdateAllUnverifiedMessagesLeftAsync(int messageLimit);

        Task UpdateUserMessageLimitAsync(int profileId, int messageLimit);

        Task<List<UserDto>> GetAllUsersAsync();

        Task<string> ClearUserTokenAsync(int profileId);

        Task<string> GetUserTokenAsync(int profileId);

        Task DeleteUserAsync(int profileId);
        
        Task<bool> VerifyEmailAsync(string email, string hash);
    }

    public class UserDto
    {
        public int Id { get; set; }
        public string Email { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string PhotoPath { get; set; }
        public bool IsSystemUser { get; set; }
        public bool IsAdmin { get; set; }
        public bool Verified { get; set; }
        public int? MessagesLeft { get; set; }
    }
}

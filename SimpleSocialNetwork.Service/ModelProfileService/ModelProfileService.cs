using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelProfileService
{
    public class ModelProfileService : IModelProfileService
    {
        private IRepository<ModelSettings> settingsRepo;
        private IRepository<ModelProfile> profileRepo;
        private IRepository<ModelFeed> feedRepo;
        private IRepository<ModelLike> likeRepo;
        private readonly IConfiguration _configuration;

        public ModelProfileService(
            IRepository<ModelProfile> profileRepo,
            IRepository<ModelFeed> feedRepo,
            IRepository<ModelLike> likeRepo,
            IRepository<ModelSettings> settingsRepo,
            IConfiguration configuration)
        {
            this.profileRepo = profileRepo;
            this.feedRepo = feedRepo;
            this.likeRepo = likeRepo;
            _configuration = configuration;
            this.settingsRepo = settingsRepo;
        }

        public async Task<SimpleSocialNetwork.Models.ModelSettings> GetSettingsAsync()
        {
            // Обычно в таблице settings только одна строка с Id = 1
            return await settingsRepo.FirstOrDefaultAsync(s => s.Id == 1);
        }

        public async Task<int> GetDefaultMessageLimitAsync()
        {
            var settings = await settingsRepo.FirstOrDefaultAsync(s => s.Id == 1);
            if (settings == null)
                throw new InvalidOperationException("Default message limit is not set in the database.");
            return settings.DefaultMessageLimit;
        }

        public async Task SetDefaultMessageLimitAsync(int newLimit)
        {
            var settings = await settingsRepo.FirstOrDefaultAsync(s => s.Id == 1);
            if (settings != null)
            {
                settings.DefaultMessageLimit = newLimit;
                await settingsRepo.UpdateAsync(settings);
            }
        }

        public async Task<bool> VerifyEmailAsync(string email, string hash)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Email == email && p.VerifyHash == hash);
            if (profile == null)
                return false;
            profile.Verified = true;
            await profileRepo.UpdateAsync(profile);
            return true;
        }

        public async Task<(int Id, string Token, bool IsAdmin, string Name, string PhotoPath, bool Verified, int? MessagesLeft)?> LoginAsync(string email, string password)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Email == email);
            if (profile != null)
            {
                // System users have plain text passwords for development, regular users have hashed passwords
                bool passwordValid = profile.IsSystemUser
                    ? profile.Password == password
                    : PasswordHelper.VerifyPassword(password, profile.Password);

                if (passwordValid)
                {
                    var token = Guid.NewGuid().ToString();
                    profile.Token = token;

                    // Auto-verify admin in development
                    if (profile.IsAdmin && !profile.Verified)
                    {
                        profile.Verified = true;
                    }

                    await profileRepo.UpdateAsync(profile);
                    return (profile.Id, token, profile.IsAdmin, profile.Name, profile.PhotoPath, profile.Verified, profile.MessagesLeft);
                }
            }
            return null;
        }

        public bool IsRegistered(string name, string password)
        {
            var profileFounded = profileRepo.FirstOrDefaultAsync(p => p.Name == name && p.Password == password).Result;
            return profileFounded != null;
        }

        public async Task<(int Id, string Token, bool IsAdmin, string Name, string PhotoPath, bool Verified, int? MessagesLeft, string VerifyHash)> RegisterAsync(DtoProfile newProfile)
        {
            // Prevent creating another admin if one already exists
            if (newProfile.isAdmin)
            {
                var existingAdmin = await profileRepo.FirstOrDefaultAsync(p => p.IsAdmin == true);
                if (existingAdmin != null)
                {
                    throw new InvalidOperationException("An admin user already exists. Only one admin is allowed.");
                }
            }

            var token = Guid.NewGuid().ToString();
            var defaultMessageLimit = int.TryParse(_configuration["AppSettings:DefaultMessageLimit"], out var limit) ? limit : 100;

            // Генерируем уникальный verify_hash
            var verifyHash = Guid.NewGuid().ToString("N");
            ModelProfile modelProfile = new ModelProfile()
            {
                DateAdd = DateTime.Now,
                Email = newProfile.email,
                Name = newProfile.name,
                Password = PasswordHelper.HashPassword(newProfile.password),
                Token = token,
                Verified = false,
                IsAdmin = newProfile.isAdmin,
                MessagesLeft = newProfile.isAdmin ? null : defaultMessageLimit,
                VerifyHash = verifyHash
            };
            await profileRepo.AddAsync(modelProfile);
            return (modelProfile.Id, token, modelProfile.IsAdmin, modelProfile.Name, modelProfile.PhotoPath, modelProfile.Verified, modelProfile.MessagesLeft, verifyHash);
        }

        public bool IsAuthenticated(string name, string token)
        {
            var profileFounded = profileRepo.FirstOrDefaultAsync(p => p.Name == name && p.Token == token).Result;
            return profileFounded != null;
        }

        public int? GetUserIdByToken(string token)
        {
            var profile = profileRepo.FirstOrDefaultAsync(p => p.Token == token).Result;
            return profile?.Id;
        }

        public bool GetIsAdminByToken(string token)
        {
            var profile = profileRepo.FirstOrDefaultAsync(p => p.Token == token).Result;
            return profile?.IsAdmin ?? false;
        }

        public async Task<(string Email, string Password)?> GetAdminCredentialsAsync()
        {
            var admin = await profileRepo.FirstOrDefaultAsync(p => p.IsAdmin == true);
            if (admin == null)
            {
                return null;
            }
            return (admin.Email, admin.Password);
        }

        public async Task UpdatePhotoPathAsync(int profileId, string photoPath)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile != null)
            {
                profile.PhotoPath = photoPath;
                await profileRepo.UpdateAsync(profile);
            }
        }

        public async Task<string> GetPhotoPathAsync(int profileId)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            return profile?.PhotoPath;
        }

        public async Task UpdateProfileNameAsync(int profileId, string name)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile != null)
            {
                profile.Name = name;
                await profileRepo.UpdateAsync(profile);
            }
        }

        public async Task<bool> ChangePasswordAsync(int profileId, string oldPassword, string newPassword)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return false;
            }

            // Verify old password
            bool passwordValid = profile.IsSystemUser
                ? profile.Password == oldPassword
                : PasswordHelper.VerifyPassword(oldPassword, profile.Password);

            if (!passwordValid)
            {
                return false;
            }

            // Update to new password (hash it unless it's a system user)
            profile.Password = profile.IsSystemUser
                ? newPassword
                : PasswordHelper.HashPassword(newPassword);

            await profileRepo.UpdateAsync(profile);
            return true;
        }

        public async Task<string> UpdateProfileAsync(int profileId, string name = null, string photoPath = null)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return null;
            }

            if (!string.IsNullOrEmpty(name))
            {
                profile.Name = name;
            }

            if (!string.IsNullOrEmpty(photoPath))
            {
                profile.PhotoPath = photoPath;
            }

            await profileRepo.UpdateAsync(profile);
            return profile.PhotoPath;
        }

        public async Task SetVerifiedAsync(int profileId, bool verified)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile != null)
            {
                // Prevent changing verification status of admin users
                if (profile.IsAdmin)
                {
                    throw new InvalidOperationException("Cannot change verification status of admin users");
                }

                profile.Verified = verified;
                await profileRepo.UpdateAsync(profile);
            }
        }

        public async Task<string> SetVerifiedAndClearTokenAsync(int profileId, bool verified)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return string.Empty;
            }

            // Prevent changing verification status of admin users
            if (profile.IsAdmin)
            {
                throw new InvalidOperationException("Cannot change verification status of admin users");
            }

            // Update both properties in one operation
            profile.Verified = verified;
            var oldToken = profile.Token;
            profile.Token = string.Empty;
            await profileRepo.UpdateAsync(profile);
            return oldToken;
        }

        public async Task<int?> GetMessagesLeftAsync(int profileId)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            return profile?.MessagesLeft;
        }

        public async Task<(bool canPost, int? messagesLeft)> DecrementMessagesLeftAsync(int profileId)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return (false, null);
            }

            // If verified, no limit applies
            if (profile.Verified)
            {
                return (true, null);
            }

            // If no limit set (null), allow unlimited
            if (!profile.MessagesLeft.HasValue)
            {
                return (true, null);
            }

            // Check if user has messages left
            if (profile.MessagesLeft.Value <= 0)
            {
                return (false, profile.MessagesLeft);
            }

            // Decrement the counter
            profile.MessagesLeft = profile.MessagesLeft.Value - 1;
            await profileRepo.UpdateAsync(profile);
            return (true, profile.MessagesLeft);
        }

        public async Task SetMessagesLeftAsync(int profileId, int? messagesLeft)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile != null)
            {
                profile.MessagesLeft = messagesLeft;
                await profileRepo.UpdateAsync(profile);
            }
        }

        public async Task UpdateAllUnverifiedMessagesLeftAsync(int messageLimit)
        {
            try
            {
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Starting update to limit: {messageLimit}");

                // Get all unverified, non-admin users (AsNoTracking returns detached entities)
                var allUsers = await profileRepo.GetAllAsync();
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Total users fetched: {allUsers.Count}");

                var usersToUpdate = allUsers
                    .Where(p => !p.Verified && !p.IsAdmin &&
                               (!p.MessagesLeft.HasValue || p.MessagesLeft.Value != 0))
                    .ToList();

                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Users to update: {usersToUpdate.Count}");
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] User IDs: {string.Join(", ", usersToUpdate.Select(u => u.Id))}");

                // Update all users in memory
                foreach (var user in usersToUpdate)
                {
                    Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Updating user {user.Id} ({user.Name}) from {user.MessagesLeft} to {messageLimit}");
                    user.MessagesLeft = messageLimit;
                }

                // Save all changes at once using bulk update to avoid tracking conflicts
                if (usersToUpdate.Any())
                {
                    Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Calling UpdateRangeAsync with {usersToUpdate.Count} users");
                    await profileRepo.UpdateRangeAsync(usersToUpdate);
                    Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] UpdateRangeAsync completed successfully");
                }
                else
                {
                    Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] No users to update");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] ERROR: {ex.Message}");
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Stack Trace: {ex.StackTrace}");
                Console.WriteLine($"[UpdateAllUnverifiedMessagesLeftAsync] Inner Exception: {ex.InnerException?.Message}");
                throw;
            }
        }

        public async Task UpdateUserMessageLimitAsync(int profileId, int messageLimit)
        {
            try
            {
                Console.WriteLine($"[UpdateUserMessageLimitAsync] Updating user {profileId} to limit: {messageLimit}");

                var user = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
                if (user == null)
                {
                    throw new InvalidOperationException($"User with ID {profileId} not found");
                }

                Console.WriteLine($"[UpdateUserMessageLimitAsync] Found user: {user.Name}, Current limit: {user.MessagesLeft}");

                user.MessagesLeft = messageLimit;
                await profileRepo.UpdateAsync(user);

                Console.WriteLine($"[UpdateUserMessageLimitAsync] Successfully updated user {profileId} to {messageLimit}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[UpdateUserMessageLimitAsync] ERROR: {ex.Message}");
                Console.WriteLine($"[UpdateUserMessageLimitAsync] Stack Trace: {ex.StackTrace}");
                throw;
            }
        }

        public async Task<List<UserDto>> GetAllUsersAsync()
        {
            var profiles = await profileRepo.GetAllAsync();
            return profiles.Select(p => new UserDto
            {
                Id = p.Id,
                Email = p.Email,
                Name = p.Name,
                PhotoPath = p.PhotoPath,
                IsSystemUser = p.IsSystemUser,
                IsAdmin = p.IsAdmin,
                Verified = p.Verified,
                MessagesLeft = p.MessagesLeft
            }).ToList();
        }

        public async Task<string> ClearUserTokenAsync(int profileId)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return string.Empty;
            }

            var oldToken = profile.Token;
            profile.Token = string.Empty;
            await profileRepo.UpdateAsync(profile);

            // Note: After UpdateAsync, the profile entity remains tracked in the DbContext
            // This is important for the subsequent DeleteUserAsync call

            return oldToken;
        }

        public async Task<string> GetUserTokenAsync(int profileId)
        {
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            return profile?.Token ?? string.Empty;
        }

        public async Task DeleteUserAsync(int profileId)
        {
            // Important: Don't fetch the profile again if it's already tracked
            // ClearUserTokenAsync already loaded and updated it, so it's tracked
            // We need to fetch it fresh to avoid tracking conflicts
            var profile = await profileRepo.FirstOrDefaultAsync(p => p.Id == profileId);
            if (profile == null)
            {
                return;
            }

            // Prevent deleting admin users
            if (profile.IsAdmin)
            {
                throw new InvalidOperationException("Cannot delete admin users");
            }

            // Get all posts by this user (both top-level and comments)
            var userPosts = await feedRepo.WhereAsync(f => f.ProfileId == profileId);

            // For each post, delete all child comments (from any user) and likes
            foreach (var post in userPosts)
            {
                await DeletePostAndChildrenAsync(post.Id);
            }

            // Delete all likes by this user on other posts
            var userLikes = await likeRepo.WhereAsync(l => l.ProfileId == profileId);
            foreach (var like in userLikes)
            {
                await likeRepo.DeleteAsync(like);
            }

            // Delete user's photo file if it exists
            if (!string.IsNullOrEmpty(profile.PhotoPath))
            {
                try
                {
                    Console.WriteLine($"Attempting to delete photo. PhotoPath: {profile.PhotoPath}");
                    Console.WriteLine($"Current directory: {Directory.GetCurrentDirectory()}");

                    // PhotoPath is stored as /api/profile/getphoto?profileId=X or uploads/profiles/X.png
                    // We need to extract the actual file path
                    string physicalPath;

                    if (profile.PhotoPath.Contains("profileId="))
                    {
                        // Extract profileId from the query string
                        var fileName = $"{profileId}.png";
                        physicalPath = Path.Combine(Directory.GetCurrentDirectory(), "uploads", "profiles", fileName);
                    }
                    else
                    {
                        // Direct path like uploads/profiles/X.png
                        physicalPath = Path.Combine(Directory.GetCurrentDirectory(), profile.PhotoPath.TrimStart('/'));
                    }

                    Console.WriteLine($"Resolved physical path: {physicalPath}");

                    if (File.Exists(physicalPath))
                    {
                        File.Delete(physicalPath);
                        Console.WriteLine($"Successfully deleted photo file: {physicalPath}");
                    }
                    else
                    {
                        Console.WriteLine($"Photo file not found: {physicalPath}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to delete photo file: {ex.Message}");
                    Console.WriteLine($"Stack trace: {ex.StackTrace}");
                    // Continue with user deletion even if photo deletion fails
                }
            }

            // Finally, delete the user profile
            // Since UpdateAsync in ClearUserTokenAsync already saved changes,
            // the profile is tracked. DeleteAsync will try to attach it again.
            // We need to ensure the entity is detached first or use the tracked instance
            await profileRepo.DeleteAsync(profile);
        }

        private async Task DeletePostAndChildrenAsync(int feedId)
        {
            // Get all child comments (recursively)
            var childComments = await feedRepo.WhereAsync(f => f.ParentId == feedId);
            foreach (var child in childComments)
            {
                await DeletePostAndChildrenAsync(child.Id);
            }

            // Delete all likes for this post
            var postLikes = await likeRepo.WhereAsync(l => l.FeedId == feedId);
            foreach (var like in postLikes)
            {
                await likeRepo.DeleteAsync(like);
            }

            // Delete the post itself
            var post = await feedRepo.FirstOrDefaultAsync(f => f.Id == feedId);
            if (post != null)
            {
                await feedRepo.DeleteAsync(post);
            }
        }
    }
}

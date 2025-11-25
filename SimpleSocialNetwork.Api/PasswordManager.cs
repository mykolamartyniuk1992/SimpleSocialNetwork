using System;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Cryptography.KeyDerivation;

namespace SimpleSocialNetwork
{
    public static class PasswordManager
    {
        public static string HashPassword(string password)
        {
            // Generate a random salt
            byte[] salt = new byte[128 / 8];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(salt);
            }

            // Hash the password with PBKDF2
            string hashed = Convert.ToBase64String(KeyDerivation.Pbkdf2(
                password: password,
                salt: salt,
                prf: KeyDerivationPrf.HMACSHA256,
                iterationCount: 10000,
                numBytesRequested: 256 / 8));

            // Combine salt and hash for storage
            return $"{Convert.ToBase64String(salt)}.{hashed}";
        }

        public static bool VerifyPassword(string hashedPassword, string providedPassword)
        {
            try
            {
                var parts = hashedPassword.Split('.');
                if (parts.Length != 2) return false;

                var salt = Convert.FromBase64String(parts[0]);
                var hash = parts[1];

                // Hash the provided password with the stored salt
                string hashedProvidedPassword = Convert.ToBase64String(KeyDerivation.Pbkdf2(
                    password: providedPassword,
                    salt: salt,
                    prf: KeyDerivationPrf.HMACSHA256,
                    iterationCount: 10000,
                    numBytesRequested: 256 / 8));

                return hash == hashedProvidedPassword;
            }
            catch
            {
                return false;
            }
        }

        // Legacy method for backward compatibility
        public static string GetHash(string name, string password)
        {
            byte[] data = System.Text.Encoding.ASCII.GetBytes(name + password);
            data = new System.Security.Cryptography.SHA256Managed().ComputeHash(data);
            var hash = System.Text.Encoding.ASCII.GetString(data);
            return hash;
        }
    }
}
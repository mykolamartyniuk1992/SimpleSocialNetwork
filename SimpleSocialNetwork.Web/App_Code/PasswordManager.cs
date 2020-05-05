using System;

namespace SimpleSocialNetwork
{
    public static class PasswordManager
    {
        public static string GetHash(string name, string password)
        {
            byte[] data = System.Text.Encoding.ASCII.GetBytes(name + password);
            data = new System.Security.Cryptography.SHA256Managed().ComputeHash(data);
            var hash = System.Text.Encoding.ASCII.GetString(data);
            return hash;
        }
    }
}
using System;
using System.Collections.Generic;

namespace SimpleSocialNetwork.Models
{
    public class ModelProfile : IEntity
    {
        public int Id { get; set; }
        public string Email { get; set; }
        public string Name { get; set; }
        public string Password { get; set; }
        public string Token { get; set; }
        public bool Verified { get; set; }
        public bool IsAdmin { get; set; }
        public bool IsSystemUser { get; set; }
        public int? MessagesLeft { get; set; }
        public string PhotoPath { get; set; }
        public DateTime DateAdd { get; set; }
        public virtual List<ModelLike> Likes { get; set; }
    }
}
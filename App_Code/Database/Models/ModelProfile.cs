using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database.Models
{
    public class ModelProfile
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Password { get; set; }
        public string Token { get; set; }
        public DateTime DateAdd { get; set; }
        public virtual List<ModelLike> Likes { get; set; }
    }
}
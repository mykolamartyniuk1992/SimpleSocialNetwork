using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database.Models
{
    public class ModelLike
    {
        public int Id { get; set; }
        public int FeedId { get; set; }
        public virtual ModelFeed Feed { get; set; }
        public int ProfileId { get; set; }
        public virtual ModelProfile Profile { get; set; }
    }
}
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleSocialNetwork.Models
{
    public class ModelFeed : IEntity
    {
        public int Id { get; set; }
        public int? ParentId { get; set; }
        public virtual ModelFeed Parent { get; set; }
        public virtual List<ModelFeed> Children { get; set; }
        public int ProfileId { get; set; }
        public virtual ModelProfile Profile { get; set; }
        public string Text { get; set; }
        public DateTime DateAdd { get; set; }
        public virtual List<ModelLike> Likes { get; set; }
    }
}
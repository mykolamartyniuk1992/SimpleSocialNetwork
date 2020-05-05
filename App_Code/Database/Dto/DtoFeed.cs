using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database.Dto
{
    public class DtoFeed
    {
        [DataMember]
        public int id { get; set; }
        [DataMember]
        public int? parentId { get; set; }
        [DataMember]
        public string name { get; set; }
        [DataMember]
        public string token { get; set; }
        [DataMember]
        public string text { get; set; }
        [DataMember]
        public string date { get; set; }
        [DataMember]
        public List<DtoLike> likes { get; set; }
    }
}
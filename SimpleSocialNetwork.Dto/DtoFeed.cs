using System.Collections.Generic;
using System.Runtime.Serialization;

namespace SimpleSocialNetwork.Dto
{
    public class DtoFeed
    {
        [DataMember]
        public int id { get; set; }
        [DataMember]
        public int? parentId { get; set; }
        [DataMember]
        public int profileId { get; set; }
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
        [DataMember]
        public string profilePhotoPath { get; set; }
        [DataMember]
        public List<DtoFeed> comments { get; set; }
        [DataMember]
        public int commentsCount { get; set; }
    }
}
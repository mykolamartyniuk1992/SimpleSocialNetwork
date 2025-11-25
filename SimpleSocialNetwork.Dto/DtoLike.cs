using System.Runtime.Serialization;

namespace SimpleSocialNetwork.Dto
{
    public class DtoLike
    {
        [DataMember]
        public int id { get; set; }
        [DataMember]
        public int profileId { get; set; }
        [DataMember]
        public string profileName { get; set; }
        [DataMember]
        public string token { get; set; }
        [DataMember]
        public int feedId { get; set; }
    }
}
using System.Runtime.Serialization;

namespace SimpleSocialNetwork.Dto
{
    public class DtoProfile
    {
        [DataMember]
        public string email { get; set; }
        [DataMember]
        public string name { get; set; }
        [DataMember]
        public string password { get; set; }
        [DataMember]
        public string token { get; set; }
        [DataMember]
        public bool verified { get; set; }
        [DataMember]
        public bool isAdmin { get; set; }
        [DataMember]
        public int? messagesLeft { get; set; }
    }
}
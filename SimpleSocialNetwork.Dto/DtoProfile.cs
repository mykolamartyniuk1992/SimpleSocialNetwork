using System.Runtime.Serialization;

namespace SimpleSocialNetwork.Dto
{
    public class DtoProfile
    {
        [DataMember]
        public string name { get; set; }
        [DataMember]
        public string password { get; set; }
        [DataMember]
        public string token { get; set; }
    }
}
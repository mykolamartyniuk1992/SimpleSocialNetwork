using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Web;

namespace SimpleSocialNetwork.App_Code.Database.Dto
{
    public class DtoLike
    {
        [DataMember]
        public int id { get; set; }
        [DataMember]
        public string profileName { get; set; }
        [DataMember]
        public string token { get; set; }
        [DataMember]
        public int feedId { get; set; }
    }
}
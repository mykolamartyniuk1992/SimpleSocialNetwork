using System.Runtime.Serialization;

namespace SimpleSocialNetwork.Dto
{
    public class DtoProfile
    {
        [DataMember]
        public string? email { get; set; } // Добавили ?

        [DataMember]
        public string? name { get; set; } // Добавили ?

        [DataMember]
        public string? password { get; set; } // Добавили ?

        // ЭТО ПОЛЕ ВЫЗЫВАЛО ОШИБКУ: Angular его не шлет, а оно было обязательным
        [DataMember]
        public string? token { get; set; } 

        [DataMember]
        public bool verified { get; set; }

        [DataMember]
        public bool isAdmin { get; set; }

        [DataMember]
        public int? messagesLeft { get; set; }
    }
}
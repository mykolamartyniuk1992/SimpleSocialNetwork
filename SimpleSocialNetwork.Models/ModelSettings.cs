using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SimpleSocialNetwork.Models
{
        [Table("settings")]
        public class ModelSettings : IEntity
    {
        [Key]
        public int Id { get; set; }
        public int DefaultMessageLimit { get; set; }
    }
}

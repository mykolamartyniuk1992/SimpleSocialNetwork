using System.Data.Entity.Migrations;

namespace SimpleSocialNetwork.Data.Migrations
{
    public partial class AddedDateAddForFeed : DbMigration
    {
        public override void Up()
        {
            AddColumn("dbo.feed", "date_add", c => c.DateTime(nullable: false));
        }
        
        public override void Down()
        {
            DropColumn("dbo.feed", "date_add");
        }
    }
}

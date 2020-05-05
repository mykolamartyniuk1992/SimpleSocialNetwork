using System.Data.Entity.Migrations;

namespace SimpleSocialNetwork.Data.Migrations
{
    public partial class AddedParentIdForFeed : DbMigration
    {
        public override void Up()
        {
            AddColumn("dbo.feed", "parent_id", c => c.Int(nullable: false));
        }
        
        public override void Down()
        {
            DropColumn("dbo.feed", "parent_id");
        }
    }
}

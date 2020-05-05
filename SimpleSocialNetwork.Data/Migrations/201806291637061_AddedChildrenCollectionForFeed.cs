using System.Data.Entity.Migrations;

namespace SimpleSocialNetwork.Data.Migrations
{
    public partial class AddedChildrenCollectionForFeed : DbMigration
    {
        public override void Up()
        {
            CreateIndex("dbo.feed", "parent_id");
            AddForeignKey("dbo.feed", "parent_id", "dbo.feed", "id");
        }
        
        public override void Down()
        {
            DropForeignKey("dbo.feed", "parent_id", "dbo.feed");
            DropIndex("dbo.feed", new[] { "parent_id" });
        }
    }
}

namespace SimpleSocialNetwork.Migrations
{
    using System;
    using System.Data.Entity.Migrations;
    
    public partial class FeedTableCreated : DbMigration
    {
        public override void Up()
        {
            CreateTable(
                "dbo.feed",
                c => new
                    {
                        id = c.Int(nullable: false, identity: true),
                        profile_id = c.Int(nullable: false),
                        text = c.String(),
                    })
                .PrimaryKey(t => t.id)
                .ForeignKey("dbo.profiles", t => t.profile_id, cascadeDelete: true)
                .Index(t => t.profile_id);
            
        }
        
        public override void Down()
        {
            DropForeignKey("dbo.feed", "profile_id", "dbo.profiles");
            DropIndex("dbo.feed", new[] { "profile_id" });
            DropTable("dbo.feed");
        }
    }
}

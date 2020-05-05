namespace SimpleSocialNetwork.Migrations
{
    using System;
    using System.Data.Entity.Migrations;
    
    public partial class LikesAdded : DbMigration
    {
        public override void Up()
        {
            CreateTable(
                "dbo.likes",
                c => new
                    {
                        id = c.Int(nullable: false, identity: true),
                        feed_id = c.Int(nullable: false),
                        profile_id = c.Int(nullable: false),
                    })
                .PrimaryKey(t => t.id)
                .ForeignKey("dbo.feed", t => t.feed_id)
                .ForeignKey("dbo.profiles", t => t.profile_id)
                .Index(t => t.feed_id)
                .Index(t => t.profile_id);
            
        }
        
        public override void Down()
        {
            DropForeignKey("dbo.likes", "profile_id", "dbo.profiles");
            DropForeignKey("dbo.likes", "feed_id", "dbo.feed");
            DropIndex("dbo.likes", new[] { "profile_id" });
            DropIndex("dbo.likes", new[] { "feed_id" });
            DropTable("dbo.likes");
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SimpleSocialNetwork.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)

        {
            migrationBuilder.CreateTable(
                name: "profiles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Password = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Token = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    Verified = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    IsAdmin = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    IsSystemUser = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    MessagesLeft = table.Column<int>(type: "int", nullable: true),
                    PhotoPath = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    DateAdd = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    VerifyHash = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_profiles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "feed",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    parent_id = table.Column<int>(type: "int", nullable: true),
                    profile_id = table.Column<int>(type: "int", nullable: false),
                    text = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    date_add = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_feed", x => x.id);
                    table.ForeignKey(
                        name: "FK_feed_feed_parent_id",
                        column: x => x.parent_id,
                        principalTable: "feed",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK_feed_profiles_profile_id",
                        column: x => x.profile_id,
                        principalTable: "profiles",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "likes",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    feed_id = table.Column<int>(type: "int", nullable: false),
                    profile_id = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_likes", x => x.id);
                    table.ForeignKey(
                        name: "FK_likes_feed_feed_id",
                        column: x => x.feed_id,
                        principalTable: "feed",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK_likes_profiles_profile_id",
                        column: x => x.profile_id,
                        principalTable: "profiles",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_feed_parent_id",
                table: "feed",
                column: "parent_id");

            migrationBuilder.CreateIndex(
                name: "IX_feed_profile_id",
                table: "feed",
                column: "profile_id");

            migrationBuilder.CreateIndex(
                name: "IX_likes_feed_id",
                table: "likes",
                column: "feed_id");

            migrationBuilder.CreateIndex(
                name: "IX_likes_profile_id",
                table: "likes",
                column: "profile_id");

            migrationBuilder.CreateIndex(
                name: "IX_profiles_IsAdmin",
                table: "profiles",
                column: "IsAdmin",
                unique: true,
                filter: "[IsAdmin] = 1");

            // Create admin user with generated password
            var adminPassword = Guid.NewGuid().ToString("N").Substring(0, 12); 
            var adminEmail = "admin@simplesocialnetwork.local";

            migrationBuilder.Sql($@"
                INSERT INTO profiles (Email, Name, Password, Token, Verified, IsAdmin, IsSystemUser, MessagesLeft, DateAdd)
                VALUES ('{adminEmail}', 'Administrator', '{adminPassword}', NULL, 1, 1, 1, NULL, SYSUTCDATETIME())
            ");

            // Create test unverified user
            var testEmail = "testuser@simplesocialnetwork.local";
            var testPassword = "Test123!";

            migrationBuilder.Sql($@"
                INSERT INTO profiles (Email, Name, Password, Token, Verified, IsAdmin, IsSystemUser, MessagesLeft, DateAdd)
                VALUES ('{testEmail}', 'TestUser', '{testPassword}', NULL, 0, 0, 1, 100, SYSUTCDATETIME())
            ");

            // Output passwords to console
            Console.WriteLine("============================================");
            Console.WriteLine("ADMIN USER CREATED");
            Console.WriteLine($"Email: {adminEmail}");
            Console.WriteLine($"Password: {adminPassword}");
            Console.WriteLine("SAVE THIS PASSWORD - IT WON'T BE SHOWN AGAIN!");
            Console.WriteLine("============================================");
            Console.WriteLine();
            Console.WriteLine("============================================");
            Console.WriteLine("TEST UNVERIFIED USER CREATED");
            Console.WriteLine($"Email: {testEmail}");
            Console.WriteLine($"Password: {testPassword}");
            Console.WriteLine($"Messages Left: 100");
            Console.WriteLine("============================================");

            migrationBuilder.CreateTable(
                name: "settings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DefaultMessageLimit = table.Column<int>(type: "int", nullable: false),
                    ProjectId = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_settings", x => x.Id);
                });

            // Seed default ProjectId
            migrationBuilder.InsertData(
                table: "settings",
                columns: new[] { "Id", "DefaultMessageLimit", "ProjectId" },
                values: new object[] { 1, 100, "norse-strata-476814-j9" }
            );
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "likes");

            migrationBuilder.DropTable(
                name: "settings");

            migrationBuilder.DropTable(
                name: "feed");

            migrationBuilder.DropTable(
                name: "profiles");
        }
    }
}

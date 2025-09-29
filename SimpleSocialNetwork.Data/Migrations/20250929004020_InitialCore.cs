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
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Password = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Token = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    DateAdd = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "likes");

            migrationBuilder.DropTable(
                name: "feed");

            migrationBuilder.DropTable(
                name: "profiles");
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddHiddenPlaceCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "hidden_place_cache",
                columns: table => new
                {
                    hidden_place_cache_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    cache_grid_key = table.Column<string>(type: "varchar(255)", nullable: false),
                    fetched_at_utc = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    place_id = table.Column<string>(type: "varchar(255)", nullable: false),
                    name = table.Column<string>(type: "longtext", nullable: false),
                    primary_type = table.Column<string>(type: "longtext", nullable: false),
                    latitude = table.Column<double>(type: "double", nullable: false),
                    longitude = table.Column<double>(type: "double", nullable: false),
                    rating = table.Column<double>(type: "double", nullable: true),
                    user_rating_count = table.Column<int>(type: "int", nullable: false),
                    price_level = table.Column<int>(type: "int", nullable: true),
                    business_status = table.Column<string>(type: "longtext", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hidden_place_cache", x => x.hidden_place_cache_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    email = table.Column<string>(type: "varchar(255)", nullable: false),
                    password_hash = table.Column<string>(type: "longtext", nullable: false),
                    username = table.Column<string>(type: "longtext", nullable: false),
                    profile_picture_url = table.Column<string>(type: "longtext", nullable: true),
                    city = table.Column<string>(type: "longtext", nullable: true),
                    age = table.Column<int>(type: "int", nullable: true),
                    gender = table.Column<string>(type: "longtext", nullable: true),
                    account_status = table.Column<string>(type: "longtext", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_users", x => x.user_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "email_verification_token",
                columns: table => new
                {
                    token_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    token = table.Column<string>(type: "varchar(255)", nullable: false),
                    expires_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    is_used = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    pending_email = table.Column<string>(type: "longtext", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_email_verification_token", x => x.token_id);
                    table.ForeignKey(
                        name: "fk_email_verification_token_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "user_session",
                columns: table => new
                {
                    session_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    session_token = table.Column<string>(type: "longtext", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    expires_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    is_active = table.Column<bool>(type: "tinyint(1)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_session", x => x.session_id);
                    table.ForeignKey(
                        name: "fk_user_session_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_email_verification_token_token",
                table: "email_verification_token",
                column: "token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_email_verification_token_user_id",
                table: "email_verification_token",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_cache_cache_grid_key_place_id",
                table: "hidden_place_cache",
                columns: new[] { "cache_grid_key", "place_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_user_session_user_id",
                table: "user_session",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_users_email",
                table: "users",
                column: "email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "email_verification_token");

            migrationBuilder.DropTable(
                name: "hidden_place_cache");

            migrationBuilder.DropTable(
                name: "user_session");

            migrationBuilder.DropTable(
                name: "users");
        }
    }
}

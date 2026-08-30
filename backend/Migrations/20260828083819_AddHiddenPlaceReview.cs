using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddHiddenPlaceReview : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "hidden_place_review",
                columns: table => new
                {
                    review_id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    google_place_id = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true),
                    recommend_place_id = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    rating = table.Column<decimal>(type: "decimal(2,1)", precision: 2, scale: 1, nullable: false),
                    comment = table.Column<string>(type: "longtext", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false, defaultValue: "ACTIVE")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hidden_place_review", x => x.review_id);
                    table.ForeignKey(
                        name: "fk_hidden_place_review_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_google_place_id",
                table: "hidden_place_review",
                column: "google_place_id");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_recommend_place_id",
                table: "hidden_place_review",
                column: "recommend_place_id");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_user_id",
                table: "hidden_place_review",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hidden_place_review");
        }
    }
}

using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewPhoto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "hidden_place_review_photo",
                columns: table => new
                {
                    review_photo_id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    review_id = table.Column<long>(type: "bigint", nullable: false),
                    photo_url = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: false),
                    display_order = table.Column<int>(type: "int", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hidden_place_review_photo", x => x.review_photo_id);
                    table.ForeignKey(
                        name: "fk_hidden_place_review_photo_hidden_place_review_review_id",
                        column: x => x.review_id,
                        principalTable: "hidden_place_review",
                        principalColumn: "review_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_photo_review_id",
                table: "hidden_place_review_photo",
                column: "review_id");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_photo_review_id_display_order",
                table: "hidden_place_review_photo",
                columns: new[] { "review_id", "display_order" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hidden_place_review_photo");
        }
    }
}

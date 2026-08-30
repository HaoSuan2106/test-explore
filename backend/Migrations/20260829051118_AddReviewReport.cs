using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewReport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "hidden_place_review_report",
                columns: table => new
                {
                    report_id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    review_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    reason = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hidden_place_review_report", x => x.report_id);
                    table.ForeignKey(
                        name: "fk_hidden_place_review_report_hidden_place_review_review_id",
                        column: x => x.review_id,
                        principalTable: "hidden_place_review",
                        principalColumn: "review_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_report_review_id",
                table: "hidden_place_review_report",
                column: "review_id");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_review_report_review_id_user_id",
                table: "hidden_place_review_report",
                columns: new[] { "review_id", "user_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hidden_place_review_report");
        }
    }
}

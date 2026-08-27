using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPlacePhotoAndSuppression : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "hidden_place_suppression",
                columns: table => new
                {
                    hidden_place_suppression_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    place_id = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: false),
                    name = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true),
                    reason = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true),
                    report_count = table.Column<int>(type: "int", nullable: false),
                    suppressed_at = table.Column<DateTime>(type: "timestamp", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hidden_place_suppression", x => x.hidden_place_suppression_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_hidden_place_suppression_place_id",
                table: "hidden_place_suppression",
                column: "place_id",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hidden_place_suppression");
        }
    }
}

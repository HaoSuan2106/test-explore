using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPassedQualityGateColumn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "passed_quality_gate",
                table: "hidden_place_cache",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "passed_quality_gate",
                table: "hidden_place_cache");
        }
    }
}

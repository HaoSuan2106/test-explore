using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddLocationFieldsToFootTrackerLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "address",
                table: "foot_tracker_log",
                type: "longtext",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "latitude",
                table: "foot_tracker_log",
                type: "double",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "longitude",
                table: "foot_tracker_log",
                type: "double",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "primary_type",
                table: "foot_tracker_log",
                type: "longtext",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "address",
                table: "foot_tracker_log");

            migrationBuilder.DropColumn(
                name: "latitude",
                table: "foot_tracker_log");

            migrationBuilder.DropColumn(
                name: "longitude",
                table: "foot_tracker_log");

            migrationBuilder.DropColumn(
                name: "primary_type",
                table: "foot_tracker_log");
        }
    }
}

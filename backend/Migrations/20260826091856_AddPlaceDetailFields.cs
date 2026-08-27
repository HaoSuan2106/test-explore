using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPlaceDetailFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "formatted_address",
                table: "hidden_place_cache",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "google_maps_uri",
                table: "hidden_place_cache",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "national_phone_number",
                table: "hidden_place_cache",
                type: "varchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "photos_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "regular_opening_hours_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "website_uri",
                table: "hidden_place_cache",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "formatted_address",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "google_maps_uri",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "national_phone_number",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "photos_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "regular_opening_hours_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "website_uri",
                table: "hidden_place_cache");
        }
    }
}

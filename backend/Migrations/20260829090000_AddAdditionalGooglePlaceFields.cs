using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddAdditionalGooglePlaceFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "accessibility_options_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "address_components_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "containing_places_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "google_maps_links_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "opening_date",
                table: "hidden_place_cache",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "primary_type_display_name",
                table: "hidden_place_cache",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "pure_service_area_business",
                table: "hidden_place_cache",
                type: "tinyint(1)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "short_formatted_address",
                table: "hidden_place_cache",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "viewport_json",
                table: "hidden_place_cache",
                type: "json",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "accessibility_options_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "address_components_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "containing_places_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "google_maps_links_json",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "opening_date",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "primary_type_display_name",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "pure_service_area_business",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "short_formatted_address",
                table: "hidden_place_cache");

            migrationBuilder.DropColumn(
                name: "viewport_json",
                table: "hidden_place_cache");
        }
    }
}

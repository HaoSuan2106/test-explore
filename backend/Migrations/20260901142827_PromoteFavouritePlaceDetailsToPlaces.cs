using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class PromoteFavouritePlaceDetailsToPlaces : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "google_maps_links_json",
                table: "places",
                type: "json",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "opening_date",
                table: "places",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "primary_type",
                table: "places",
                type: "varchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "primary_type_display_name",
                table: "places",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "short_formatted_address",
                table: "places",
                type: "varchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "viewport_json",
                table: "places",
                type: "json",
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "place_id",
                table: "favourite_place",
                type: "varchar(255)",
                maxLength: 255,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "varchar(255)",
                oldMaxLength: 255,
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_favourite_place_place_id",
                table: "favourite_place",
                column: "place_id");

            migrationBuilder.AddForeignKey(
                name: "fk_favourite_place_places_place_id",
                table: "favourite_place",
                column: "place_id",
                principalTable: "places",
                principalColumn: "place_id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_favourite_place_places_place_id",
                table: "favourite_place");

            migrationBuilder.DropIndex(
                name: "ix_favourite_place_place_id",
                table: "favourite_place");

            migrationBuilder.DropColumn(
                name: "google_maps_links_json",
                table: "places");

            migrationBuilder.DropColumn(
                name: "opening_date",
                table: "places");

            migrationBuilder.DropColumn(
                name: "primary_type",
                table: "places");

            migrationBuilder.DropColumn(
                name: "primary_type_display_name",
                table: "places");

            migrationBuilder.DropColumn(
                name: "short_formatted_address",
                table: "places");

            migrationBuilder.DropColumn(
                name: "viewport_json",
                table: "places");

            migrationBuilder.AlterColumn<string>(
                name: "place_id",
                table: "favourite_place",
                type: "varchar(255)",
                maxLength: 255,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(255)",
                oldMaxLength: 255);
        }
    }
}
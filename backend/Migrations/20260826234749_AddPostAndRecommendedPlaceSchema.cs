using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPostAndRecommendedPlaceSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "places",
                columns: table => new
                {
                    place_id = table.Column<string>(type: "varchar(255)", nullable: false),
                    name = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false),
                    address = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: false),
                    category = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: false),
                    description = table.Column<string>(type: "longtext", nullable: true),
                    latitude = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    longitude = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_places", x => x.place_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "foot_tracker_log",
                columns: table => new
                {
                    log_id = table.Column<string>(type: "varchar(255)", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    place_id = table.Column<string>(type: "varchar(255)", nullable: true),
                    title = table.Column<string>(type: "longtext", nullable: true),
                    distance_km = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    started_at = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    ended_at = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_foot_tracker_log", x => x.log_id);
                    // Priority 3: place_id is a reference-only field — NO FK to places
                    // (matches latest_v2.sql). Only the ix_foot_tracker_log_place_id
                    // index below remains.
                    table.ForeignKey(
                        name: "fk_foot_tracker_log_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_foot_tracker_log_place_id",
                table: "foot_tracker_log",
                column: "place_id");

            migrationBuilder.CreateIndex(
                name: "ix_foot_tracker_log_user_id",
                table: "foot_tracker_log",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "foot_tracker_log");

            migrationBuilder.DropTable(
                name: "places");
        }
    }
}

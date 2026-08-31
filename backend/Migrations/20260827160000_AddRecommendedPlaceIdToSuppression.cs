using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    /// <summary>
    /// Adds <c>hidden_place_suppression.recommended_place_id</c> (nullable) plus a
    /// supporting index. The suppression table is managed by hand-written SQL
    /// (it is not part of the EF model snapshot), so this migration executes raw
    /// SQL only and leaves the EF model unchanged.
    /// </summary>
    public partial class AddRecommendedPlaceIdToSuppression : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "ALTER TABLE hidden_place_suppression ADD COLUMN recommended_place_id VARCHAR(255) NULL;");

            migrationBuilder.Sql(
                "CREATE INDEX idx_hidden_place_suppression_recommended_place_id ON hidden_place_suppression (recommended_place_id);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "DROP INDEX idx_hidden_place_suppression_recommended_place_id ON hidden_place_suppression;");

            migrationBuilder.Sql(
                "ALTER TABLE hidden_place_suppression DROP COLUMN recommended_place_id;");
        }
    }
}

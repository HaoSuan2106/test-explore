using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPostAndRecommendedPlaceSchema : Migration
    {
        /// <inheritdoc />
        /// <remarks>
        /// NO-OP: Tables `places` and `foot_tracker_log` were already created by
        /// migration 20260826144036_AddCommunityAndRecommendedPlaces (applied).
        /// This migration was generated against an out-of-date model snapshot
        /// and is a duplicate — its CreateTable operations are redundant.
        /// </remarks>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
        }

        /// <inheritdoc />
        /// <remarks>
        /// NO-OP: Tables were created by migration 20260826144036, not by this migration.
        /// Rolling back to migration 9 should not drop them.
        /// </remarks>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}

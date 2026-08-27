using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class ReconcileFavouritePlaceWithMain : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // favourite_place already exists — it was created by the earlier
            // AddFavouritePlace migration before this branch merged with main.
            // This migration exists only to bring the recorded EF model
            // snapshot back in sync with both branches' changes; it makes no
            // actual database changes.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}
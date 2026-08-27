using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddCommunityAndRecommendedPlaces : Migration
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
                name: "recommended_places",
                columns: table => new
                {
                    submission_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    submitter_id = table.Column<int>(type: "int", nullable: false),
                    name = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false),
                    location_address = table.Column<string>(type: "varchar(250)", maxLength: 250, nullable: false),
                    latitude = table.Column<decimal>(type: "decimal(10,7)", precision: 10, scale: 7, nullable: true),
                    longitude = table.Column<decimal>(type: "decimal(10,7)", precision: 10, scale: 7, nullable: true),
                    category = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: false),
                    description = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    status = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_recommended_places", x => x.submission_id);
                    table.ForeignKey(
                        name: "fk_recommended_places_users_submitter_id",
                        column: x => x.submitter_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community_posts",
                columns: table => new
                {
                    post_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    author_id = table.Column<int>(type: "int", nullable: false),
                    tagged_place_id = table.Column<string>(type: "varchar(255)", nullable: false),
                    title = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true),
                    description = table.Column<string>(type: "varchar(2000)", maxLength: 2000, nullable: false),
                    views_count = table.Column<int>(type: "int", nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_posts", x => x.post_id);
                    table.ForeignKey(
                        name: "fk_community_posts_places_tagged_place_id",
                        column: x => x.tagged_place_id,
                        principalTable: "places",
                        principalColumn: "place_id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_community_posts_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
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
                    table.ForeignKey(
                        name: "fk_foot_tracker_log_places_place_id",
                        column: x => x.place_id,
                        principalTable: "places",
                        principalColumn: "place_id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_foot_tracker_log_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "recommended_place_reports",
                columns: table => new
                {
                    report_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    submission_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    reporter_id = table.Column<int>(type: "int", nullable: false),
                    reason = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_recommended_place_reports", x => x.report_id);
                    table.ForeignKey(
                        name: "fk_recommended_place_reports_recommended_places_submission_id",
                        column: x => x.submission_id,
                        principalTable: "recommended_places",
                        principalColumn: "submission_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_recommended_place_reports_users_reporter_id",
                        column: x => x.reporter_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "recommended_place_verifications",
                columns: table => new
                {
                    verification_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    submission_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_recommended_place_verifications", x => x.verification_id);
                    table.ForeignKey(
                        name: "fk_recommended_place_verifications_recommended_places_submissio",
                        column: x => x.submission_id,
                        principalTable: "recommended_places",
                        principalColumn: "submission_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_recommended_place_verifications_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community_post_comments",
                columns: table => new
                {
                    comment_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    post_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    author_id = table.Column<int>(type: "int", nullable: false),
                    content = table.Column<string>(type: "varchar(300)", maxLength: 300, nullable: false),
                    likes_count = table.Column<int>(type: "int", nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_post_comments", x => x.comment_id);
                    table.ForeignKey(
                        name: "fk_community_post_comments_community_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "community_posts",
                        principalColumn: "post_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_community_post_comments_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community_post_images",
                columns: table => new
                {
                    image_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    post_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    image_url = table.Column<string>(type: "longtext", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_post_images", x => x.image_id);
                    table.ForeignKey(
                        name: "fk_community_post_images_community_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "community_posts",
                        principalColumn: "post_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community_post_reactions",
                columns: table => new
                {
                    reaction_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    post_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    reaction_type = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_post_reactions", x => x.reaction_id);
                    table.ForeignKey(
                        name: "fk_community_post_reactions_community_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "community_posts",
                        principalColumn: "post_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_community_post_reactions_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community_post_reports",
                columns: table => new
                {
                    report_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    post_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    reporter_id = table.Column<int>(type: "int", nullable: false),
                    reason = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false),
                    status = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_post_reports", x => x.report_id);
                    table.ForeignKey(
                        name: "fk_community_post_reports_community_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "community_posts",
                        principalColumn: "post_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_community_post_reports_users_reporter_id",
                        column: x => x.reporter_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "user_saved_posts",
                columns: table => new
                {
                    saved_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    post_id = table.Column<string>(type: "varchar(36)", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_saved_posts", x => x.saved_id);
                    table.ForeignKey(
                        name: "fk_user_saved_posts_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "community_posts",
                        principalColumn: "post_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_user_saved_posts_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_comments_author_id",
                table: "community_post_comments",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_comments_post_id",
                table: "community_post_comments",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_images_post_id",
                table: "community_post_images",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_images_post_id_display_order",
                table: "community_post_images",
                columns: new[] { "post_id", "display_order" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reactions_post_id",
                table: "community_post_reactions",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reactions_post_id_user_id",
                table: "community_post_reactions",
                columns: new[] { "post_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reactions_user_id",
                table: "community_post_reactions",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reports_post_id",
                table: "community_post_reports",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reports_post_id_reporter_id",
                table: "community_post_reports",
                columns: new[] { "post_id", "reporter_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_community_post_reports_reporter_id",
                table: "community_post_reports",
                column: "reporter_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_posts_author_id",
                table: "community_posts",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "ix_community_posts_status",
                table: "community_posts",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "ix_community_posts_tagged_place_id",
                table: "community_posts",
                column: "tagged_place_id");

            migrationBuilder.CreateIndex(
                name: "ix_foot_tracker_log_place_id",
                table: "foot_tracker_log",
                column: "place_id");

            migrationBuilder.CreateIndex(
                name: "ix_foot_tracker_log_user_id",
                table: "foot_tracker_log",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_recommended_place_reports_reporter_id",
                table: "recommended_place_reports",
                column: "reporter_id");

            migrationBuilder.CreateIndex(
                name: "ix_recommended_place_reports_submission_id_reporter_id",
                table: "recommended_place_reports",
                columns: new[] { "submission_id", "reporter_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_recommended_place_verifications_submission_id_user_id",
                table: "recommended_place_verifications",
                columns: new[] { "submission_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_recommended_place_verifications_user_id",
                table: "recommended_place_verifications",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_recommended_places_status",
                table: "recommended_places",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "ix_recommended_places_submitter_id",
                table: "recommended_places",
                column: "submitter_id");

            migrationBuilder.CreateIndex(
                name: "ix_user_saved_posts_post_id",
                table: "user_saved_posts",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_user_saved_posts_post_id_user_id",
                table: "user_saved_posts",
                columns: new[] { "post_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_user_saved_posts_user_id",
                table: "user_saved_posts",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "community_post_comments");

            migrationBuilder.DropTable(
                name: "community_post_images");

            migrationBuilder.DropTable(
                name: "community_post_reactions");

            migrationBuilder.DropTable(
                name: "community_post_reports");

            migrationBuilder.DropTable(
                name: "foot_tracker_log");

            migrationBuilder.DropTable(
                name: "recommended_place_reports");

            migrationBuilder.DropTable(
                name: "recommended_place_verifications");

            migrationBuilder.DropTable(
                name: "user_saved_posts");

            migrationBuilder.DropTable(
                name: "recommended_places");

            migrationBuilder.DropTable(
                name: "community_posts");

            migrationBuilder.DropTable(
                name: "places");
        }
    }
}

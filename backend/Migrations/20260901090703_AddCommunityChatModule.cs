using System;
using Microsoft.EntityFrameworkCore.Migrations;
using MySql.EntityFrameworkCore.Metadata;

#nullable disable

namespace explore_my_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddCommunityChatModule : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "place_id",
                table: "favourite_place",
                type: "varchar(255)",
                maxLength: 255,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "varchar(255)",
                oldMaxLength: 255);
            // tagged_place_id is widened to longtext below, but MySQL refuses to ALTER a
            // TEXT/BLOB column while a key (FK or plain index) is defined on it without a
            // prefix length. Both the FK and its separately-named supporting index have to
            // go first - dropping the FK alone leaves ix_community_posts_tagged_place_id
            // behind and the ALTER still fails the same way. Mirrored back in Down().
            //
            // The FK/index drop and the withdrawn_at column add below are wrapped in throwaway
            // stored procedures that check information_schema first, instead of the plain
            // migrationBuilder.DropForeignKey/DropIndex/AddColumn calls. Why they need to be
            // conditional: MySQL DDL auto-commits per statement, so when this migration failed
            // partway through on a later statement (it originally failed further down, at the
            // recommended_places CreateTable), these earlier statements had already committed.
            // A retry re-runs Up() from the top, and unconditional versions then blow up with
            // "constraint does not exist" / "duplicate column name".
            //
            // Why a stored procedure and not something shorter - two simpler forms were tried
            // and both failed on this stack:
            //   1. SET @var := (SELECT ...) + PREPARE/EXECUTE - MySql.Data's ADO.NET client
            //      parses any "@name" in the command text as a bind parameter rather than a
            //      MySQL user variable, and throws "Parameter '@fk_exists' must be defined".
            //   2. ALTER TABLE ... DROP CONSTRAINT/FOREIGN KEY IF EXISTS - the IF EXISTS
            //      clause on ALTER TABLE needs MySQL 8.0.29+; this server rejects it as a
            //      syntax error.
            // A procedure body uses DECLARE'd local variables (no "@" for the driver to grab)
            // and IF/THEN, both supported since MySQL 5.7. The whole CREATE PROCEDURE is sent
            // as one command, so the DELIMITER dance the mysql CLI needs does not apply here.
            migrationBuilder.Sql(
                "DROP PROCEDURE IF EXISTS explore_my_drop_tagged_place_id_keys;");
            migrationBuilder.Sql(@"
CREATE PROCEDURE explore_my_drop_tagged_place_id_keys()
BEGIN
    DECLARE fk_count INT DEFAULT 0;
    DECLARE idx_count INT DEFAULT 0;

    SELECT COUNT(*) INTO fk_count
      FROM information_schema.TABLE_CONSTRAINTS
     WHERE CONSTRAINT_SCHEMA = DATABASE()
       AND TABLE_NAME = 'community_posts'
       AND CONSTRAINT_NAME = 'fk_community_posts_places_tagged_place_id'
       AND CONSTRAINT_TYPE = 'FOREIGN KEY';

    IF fk_count > 0 THEN
        ALTER TABLE community_posts DROP FOREIGN KEY fk_community_posts_places_tagged_place_id;
    END IF;

    SELECT COUNT(*) INTO idx_count
      FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'community_posts'
       AND INDEX_NAME = 'ix_community_posts_tagged_place_id';

    IF idx_count > 0 THEN
        ALTER TABLE community_posts DROP INDEX ix_community_posts_tagged_place_id;
    END IF;
END");
            migrationBuilder.Sql("CALL explore_my_drop_tagged_place_id_keys();");
            migrationBuilder.Sql("DROP PROCEDURE explore_my_drop_tagged_place_id_keys;");

            migrationBuilder.AlterColumn<string>(
                name: "tagged_place_id",
                table: "community_posts",
                type: "longtext",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "varchar(255)");

            migrationBuilder.Sql(
                "DROP PROCEDURE IF EXISTS explore_my_add_report_withdrawn_at;");
            migrationBuilder.Sql(@"
CREATE PROCEDURE explore_my_add_report_withdrawn_at()
BEGIN
    DECLARE col_count INT DEFAULT 0;

    SELECT COUNT(*) INTO col_count
      FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'community_post_reports'
       AND COLUMN_NAME = 'withdrawn_at';

    IF col_count = 0 THEN
        ALTER TABLE community_post_reports ADD COLUMN withdrawn_at datetime(6) NULL;
    END IF;
END");
            migrationBuilder.Sql("CALL explore_my_add_report_withdrawn_at();");
            migrationBuilder.Sql("DROP PROCEDURE explore_my_add_report_withdrawn_at;");

            // The old recommended_places schema (submission_id PK, created by migration
            // 20260826144036_AddCommunityAndRecommendedPlaces) is replaced below by the new
            // normalized schema (recommend_place_id PK). The old tables are empty, so this
            // is a data-safe structural swap. DROP TABLE IF EXISTS is idempotent, which the
            // retry-safe pattern in this migration requires (MySQL DDL auto-commits, so a
            // partial failure followed by a retry must not blow up on "table already exists"
            // or "table does not exist"). Children with FKs to recommended_places must be
            // dropped before the parent.
            migrationBuilder.Sql(
                "DROP TABLE IF EXISTS recommended_place_reports;");
            migrationBuilder.Sql(
                "DROP TABLE IF EXISTS recommended_place_verifications;");
            migrationBuilder.Sql(
                "DROP TABLE IF EXISTS recommended_places;");

            migrationBuilder.CreateTable(
                name: "recommended_places",
                columns: table => new
                {
                    recommend_place_id = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: false),
                    name = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: false),
                    primary_type = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false),
                    latitude = table.Column<double>(type: "double", nullable: false),
                    longitude = table.Column<double>(type: "double", nullable: false),
                    rating = table.Column<double>(type: "double", nullable: true),
                    user_rating_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    price_level = table.Column<int>(type: "int", nullable: true),
                    business_status = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    photo_json = table.Column<string>(type: "json", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_recommended_places", x => x.recommend_place_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "community",
                columns: table => new
                {
                    community_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    name = table.Column<string>(type: "varchar(150)", maxLength: 150, nullable: false),
                    description = table.Column<string>(type: "varchar(1000)", maxLength: 1000, nullable: true),
                    area = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true),
                    state = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true),
                    latitude = table.Column<double>(type: "double", nullable: true),
                    longitude = table.Column<double>(type: "double", nullable: true),
                    image_url = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community", x => x.community_id);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "place_submissions",
                columns: table => new
                {
                    submission_id = table.Column<string>(type: "varchar(36)", maxLength: 36, nullable: false),
                    submitter_id = table.Column<int>(type: "int", nullable: false),
                    recommend_place_id = table.Column<string>(type: "varchar(255)", nullable: false),
                    status = table.Column<string>(type: "varchar(30)", maxLength: 30, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_place_submissions", x => x.submission_id);
                    table.ForeignKey(
                        name: "fk_place_submissions_recommend_places_recommend_place_id",
                        column: x => x.recommend_place_id,
                        principalTable: "recommended_places",
                        principalColumn: "recommend_place_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_place_submissions_users_submitter_id",
                        column: x => x.submitter_id,
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
                        name: "fk_recommended_place_verifications_place_submissions_submission",
                        column: x => x.submission_id,
                        principalTable: "place_submissions",
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
                name: "community_member",
                columns: table => new
                {
                    community_member_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    community_id = table.Column<int>(type: "int", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    role = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false, defaultValue: "Member"),
                    is_active = table.Column<bool>(type: "tinyint(1)", nullable: false, defaultValue: true),
                    joined_at = table.Column<DateTime>(type: "timestamp", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP"),
                    left_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_community_member", x => x.community_member_id);
                    table.ForeignKey(
                        name: "fk_community_member_community_community_id",
                        column: x => x.community_id,
                        principalTable: "community",
                        principalColumn: "community_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_community_member_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "message",
                columns: table => new
                {
                    message_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    community_id = table.Column<int>(type: "int", nullable: false),
                    sender_user_id = table.Column<int>(type: "int", nullable: false),
                    content = table.Column<string>(type: "varchar(2000)", maxLength: 2000, nullable: true),
                    reply_to_message_id = table.Column<int>(type: "int", nullable: true),
                    is_deleted = table.Column<bool>(type: "tinyint(1)", nullable: false, defaultValue: false),
                    sent_at = table.Column<DateTime>(type: "timestamp", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_message", x => x.message_id);
                    table.ForeignKey(
                        name: "fk_message_community_community_id",
                        column: x => x.community_id,
                        principalTable: "community",
                        principalColumn: "community_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_message_users_sender_user_id",
                        column: x => x.sender_user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "message_attachment",
                columns: table => new
                {
                    attachment_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    message_id = table.Column<int>(type: "int", nullable: false),
                    type = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false),
                    media_url = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    place_id = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true),
                    place_name = table.Column<string>(type: "varchar(255)", maxLength: 255, nullable: true),
                    place_address = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    place_image_url = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    place_status = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: true),
                    place_latitude = table.Column<double>(type: "double", nullable: true),
                    place_longitude = table.Column<double>(type: "double", nullable: true),
                    place_primary_type = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true),
                    is_community_place = table.Column<bool>(type: "tinyint(1)", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_message_attachment", x => x.attachment_id);
                    table.ForeignKey(
                        name: "fk_message_attachment_message_message_id",
                        column: x => x.message_id,
                        principalTable: "message",
                        principalColumn: "message_id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "message_report",
                columns: table => new
                {
                    report_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySQL:ValueGenerationStrategy", MySQLValueGenerationStrategy.IdentityColumn),
                    message_id = table.Column<int>(type: "int", nullable: false),
                    reporter_user_id = table.Column<int>(type: "int", nullable: false),
                    reason = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp", nullable: false, defaultValueSql: "CURRENT_TIMESTAMP")
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_message_report", x => x.report_id);
                    table.ForeignKey(
                        name: "fk_message_report_message_message_id",
                        column: x => x.message_id,
                        principalTable: "message",
                        principalColumn: "message_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_message_report_users_reporter_user_id",
                        column: x => x.reporter_user_id,
                        principalTable: "users",
                        principalColumn: "user_id",
                        onDelete: ReferentialAction.Restrict);
                })
                .Annotation("MySQL:Charset", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "idx_community_state",
                table: "community",
                column: "state");
            migrationBuilder.CreateIndex(
                name: "idx_member_community_user",
                table: "community_member",
                columns: new[] { "community_id", "user_id" },
                unique: true);
            migrationBuilder.CreateIndex(
                name: "ix_community_member_user_id",
                table: "community_member",
                column: "user_id");
            migrationBuilder.CreateIndex(
                name: "idx_message_community_sent_at",
                table: "message",
                columns: new[] { "community_id", "sent_at" });
            migrationBuilder.CreateIndex(
                name: "ix_message_sender_user_id",
                table: "message",
                column: "sender_user_id");
            migrationBuilder.CreateIndex(
                name: "idx_attachment_message_id",
                table: "message_attachment",
                column: "message_id");
            migrationBuilder.CreateIndex(
                name: "idx_report_message_reporter",
                table: "message_report",
                columns: new[] { "message_id", "reporter_user_id" },
                unique: true);
            migrationBuilder.CreateIndex(
                name: "ix_message_report_reporter_user_id",
                table: "message_report",
                column: "reporter_user_id");
            migrationBuilder.CreateIndex(
                name: "ix_place_submissions_recommend_place_id",
                table: "place_submissions",
                column: "recommend_place_id");
            migrationBuilder.CreateIndex(
                name: "ix_place_submissions_status",
                table: "place_submissions",
                column: "status");
            migrationBuilder.CreateIndex(
                name: "ix_place_submissions_submitter_id",
                table: "place_submissions",
                column: "submitter_id");
            migrationBuilder.CreateIndex(
                name: "uq_recommended_place_verifications_submission_user",
                table: "recommended_place_verifications",
                columns: new[] { "submission_id", "user_id" },
                unique: true);
            migrationBuilder.CreateIndex(
                name: "ix_recommended_place_verifications_user_id",
                table: "recommended_place_verifications",
                column: "user_id");

            // foot_tracker_log already carries this FK from its original CreateTable (with
            // ON DELETE SET NULL) - this statement is meant to replace it with the default
            // (no ON DELETE clause / RESTRICT) behaviour, but the migration never dropped the
            // old one first. Same missing-DropForeignKey mistake as the tagged_place_id fix
            // above, fixed the same way: drop-if-present, then add. Wrapped in a procedure for
            // the same DECLARE-local-variable / no-IF-EXISTS-clause reasons documented above.
            migrationBuilder.Sql(
                "DROP PROCEDURE IF EXISTS explore_my_fix_foot_tracker_place_fk;");
            migrationBuilder.Sql(@"
CREATE PROCEDURE explore_my_fix_foot_tracker_place_fk()
BEGIN
    DECLARE fk_count INT DEFAULT 0;

    SELECT COUNT(*) INTO fk_count
      FROM information_schema.TABLE_CONSTRAINTS
     WHERE CONSTRAINT_SCHEMA = DATABASE()
       AND TABLE_NAME = 'foot_tracker_log'
       AND CONSTRAINT_NAME = 'fk_foot_tracker_log_places_place_id'
       AND CONSTRAINT_TYPE = 'FOREIGN KEY';

    IF fk_count > 0 THEN
        ALTER TABLE foot_tracker_log DROP FOREIGN KEY fk_foot_tracker_log_places_place_id;
    END IF;

    ALTER TABLE foot_tracker_log
        ADD CONSTRAINT fk_foot_tracker_log_places_place_id
        FOREIGN KEY (place_id) REFERENCES places (place_id);
END");
            migrationBuilder.Sql("CALL explore_my_fix_foot_tracker_place_fk();");
            migrationBuilder.Sql("DROP PROCEDURE explore_my_fix_foot_tracker_place_fk;");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_foot_tracker_log_places_place_id",
                table: "foot_tracker_log");

            migrationBuilder.DropTable(
                name: "recommended_place_verifications");
            migrationBuilder.DropTable(
                name: "community_member");
            migrationBuilder.DropTable(
                name: "message_attachment");
            migrationBuilder.DropTable(
                name: "message_report");
            migrationBuilder.DropTable(
                name: "place_submissions");
            migrationBuilder.DropTable(
                name: "message");
            migrationBuilder.DropTable(
                name: "community");
            migrationBuilder.DropTable(
                name: "recommended_places");

            migrationBuilder.DropColumn(
                name: "withdrawn_at",
                table: "community_post_reports");

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
            migrationBuilder.AlterColumn<string>(
                name: "tagged_place_id",
                table: "community_posts",
                type: "varchar(255)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "longtext");

            // Mirrors the Up() side: recreate the supporting index before the FK that needs it.
            migrationBuilder.CreateIndex(
                name: "ix_community_posts_tagged_place_id",
                table: "community_posts",
                column: "tagged_place_id");

            migrationBuilder.AddForeignKey(
                name: "fk_community_posts_places_tagged_place_id",
                table: "community_posts",
                column: "tagged_place_id",
                principalTable: "places",
                principalColumn: "place_id",
                onDelete: ReferentialAction.Restrict);
            migrationBuilder.AddForeignKey(
                name: "fk_foot_tracker_log_places_place_id",
                table: "foot_tracker_log",
                column: "place_id",
                principalTable: "places",
                principalColumn: "place_id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}

using ExploreMy.Api.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.Persistence.DbContext;

public class MySqlDbContext : Microsoft.EntityFrameworkCore.DbContext
{
    public MySqlDbContext(DbContextOptions<MySqlDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserSession> UserSessions => Set<UserSession>();
    public DbSet<EmailVerificationToken> EmailVerificationTokens => Set<EmailVerificationToken>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<HiddenPlace> HiddenPlaces => Set<HiddenPlace>();
    public DbSet<PlacePhoto> PlacePhotos => Set<PlacePhoto>();
    public DbSet<HiddenPlaceSuppression> HiddenPlaceSuppressions => Set<HiddenPlaceSuppression>();
    public DbSet<FavouritePlace> FavouritePlaces => Set<FavouritePlace>();

    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<ReviewPhoto> ReviewPhotos => Set<ReviewPhoto>();

    public DbSet<ReviewReport> ReviewReports => Set<ReviewReport>();

    // -------------------------------------------------------------------------
    // The Property(...) calls below exist to make `dotnet ef database update`
    // produce the SAME column types, lengths, defaults and index names as
    // database/scripts/CreateTable.sql, which is the schema the team wrote by
    // hand. Keep the two in step: if you change a length or a type here, change
    // it there as well (and vice versa), then add a migration.
    //
    // Without these, EF maps every string to `longtext` and every DateTime to
    // `datetime(6)`, which is what caused the two to drift apart in the first
    // place.
    //
    // Two deliberate exceptions, both noted at the property concerned:
    // user_session.is_active's DEFAULT, and the FK constraint names.
    // -------------------------------------------------------------------------
    // Post module
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<PostImage> PostImages => Set<PostImage>();
    public DbSet<PostComment> PostComments => Set<PostComment>();
    public DbSet<PostReaction> PostReactions => Set<PostReaction>();
    public DbSet<PostReport> PostReports => Set<PostReport>();
    public DbSet<UserSavedPost> UserSavedPosts => Set<UserSavedPost>();

    // Shared module dependencies required by the Post module
    public DbSet<Place> Places => Set<Place>();
    public DbSet<FootTrackerLog> FootTrackerLogs => Set<FootTrackerLog>();

    // My Recommended Places module (normalized schema: canonical place + submissions)
    public DbSet<RecommendPlace> RecommendPlaces => Set<RecommendPlace>();
    public DbSet<PlaceSubmission> PlaceSubmissions => Set<PlaceSubmission>();
    public DbSet<PlaceSubmissionVerification> PlaceSubmissionVerifications => Set<PlaceSubmissionVerification>();

    // Communication module (Community Chat)
    public DbSet<Community> Communities => Set<Community>();
    public DbSet<CommunityMember> CommunityMembers => Set<CommunityMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<MessageAttachment> MessageAttachments => Set<MessageAttachment>();
    public DbSet<MessageReport> MessageReports => Set<MessageReport>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(u => u.Email).HasMaxLength(255);
            entity.Property(u => u.PasswordHash).HasMaxLength(255);
            entity.Property(u => u.Username).HasMaxLength(50);
            entity.Property(u => u.ProfilePictureUrl).HasMaxLength(500);
            entity.Property(u => u.City).HasMaxLength(100);

            // EF has no concept of a MySQL ENUM, so the column type is spelled out
            // verbatim. The values must stay identical to CreateTable.sql - MySQL
            // silently stores '' for any value not in the list.
            entity.Property(u => u.Gender)
                .HasColumnType("enum('Male','Female','Prefer not to say')");

            entity.Property(u => u.AccountStatus)
                .HasMaxLength(30)
                .HasDefaultValue("pending_verification");

            entity.Property(u => u.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            // MySQL's auto-touch-on-update. EF has no first-class API for the
            // "ON UPDATE" half, but it emits HasDefaultValueSql verbatim after
            // DEFAULT, and MySQL parses the whole clause.
            entity.Property(u => u.UpdatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");

            // CreateTable.sql declares this as an inline `UNIQUE` on the column,
            // which MySQL names after the column itself - hence "email" rather
            // than EF's default of ix_users_email.
            entity.HasIndex(u => u.Email)
                .IsUnique()
                .HasDatabaseName("email");
        });

        modelBuilder.Entity<EmailVerificationToken>(entity =>
        {
            entity.ToTable("email_verification_token");
            entity.HasKey(t => t.TokenId);

            entity.Property(t => t.Token).HasMaxLength(255);
            entity.Property(t => t.PendingEmail).HasMaxLength(255);
            entity.Property(t => t.ExpiresAt).HasColumnType("datetime");
            entity.Property(t => t.IsUsed).HasDefaultValue(false);
            entity.Property(t => t.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(t => t.UserId).HasDatabaseName("idx_evt_user_id");
            entity.HasIndex(t => t.Token).IsUnique().HasDatabaseName("token");
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.ToTable("password_reset_token");
            entity.HasKey(t => t.TokenId);

            entity.Property(t => t.Token).HasMaxLength(255);
            entity.Property(t => t.ExpiresAt).HasColumnType("datetime");
            entity.Property(t => t.IsUsed).HasDefaultValue(false);
            entity.Property(t => t.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(t => t.UserId).HasDatabaseName("idx_prt_user_id");
            entity.HasIndex(t => t.Token).IsUnique().HasDatabaseName("token");
        });

        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.ToTable("user_session");
            entity.HasKey(s => s.SessionId);

            entity.Property(s => s.SessionToken).HasMaxLength(500);
            entity.Property(s => s.ExpiresAt).HasColumnType("datetime");
            entity.Property(s => s.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            // NOT configured with .HasDefaultValue(true), even though
            // CreateTable.sql says DEFAULT TRUE. A property with an EF default is
            // treated as store-generated, and EF then OMITS it from the INSERT
            // whenever its value equals the CLR default (false) - so writing a
            // session with IsActive = false would silently store TRUE. The column
            // still ends up tinyint(1) NOT NULL; only the DEFAULT clause differs,
            // and the app always sets this explicitly.
            //
            // The same trap does not apply to is_used / passed_quality_gate: their
            // DEFAULT is FALSE, which matches the CLR default, so omitting them
            // stores the right value either way.

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(s => s.UserId).HasDatabaseName("idx_session_user_id");
        });

        modelBuilder.Entity<Review>(entity =>
        {
            entity.ToTable("hidden_place_review");

            entity.HasKey(r => r.ReviewId);

            entity.Property(r => r.GooglePlaceId)
                .HasMaxLength(255);

            entity.Property(r => r.RecommendPlaceId)
                .HasMaxLength(255);

            entity.Property(r => r.Rating)
                .HasPrecision(2, 1);

            entity.Property(r => r.Comment)
                .IsRequired();

            entity.Property(r => r.CreatedAt)
                .HasColumnType("datetime(6)");

            entity.Property(r => r.UpdatedAt)
                .HasColumnType("datetime(6)");

            entity.Property(r => r.Status)
                .HasMaxLength(20)
                .HasDefaultValue("ACTIVE");

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(r => r.GooglePlaceId);
            entity.HasIndex(r => r.RecommendPlaceId);
            entity.HasIndex(r => r.UserId);
        });

        modelBuilder.Entity<ReviewReport>(entity =>
        {
            entity.ToTable("hidden_place_review_report");

            entity.HasKey(e => e.ReportId);

            entity.Property(e => e.ReportId)
                .HasColumnName("report_id");

            entity.Property(e => e.ReviewId)
                .HasColumnName("review_id");

            entity.Property(e => e.UserId)
                .HasColumnName("user_id");

            entity.Property(e => e.Reason)
                .HasColumnName("reason")
                .HasMaxLength(50)
                .IsRequired();

            entity.Property(e => e.CreatedAt)
                .HasColumnName("created_at");

            entity.HasIndex(e => e.ReviewId);

            entity.HasIndex(e => new
            {
                e.ReviewId,
                e.UserId
            })
            .IsUnique();

            entity.HasOne<Review>()
                .WithMany()
                .HasForeignKey(e => e.ReviewId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ReviewPhoto>(entity =>
        {
            entity.ToTable("hidden_place_review_photo");

            entity.HasKey(p => p.ReviewPhotoId);

            entity.Property(p => p.PhotoUrl)
                .HasMaxLength(500)
                .IsRequired();

            entity.Property(p => p.DisplayOrder)
                .IsRequired();

            entity.Property(p => p.CreatedAt)
                .HasColumnType("datetime(6)");

            entity.HasOne<Review>()
                .WithMany()
                .HasForeignKey(p => p.ReviewId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(p => p.ReviewId);

            entity.HasIndex(p => new
            {
                p.ReviewId,
                p.DisplayOrder
            }).IsUnique();
        });

        modelBuilder.Entity<HiddenPlace>(entity =>
        {
            entity.ToTable("hidden_place_cache");
            entity.HasKey(p => p.HiddenPlaceCacheId);

            entity.Property(p => p.CacheGridKey).HasMaxLength(255);
            entity.Property(p => p.PlaceId).HasMaxLength(255);
            entity.Property(p => p.Name).HasMaxLength(255);
            entity.Property(p => p.PrimaryType).HasMaxLength(100);
            entity.Property(p => p.BusinessStatus)
                .HasMaxLength(50)
                .HasDefaultValue("OPERATIONAL");
            entity.Property(p => p.UserRatingCount).HasDefaultValue(0);
            entity.Property(p => p.PassedQualityGate).HasDefaultValue(false);

            entity.Property(p => p.FormattedAddress).HasMaxLength(500);
            entity.Property(p => p.GoogleMapsUri).HasMaxLength(500);
            entity.Property(p => p.WebsiteUri).HasMaxLength(500);
            entity.Property(p => p.NationalPhoneNumber).HasMaxLength(50);
            entity.Property(p => p.ShortFormattedAddress).HasMaxLength(500);
            entity.Property(p => p.PrimaryTypeDisplayName).HasMaxLength(100);

            // Mapped to MySQL's native json type rather than longtext. The app only ever passes these
            // through to the client, so the strong reason is validation: json rejects anything malformed,
            // which turns a serialisation bug into an insert failure instead of corrupt rows discovered
            // later. It also leaves the door open to querying inside them with JSON_EXTRACT.
            //
            // The column is nullable and must be given SQL NULL - not "" - when Google omits the field;
            // json will not accept an empty string. GooglePlacesApiClient.RawJsonOrNull enforces that.
            entity.Property(p => p.PhotosJson).HasColumnType("json");
            entity.Property(p => p.RegularOpeningHoursJson).HasColumnType("json");
            entity.Property(p => p.AddressComponentsJson).HasColumnType("json");
            entity.Property(p => p.ViewportJson).HasColumnType("json");
            entity.Property(p => p.GoogleMapsLinksJson).HasColumnType("json");
            entity.Property(p => p.AccessibilityOptionsJson).HasColumnType("json");
            entity.Property(p => p.ContainingPlacesJson).HasColumnType("json");

            // Plain nullable columns - no default, since "unknown" (Google omitted the field) has to stay
            // distinguishable from a known false/empty value.
            entity.Property(p => p.PureServiceAreaBusiness);
            entity.Property(p => p.OpeningDate).HasColumnType("date");

            // Left as datetime(6), NOT timestamp: freshness is compared against UTC
            // "now" in code, and timestamp would apply session-timezone conversion
            // on the way in and out.

            // A bucket (CacheGridKey) is replaced wholesale on refetch, and within a bucket a given
            // real-world place (PlaceId) should only appear once.
            entity.HasIndex(p => new { p.CacheGridKey, p.PlaceId }).IsUnique();
        });

        modelBuilder.Entity<PlacePhoto>(entity =>
        {
            entity.ToTable("place_photo");
            entity.HasKey(p => p.PlacePhotoId);

            entity.Property(p => p.PlaceId).HasMaxLength(255);
            entity.Property(p => p.PhotoUrl).HasMaxLength(500);
            entity.Property(p => p.PhotoReference).HasMaxLength(500);
            entity.Property(p => p.Attribution).HasMaxLength(255);
            entity.Property(p => p.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            // NOT a foreign key to hidden_place_cache. That table is disposable - buckets are deleted
            // and re-inserted on every refresh - so an FK would either block the refresh or cascade
            // these rows away, which is exactly the re-buying from Google this table exists to avoid.
            // The unique index is what matters here: one photo per place, and the lookup by place id.
            entity.HasIndex(p => p.PlaceId).IsUnique();
        });

        // hidden_place_suppression is configured further down, in one place, next to the rest of the
        // reporting tables. It used to be configured HERE as well, and the two blocks disagreed: this
        // one declared HasIndex(PlaceId).IsUnique(), the other declares the same index without it and
        // puts the uniqueness on (UserId, PlaceId) instead. Two calls for the same property list are
        // the SAME index, and the second only renamed it - the IsUnique() set here survived into the
        // model, which is how a UNIQUE landed on place_id alone.
        //
        // That is not a cosmetic mismatch. One row per (user, place) is the whole storage design: a
        // place is suppressed once HideThreshold DIFFERENT people report it, so a unique place_id
        // means reporter number two gets a duplicate-key error and the threshold can never be
        // reached. Do not reintroduce a second configuration block for this entity.

        // Foot Tracker Modules
        modelBuilder.Entity<FavouritePlace>(entity =>
        {
            entity.ToTable("favourite_place");

            entity.Property(f => f.PlaceId).IsRequired().HasMaxLength(255);
            entity.Property(f => f.LastVisitAt).HasColumnType("datetime");
            entity.Property(f => f.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(f => f.Place)
                .WithMany()
                .HasForeignKey(f => f.PlaceId)
                .OnDelete(DeleteBehavior.Cascade); // still your call vs Restrict

            // A user should only be able to favourite a given place once.
            entity.HasIndex(f => new { f.UserId, f.PlaceId })
                .IsUnique()
                .HasDatabaseName("uq_user_place");
        });

        modelBuilder.Entity<Place>(entity =>
        {
            entity.ToTable("places");
            entity.HasKey(p => p.PlaceId);

            entity.Property(p => p.PlaceId).HasMaxLength(255);
            entity.Property(p => p.Name).IsRequired().HasMaxLength(150);
            entity.Property(p => p.Address).IsRequired().HasMaxLength(500);
            entity.Property(p => p.PrimaryType).IsRequired().HasMaxLength(100);
            entity.Property(p => p.BusinessStatus).HasMaxLength(50);
            entity.Property(p => p.GoogleMapsUri).HasMaxLength(500);
            entity.Property(p => p.NationalPhoneNumber).HasMaxLength(50);
            entity.Property(p => p.WebsiteUri).HasMaxLength(500);
            entity.Property(p => p.ShortFormattedAddress).HasMaxLength(500);
            entity.Property(p => p.PrimaryTypeDisplayName).HasMaxLength(100);
            entity.Property(p => p.UserRatingCount).HasDefaultValue(0);

            entity.Property(p => p.PhotosJson).HasColumnType("json");
            entity.Property(p => p.RegularOpeningHoursJson).HasColumnType("json");
            entity.Property(p => p.AccessibilityOptionsJson).HasColumnType("json");
            entity.Property(p => p.AddressComponentsJson).HasColumnType("json");
            entity.Property(p => p.GoogleMapsLinksJson).HasColumnType("json");
            entity.Property(p => p.ViewportJson).HasColumnType("json");
        });

        // ---------------- Post module ----------------

        modelBuilder.Entity<Post>(entity =>
        {
            entity.ToTable("community_posts");
            entity.HasKey(p => p.PostId);
            entity.Property(p => p.PostId).HasMaxLength(36);
            entity.Property(p => p.Title).HasMaxLength(100);
            entity.Property(p => p.Description).HasMaxLength(2000).IsRequired();
            entity.Property(p => p.Status).HasMaxLength(20).IsRequired();
            entity.Property(p => p.ViewsCount).IsRequired();

            entity.HasOne(p => p.Author)
                .WithMany()
                .HasForeignKey(p => p.AuthorId)
                .OnDelete(DeleteBehavior.Cascade);

            // Priority 3: tagged_place_id is a reference-only field (latest_v2.sql
            // defines NO FK and NO index on it). No relationship and no index here.

            entity.HasIndex(p => p.AuthorId);
            entity.HasIndex(p => p.Status);
        });

        modelBuilder.Entity<PostImage>(entity =>
        {
            entity.ToTable("community_post_images");
            entity.HasKey(i => i.ImageId);
            entity.Property(i => i.ImageId).HasMaxLength(36);
            entity.Property(i => i.ImageUrl).IsRequired();
            entity.Property(i => i.DisplayOrder).IsRequired();

            entity.HasOne(i => i.Post)
                .WithMany(p => p.Images)
                .HasForeignKey(i => i.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(i => i.PostId);
            entity.HasIndex(i => new { i.PostId, i.DisplayOrder }).IsUnique();
        });

        modelBuilder.Entity<PostComment>(entity =>
        {
            entity.ToTable("community_post_comments");
            entity.HasKey(c => c.CommentId);
            entity.Property(c => c.CommentId).HasMaxLength(36);
            entity.Property(c => c.Content).HasMaxLength(300).IsRequired();
            entity.Property(c => c.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(c => c.Post)
                .WithMany(p => p.Comments)
                .HasForeignKey(c => c.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(c => c.Author)
                .WithMany()
                .HasForeignKey(c => c.AuthorId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(c => c.PostId);
            entity.HasIndex(c => c.AuthorId);
        });

        modelBuilder.Entity<PostReaction>(entity =>
        {
            entity.ToTable("community_post_reactions");
            entity.HasKey(r => r.ReactionId);
            entity.Property(r => r.ReactionId).HasMaxLength(36);
            entity.Property(r => r.ReactionType).HasMaxLength(20).IsRequired();
            entity.Property(r => r.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(r => r.Post)
                .WithMany(p => p.Reactions)
                .HasForeignKey(r => r.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(r => r.PostId);
            entity.HasIndex(r => r.UserId);
            entity.HasIndex(r => new { r.PostId, r.UserId }).IsUnique();
        });

        modelBuilder.Entity<PostReport>(entity =>
        {
            entity.ToTable("community_post_reports");
            entity.HasKey(r => r.ReportId);
            entity.Property(r => r.ReportId).HasMaxLength(36);
            entity.Property(r => r.Reason).HasMaxLength(100).IsRequired();
            entity.Property(r => r.Status).HasMaxLength(20).IsRequired();
            entity.Property(r => r.WithdrawnAt);

            entity.HasOne(r => r.Post)
                .WithMany(p => p.Reports)
                .HasForeignKey(r => r.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.Reporter)
                .WithMany()
                .HasForeignKey(r => r.ReporterId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(r => r.PostId);
            entity.HasIndex(r => r.ReporterId);
            // NOTE: NO unique index on (PostId, ReporterId) — the schema and
            // seed data (latest_v2.sql) allow duplicate reports from the same
            // reporter on the same post.
        });

        modelBuilder.Entity<UserSavedPost>(entity =>
        {
            entity.ToTable("user_saved_posts");
            entity.HasKey(s => s.SavedId);
            entity.Property(s => s.SavedId).HasMaxLength(36);

            entity.HasOne(s => s.Post)
                .WithMany(p => p.Saves)
                .HasForeignKey(s => s.PostId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(s => s.User)
                .WithMany()
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(s => s.PostId);
            entity.HasIndex(s => s.UserId);
            entity.HasIndex(s => new { s.PostId, s.UserId }).IsUnique();
        });

        // ---------------- Shared module dependencies ----------------

        modelBuilder.Entity<FootTrackerLog>(entity =>
        {
            entity.ToTable("foot_tracker_log");
            entity.HasKey(l => l.LogId);
            entity.Property(l => l.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(l => l.User)
                .WithMany()
                .HasForeignKey(l => l.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // FK to places dropped — foot_tracker_log no longer needs this durability
            // now that favourite_place self-contains its own snapshot. PlaceId stays
            // as a plain, unconstrained column here.

            entity.HasIndex(l => l.UserId);
            entity.HasIndex(l => l.PlaceId);
        });

        // ---------------- My Recommended Places module (normalized schema) ----------------

        modelBuilder.Entity<RecommendPlace>(entity =>
        {
            entity.ToTable("recommended_places");
            entity.HasKey(p => p.RecommendPlaceId);
            entity.Property(p => p.RecommendPlaceId).HasColumnName("recommend_place_id").HasMaxLength(255);
            entity.Property(p => p.Name).HasMaxLength(255).IsRequired();
            entity.Property(p => p.PrimaryType).HasMaxLength(100).IsRequired();
            // No address column. Location is represented ONLY by Latitude + Longitude.
            entity.Property(p => p.Latitude).IsRequired();
            entity.Property(p => p.Longitude).IsRequired();
            entity.Property(p => p.Rating);
            entity.Property(p => p.UserRatingCount).HasDefaultValue(0);
            entity.Property(p => p.PriceLevel);
            entity.Property(p => p.BusinessStatus).HasMaxLength(50).IsRequired();
            entity.Property(p => p.Description).HasColumnType("text");
            entity.Property(p => p.PhotosJson).HasColumnName("photo_json").HasColumnType("json");
        });

        modelBuilder.Entity<PlaceSubmission>(entity =>
        {
            entity.ToTable("place_submissions");
            entity.HasKey(p => p.SubmissionId);
            entity.Property(p => p.SubmissionId).HasMaxLength(36);
            entity.Property(p => p.Status).HasMaxLength(30).IsRequired();

            entity.HasOne(p => p.Submitter)
                .WithMany()
                .HasForeignKey(p => p.SubmitterId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(p => p.Place)
                .WithMany(p => p.Submissions)
                .HasForeignKey(p => p.RecommendPlaceId)
                .HasPrincipalKey(p => p.RecommendPlaceId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(p => p.SubmitterId);
            entity.HasIndex(p => p.RecommendPlaceId);
            entity.HasIndex(p => p.Status);
        });

        modelBuilder.Entity<PlaceSubmissionVerification>(entity =>
        {
            entity.ToTable("recommended_place_verifications");
            entity.HasKey(v => v.VerificationId);
            entity.Property(v => v.VerificationId).HasMaxLength(36);
            entity.Property(v => v.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(v => v.Submission)
                .WithMany(p => p.Verifications)
                .HasForeignKey(v => v.SubmissionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(v => v.User)
                .WithMany()
                .HasForeignKey(v => v.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(v => new { v.SubmissionId, v.UserId }).HasDatabaseName("uq_recommended_place_verifications_submission_user").IsUnique();
            entity.HasIndex(v => v.UserId);
        });

        // ---------------- Communication module (Community Chat) ----------------
        // Kept in sync with database/scripts/CreateTable.sql's "MODULE: Communication" section.

        modelBuilder.Entity<Community>(entity =>
        {
            entity.ToTable("community");
            entity.HasKey(c => c.CommunityId);

            entity.Property(c => c.Name).HasMaxLength(150).IsRequired();
            entity.Property(c => c.Description).HasMaxLength(1000);
            entity.Property(c => c.Area).HasMaxLength(100);
            entity.Property(c => c.State).HasMaxLength(100);
            entity.Property(c => c.ImageUrl).HasMaxLength(500);
            entity.Property(c => c.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasIndex(c => c.State).HasDatabaseName("idx_community_state");
        });

        modelBuilder.Entity<CommunityMember>(entity =>
        {
            entity.ToTable("community_member");
            entity.HasKey(m => m.CommunityMemberId);

            entity.Property(m => m.Role).HasMaxLength(20).HasDefaultValue("Member");
            entity.Property(m => m.IsActive).HasDefaultValue(true);
            entity.Property(m => m.JoinedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");
            entity.Property(m => m.LeftAt).HasColumnType("datetime");

            entity.HasOne<Community>()
                .WithMany()
                .HasForeignKey(m => m.CommunityId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(m => m.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(m => new { m.CommunityId, m.UserId })
                .IsUnique()
                .HasDatabaseName("idx_member_community_user");
        });

        modelBuilder.Entity<Message>(entity =>
        {
            entity.ToTable("message");
            entity.HasKey(m => m.MessageId);

            entity.Property(m => m.Content).HasMaxLength(2000);
            entity.Property(m => m.IsDeleted).HasDefaultValue(false);
            entity.Property(m => m.SentAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<Community>()
                .WithMany()
                .HasForeignKey(m => m.CommunityId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(m => m.SenderUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(m => new { m.CommunityId, m.SentAt }).HasDatabaseName("idx_message_community_sent_at");
        });

        modelBuilder.Entity<MessageAttachment>(entity =>
        {
            entity.ToTable("message_attachment");
            entity.HasKey(a => a.AttachmentId);

            entity.Property(a => a.Type).HasMaxLength(20).IsRequired();
            entity.Property(a => a.MediaUrl).HasMaxLength(500);
            entity.Property(a => a.PlaceId).HasMaxLength(255);
            entity.Property(a => a.PlaceName).HasMaxLength(255);
            entity.Property(a => a.PlaceAddress).HasMaxLength(500);
            entity.Property(a => a.PlaceImageUrl).HasMaxLength(500);
            entity.Property(a => a.PlaceStatus).HasMaxLength(50);
            entity.Property(a => a.PlacePrimaryType).HasMaxLength(100);
            entity.Property(a => a.IsCommunityPlace).HasDefaultValue(false);

            entity.HasOne<Message>()
                .WithMany()
                .HasForeignKey(a => a.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(a => a.MessageId).HasDatabaseName("idx_attachment_message_id");
        });

        modelBuilder.Entity<MessageReport>(entity =>
        {
            entity.ToTable("message_report");
            entity.HasKey(r => r.ReportId);

            entity.Property(r => r.Reason).HasMaxLength(500);
            entity.Property(r => r.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<Message>()
                .WithMany()
                .HasForeignKey(r => r.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(r => r.ReporterUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(r => new { r.MessageId, r.ReporterUserId })
                .IsUnique()
                .HasDatabaseName("idx_report_message_reporter");
        });

        modelBuilder.Entity<HiddenPlaceSuppression>(entity =>
        {
            entity.ToTable("hidden_place_suppression");
            entity.HasKey(s => s.HiddenPlaceSuppressionId);
            entity.Property(s => s.HiddenPlaceSuppressionId).ValueGeneratedOnAdd();
            entity.Property(s => s.UserId).IsRequired().HasDefaultValue(0);
            entity.Property(s => s.PlaceId).HasMaxLength(255).IsRequired();
            entity.Property(s => s.RecommendedPlaceId).HasMaxLength(255);
            entity.Property(s => s.Name).HasMaxLength(255).IsRequired();
            entity.Property(s => s.Reason).HasMaxLength(100).IsRequired();
            entity.Property(s => s.ReportCount).HasDefaultValue(0);
            entity.Property(s => s.SuppressedAt).HasColumnType("timestamp").HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasIndex(s => s.PlaceId).HasDatabaseName("idx_hidden_place_suppression_place_id");
            entity.HasIndex(s => s.RecommendedPlaceId).HasDatabaseName("idx_hidden_place_suppression_recommended_place_id");
            entity.HasIndex(s => s.SuppressedAt).HasDatabaseName("idx_hidden_place_suppression_suppressed_at");
            entity.HasIndex(s => new { s.UserId, s.PlaceId }).HasDatabaseName("uq_hidden_place_suppression_user_place").IsUnique();
        });
    }
}

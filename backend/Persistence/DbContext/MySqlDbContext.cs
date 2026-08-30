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

    // My Recommended Places module
    public DbSet<RecommendedPlace> RecommendedPlaces => Set<RecommendedPlace>();
    public DbSet<RecommendedPlaceVerification> RecommendedPlaceVerifications => Set<RecommendedPlaceVerification>();
    public DbSet<RecommendedPlaceReport> RecommendedPlaceReports => Set<RecommendedPlaceReport>();

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

        modelBuilder.Entity<HiddenPlaceSuppression>(entity =>
        {
            entity.ToTable("hidden_place_suppression");
            entity.HasKey(s => s.HiddenPlaceSuppressionId);

            entity.Property(s => s.PlaceId).HasMaxLength(255);
            entity.Property(s => s.Name).HasMaxLength(255);
            entity.Property(s => s.Reason).HasMaxLength(100);
            entity.Property(s => s.SuppressedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            // Same reasoning as place_photo: no foreign key to hidden_place_cache. A suppression
            // whose lifetime was tied to a cache row would be erased by the very refresh it is
            // meant to survive, and the reported place would come straight back.
            entity.HasIndex(s => s.PlaceId).IsUnique();
        });


        modelBuilder.Entity<FavouritePlace>(entity =>
        {
            entity.ToTable("favourite_place");

            entity.Property(f => f.PlaceId).HasMaxLength(255);
            entity.Property(f => f.Name).HasMaxLength(255);
            entity.Property(f => f.PrimaryType).HasMaxLength(100);
            entity.Property(f => f.Address).HasMaxLength(500);
            entity.Property(f => f.LastVisitAt).HasColumnType("datetime");
            entity.Property(f => f.CreatedAt)
                .HasColumnType("timestamp")
                .HasDefaultValueSql("CURRENT_TIMESTAMP");

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // A user should only be able to favourite a given real-world place once.
            // This composite index also covers lookups by user_id alone, so no
            // separate FK index is needed.
            entity.HasIndex(f => new { f.UserId, f.PlaceId })
                .IsUnique()
                .HasDatabaseName("uq_user_place");
        });

        // ---------------- Post module ----------------

        modelBuilder.Entity<Place>(entity =>
        {
            entity.ToTable("places");
            entity.HasKey(p => p.PlaceId);
            entity.Property(p => p.Name).HasMaxLength(150).IsRequired();
            entity.Property(p => p.Address).HasMaxLength(250).IsRequired();
            entity.Property(p => p.Category).HasMaxLength(50).IsRequired();
        });

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

            entity.HasOne(p => p.TaggedPlace)
                .WithMany()
                .HasForeignKey(p => p.TaggedPlaceId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(p => p.AuthorId);
            entity.HasIndex(p => p.TaggedPlaceId);
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
            entity.HasIndex(r => new { r.PostId, r.ReporterId }).IsUnique();
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

            entity.HasOne(l => l.Place)
                .WithMany()
                .HasForeignKey(l => l.PlaceId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasIndex(l => l.UserId);
            entity.HasIndex(l => l.PlaceId);
        });

        // ---------------- My Recommended Places module ----------------

        modelBuilder.Entity<RecommendedPlace>(entity =>
        {
            entity.ToTable("recommended_places");
            entity.HasKey(p => p.SubmissionId);
            entity.Property(p => p.SubmissionId).HasMaxLength(36);
            entity.Property(p => p.Name).HasMaxLength(150).IsRequired();
            entity.Property(p => p.LocationAddress).HasMaxLength(250).IsRequired();
            entity.Property(p => p.Latitude).HasPrecision(10, 7);
            entity.Property(p => p.Longitude).HasPrecision(10, 7);
            entity.Property(p => p.Category).HasMaxLength(50).IsRequired();
            entity.Property(p => p.Description).HasMaxLength(500);
            entity.Property(p => p.Status).HasMaxLength(30).IsRequired();

            entity.HasOne(p => p.Submitter)
                .WithMany()
                .HasForeignKey(p => p.SubmitterId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(p => p.SubmitterId);
            entity.HasIndex(p => p.Status);
        });

        modelBuilder.Entity<RecommendedPlaceVerification>(entity =>
        {
            entity.ToTable("recommended_place_verifications");
            entity.HasKey(v => v.VerificationId);
            entity.Property(v => v.VerificationId).HasMaxLength(36);
            entity.Property(v => v.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(v => v.Place)
                .WithMany(p => p.Verifications)
                .HasForeignKey(v => v.SubmissionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(v => v.User)
                .WithMany()
                .HasForeignKey(v => v.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(v => new { v.SubmissionId, v.UserId }).IsUnique();
            entity.HasIndex(v => v.UserId);
        });

        modelBuilder.Entity<RecommendedPlaceReport>(entity =>
        {
            entity.ToTable("recommended_place_reports");
            entity.HasKey(r => r.ReportId);
            entity.Property(r => r.ReportId).HasMaxLength(36);
            entity.Property(r => r.Reason).HasMaxLength(100).IsRequired();
            entity.Property(r => r.Status).HasMaxLength(20).IsRequired();

            entity.HasOne(r => r.Place)
                .WithMany(p => p.Reports)
                .HasForeignKey(r => r.SubmissionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.Reporter)
                .WithMany()
                .HasForeignKey(r => r.ReporterId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(r => new { r.SubmissionId, r.ReporterId }).IsUnique();
            entity.HasIndex(r => r.ReporterId);

        });
    }
}


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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.Email)
                .IsUnique();
        });

        modelBuilder.Entity<EmailVerificationToken>(entity =>
        {
            entity.ToTable("email_verification_token");
            entity.HasKey(t => t.TokenId);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(t => t.UserId);
            entity.HasIndex(t => t.Token).IsUnique();
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.ToTable("password_reset_token");
            entity.HasKey(t => t.TokenId);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(t => t.UserId);
            entity.HasIndex(t => t.Token).IsUnique();
        });

        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.ToTable("user_session");
            entity.HasKey(s => s.SessionId);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(s => s.UserId);
        });

        modelBuilder.Entity<HiddenPlace>(entity =>
        {
            entity.ToTable("hidden_place_cache");
            entity.HasKey(p => p.HiddenPlaceCacheId);

            // A bucket (CacheGridKey) is replaced wholesale on refetch, and within a bucket a given
            // real-world place (PlaceId) should only appear once.
            entity.HasIndex(p => new { p.CacheGridKey, p.PlaceId }).IsUnique();
        });
    }
}
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
    }
}
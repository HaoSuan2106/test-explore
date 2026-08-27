using ExploreMy.Api.Application.AuthProfile.ManageProfile;
using ExploreMy.Api.Common.Exceptions;
using ExploreMy.Api.Common.Helpers;
using ExploreMy.Api.Configuration;
using ExploreMy.Api.DataAccess.ExternalClients.SupabaseStorage;
using ExploreMy.Api.DataAccess.Repositories.AuthProfile;
using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.DTOs.AuthProfile;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;

namespace ExploreMy.Backend.Tests;

public class ChangePasswordServiceTests
{
    private readonly Mock<IAuthProfileRepository> _repository = new();

    [Fact]
    public async Task VerifyCurrentPassword_CorrectPassword_Succeeds()
    {
        var user = UserWithPassword("Current1!");
        _repository.Setup(r => r.GetByIdAsync(user.UserId)).ReturnsAsync(user);

        await CreateService().VerifyCurrentPasswordAsync(
            user.UserId,
            new CheckPasswordRequestDto { CurrentPassword = "Current1!" });
    }

    [Fact]
    public async Task VerifyCurrentPassword_IncorrectPassword_ThrowsAuthenticationException()
    {
        var user = UserWithPassword("Current1!");
        _repository.Setup(r => r.GetByIdAsync(user.UserId)).ReturnsAsync(user);

        await Assert.ThrowsAsync<AuthenticationException>(() =>
            CreateService().VerifyCurrentPasswordAsync(
                user.UserId,
                new CheckPasswordRequestDto { CurrentPassword = "Wrong1!" }));
    }

    [Fact]
    public async Task UpdatePassword_WithCurrentPassword_UpdatesHash()
    {
        var user = UserWithPassword("Current1!");
        _repository.Setup(r => r.GetByIdAsync(user.UserId)).ReturnsAsync(user);

        await CreateService().UpdatePasswordAsync(
            user.UserId,
            new UpdatePasswordRequestDto
            {
                CurrentPassword = "Current1!",
                NewPassword = "Updated2!"
            });

        Assert.True(PasswordHasher.VerifyPassword("Updated2!", user.PasswordHash));
        _repository.Verify(r => r.UpdateUserAsync(user), Times.Once);
        _repository.Verify(r => r.InvalidateActivePasswordResetTokensAsync(user.UserId), Times.Once);
    }

    [Fact]
    public async Task UpdatePassword_WithVerifiedResetCode_ConsumesCodeAndUpdatesHash()
    {
        var user = UserWithPassword("Current1!");
        var resetToken = new PasswordResetToken
        {
            UserId = user.UserId,
            Token = RefreshTokenHelper.Hash("123456"),
            ExpiresAt = DateTime.UtcNow.AddMinutes(5)
        };
        _repository.Setup(r => r.GetByIdAsync(user.UserId)).ReturnsAsync(user);
        _repository
            .Setup(r => r.GetLatestActivePasswordResetTokenByUserIdAsync(user.UserId))
            .ReturnsAsync(resetToken);

        await CreateService().UpdatePasswordAsync(
            user.UserId,
            new UpdatePasswordRequestDto
            {
                ResetCode = "123456",
                NewPassword = "Updated2!"
            });

        Assert.True(PasswordHasher.VerifyPassword("Updated2!", user.PasswordHash));
        _repository.Verify(r => r.MarkPasswordResetTokenUsedAsync(resetToken), Times.Once);
    }

    private ManageProfileService CreateService() => new(
        _repository.Object,
        Mock.Of<IStorageClient>(),
        Mock.Of<IEmailSender>(),
        Options.Create(new SmtpSettings()),
        NullLogger<ManageProfileService>.Instance);

    private static User UserWithPassword(string password) => new()
    {
        UserId = 7,
        Username = "explorer",
        Email = "explorer@example.com",
        PasswordHash = PasswordHasher.HashPassword(password),
        AccountStatus = "active"
    };
}

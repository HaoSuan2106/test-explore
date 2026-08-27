using System.ComponentModel.DataAnnotations;
using ExploreMy.Api.DTOs.AuthProfile;

namespace ExploreMy.Backend.Tests;

public class PasswordPolicyTests
{
    [Theory]
    [InlineData("Explore1!", true)]
    [InlineData("Abc1!", false)]
    [InlineData("Explore!", false)]
    [InlineData("Explore1", false)]
    public void RegisterPassword_EnforcesRequiredPolicy(string password, bool expectedValid)
    {
        var request = new RegisterRequestDto
        {
            Username = "explorer",
            Email = "explorer@example.com",
            Password = password
        };

        var results = new List<ValidationResult>();
        var isValid = Validator.TryValidateObject(
            request,
            new ValidationContext(request),
            results,
            validateAllProperties: true);

        Assert.Equal(expectedValid, isValid);
    }
}

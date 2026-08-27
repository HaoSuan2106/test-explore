namespace ExploreMy.Api.Domain.Entities;

public class FavouritePlace
{
    public int FavouritePlaceId { get; set; }
    public int UserId { get; set; }
    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string PrimaryType { get; set; } = string.Empty;
    public string? Address { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime? LastVisitAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
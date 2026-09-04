namespace ExploreMy.Api.Domain.Entities;

public class FavouritePlace
{
    public int FavouritePlaceId { get; set; }
    public int UserId { get; set; }
    public string PlaceId { get; set; } = string.Empty;
    public Place? Place { get; set; }
    public DateTime? LastVisitAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
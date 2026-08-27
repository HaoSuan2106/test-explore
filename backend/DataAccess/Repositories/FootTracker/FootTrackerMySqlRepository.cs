using ExploreMy.Api.Domain.Entities;
using ExploreMy.Api.Persistence.DbContext;
using Microsoft.EntityFrameworkCore;

namespace ExploreMy.Api.DataAccess.Repositories.FootTracker;

public class FootTrackerMySqlRepository : IFootTrackerRepository
{
    private readonly MySqlDbContext _context;

    public FootTrackerMySqlRepository(MySqlDbContext context)
    {
        _context = context;
    }

    public async Task<List<FavouritePlace>> GetFavouritePlacesByUserIdAsync(int userId)
    {
        return await _context.FavouritePlaces
            .Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();
    }

    public async Task<FavouritePlace?> GetFavouritePlaceByUserAndPlaceIdAsync(int userId, string placeId)
    {
        return await _context.FavouritePlaces
            .FirstOrDefaultAsync(f => f.UserId == userId && f.PlaceId == placeId);
    }

    public async Task AddFavouritePlaceAsync(FavouritePlace favouritePlace)
    {
        _context.FavouritePlaces.Add(favouritePlace);
        await _context.SaveChangesAsync();
    }

    public async Task RemoveFavouritePlacesAsync(int userId, List<int> favouritePlaceIds)
    {
        var toRemove = await _context.FavouritePlaces
            .Where(f => f.UserId == userId && favouritePlaceIds.Contains(f.FavouritePlaceId))
            .ToListAsync();

        _context.FavouritePlaces.RemoveRange(toRemove);
        await _context.SaveChangesAsync();
    }
}

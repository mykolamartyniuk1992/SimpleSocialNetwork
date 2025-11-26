using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Service.ModelProfileService;
using System.Linq;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Controllers
{
    public partial class FeedController : ControllerBase
    {
        [HttpGet("getlikespaginated/{feedId}")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult> GetLikesPaginated(int feedId, [FromQuery] int page = 1, [FromQuery] int pageSize = 5)
        {
            var likes = await _feeds.GetLikesForFeedAsync(feedId);
            var totalCount = likes.Count;
            var pagedLikes = likes
                .OrderByDescending(l => l.id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();
            var result = new System.Collections.Generic.List<object>();
            foreach (var l in pagedLikes)
            {
                string photoPath = await _profiles.GetPhotoPathAsync(l.profileId);
                result.Add(new {
                    profileName = l.profileName,
                    photoPath = string.IsNullOrWhiteSpace(photoPath) ? null : photoPath
                });
            }
            return Ok(new { likes = result, totalCount });
        }
    }
}

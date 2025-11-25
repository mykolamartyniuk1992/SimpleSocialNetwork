using Humanizer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Service.ModelProfileService;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Controllers
{
    [ApiController]
    [Route("api/feed")]
    public class FeedController : ControllerBase
    {
        private readonly IModelFeedService _feeds;
        private readonly IHubContext<FeedHub> _hub;
        private readonly IModelProfileService _profiles;

        public FeedController(IModelFeedService feeds, IHubContext<FeedHub> hub, IModelProfileService profiles)
        {
            _feeds = feeds;
            _hub  = hub;
            _profiles = profiles;
        }

        [HttpGet("hello")]
        public ActionResult<string> Hello() => "Hello there";

        [HttpPost("getfeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]                            // фильтр сам проверит куки
        public ActionResult<IEnumerable<DtoFeed>> GetFeed()
            => Ok(_feeds.GetFeed());

        [HttpGet("getfeedpaginated")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult> GetFeedPaginated([FromQuery] int page = 1, [FromQuery] int pageSize = 5)
        {
            var (feeds, totalCount) = await _feeds.GetFeedPaginatedAsync(page, pageSize);
            return Ok(new { feeds, totalCount, page, pageSize });
        }

        [HttpGet("getcomments/{feedId}")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public ActionResult<IEnumerable<DtoFeed>> GetComments(int feedId)
            => Ok(_feeds.GetComments(feedId));

        [HttpGet("getcommentspaginated/{feedId}")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult> GetCommentsPaginated(int feedId, [FromQuery] int page = 1, [FromQuery] int pageSize = 5)
        {
            var (comments, totalCount) = await _feeds.GetCommentsPaginatedAsync(feedId, page, pageSize);
            return Ok(new { comments, totalCount, page, pageSize });
        }

        [HttpPost("addfeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult<int>> AddFeed([FromBody] DtoFeed dto)
        {
            // Get userId from HttpContext (set by IsAuthenticatedAttribute)
            var userId = HttpContext.Items["UserId"] as int?;
            if (userId == null)
            {
                // Fallback to cookies for backward compatibility
                dto.name = Request.Cookies["name"];
                dto.token = Request.Cookies["token"];
            }
            
            // Check message limit for unverified users
            int? updatedMessagesLeft = null;
            if (userId.HasValue)
            {
                var result = await _profiles.DecrementMessagesLeftAsync(userId.Value);
                updatedMessagesLeft = result.messagesLeft;
                if (!result.canPost)
                {
                    return BadRequest(new { message = "Message limit reached. Please verify your account to continue posting." });
                }
            }
            
            dto.id = _feeds.AddFeed(dto, userId);
            
            // Get the full feed item with all properties including profilePhotoPath
            var newFeed = _feeds.GetFeed().FirstOrDefault(f => f.id == dto.id);
            if (newFeed != null)
            {
                if (dto.parentId.HasValue)
                {
                    // It's a comment, broadcast to specific feed
                    await _hub.Clients.All.SendAsync("NewComment", newFeed);
                }
                else
                {
                    // It's a top-level post
                    await _hub.Clients.All.SendAsync("NewFeedPost", newFeed);
                }
            }
            
            return Ok(new { id = dto.id, messagesLeft = updatedMessagesLeft });
        }

        [HttpPost("deletefeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<IActionResult> DeleteFeed([FromBody] DtoFeed dto)
        {
            // Get userId from HttpContext (set by IsAuthenticatedAttribute)
            var userId = HttpContext.Items["UserId"] as int?;
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            // Verify ownership
            var feedItem = _feeds.GetAllFeeds().FirstOrDefault(f => f.id == dto.id);
            if (feedItem == null)
            {
                return NotFound();
            }

            // Check if user is the owner (by comparing profile IDs)
            if (feedItem.profileId != userId.Value)
            {
                return Forbid(); // User is not the owner
            }

            _feeds.DeleteFeed(dto.id);
            await _hub.Clients.All.SendAsync("FeedDeleted", dto.id);
            return NoContent();
        }

        [HttpPost("like")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult<DtoLike>> Like([FromBody] DtoLike like)
        {
            // Get userId from HttpContext (set by IsAuthenticatedAttribute)
            var userId = HttpContext.Items["UserId"] as int?;
            if (userId == null)
            {
                // Fallback to cookies for backward compatibility
                like.token = Request.Cookies["token"];
                like.profileName = Request.Cookies["name"];
            }
            
            like.id = _feeds.Like(like, userId);
            
            // Get updated feed item and broadcast to all clients
            var updatedFeed = _feeds.GetFeed().FirstOrDefault(f => f.id == like.feedId);
            if (updatedFeed == null)
            {
                // It might be a comment, try to get it from all feeds
                updatedFeed = _feeds.GetAllFeeds().FirstOrDefault(f => f.id == like.feedId);
            }
            
            if (updatedFeed != null)
            {
                await _hub.Clients.All.SendAsync("FeedLikeUpdated", updatedFeed);
            }
            
            return Ok(like);
        }

        [HttpPost("dislike")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<IActionResult> Dislike([FromBody] DtoLike like)
        {
            _feeds.Dislike(like.id);
            
            // Get updated feed item and broadcast to all clients
            var updatedFeed = _feeds.GetFeed().FirstOrDefault(f => f.id == like.feedId);
            if (updatedFeed == null)
            {
                // It might be a comment, try to get it from all feeds
                updatedFeed = _feeds.GetAllFeeds().FirstOrDefault(f => f.id == like.feedId);
            }
            
            if (updatedFeed != null)
            {
                await _hub.Clients.All.SendAsync("FeedLikeUpdated", updatedFeed);
            }
            
            return NoContent();
        }
    }
}

using Humanizer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Service.ModelFeedService;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Controllers
{
    [ApiController]
    [Route("api/feed")]
    public class FeedController : ControllerBase
    {
        private readonly IModelFeedService _feeds;
        private readonly IHubContext<FeedHub> _hub;

        public FeedController(IModelFeedService feeds, IHubContext<FeedHub> hub)
        {
            _feeds = feeds;
            _hub  = hub;
        }

        [HttpGet("hello")]
        public ActionResult<string> Hello() => "Hello there";

        [HttpPost("getfeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]                            // фильтр сам проверит куки
        public ActionResult<IEnumerable<DtoFeed>> GetFeed()
            => Ok(_feeds.GetFeed());

        [HttpPost("addfeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult<int>> AddFeed([FromBody] DtoFeed dto)
        {
            // автор берётся с куки (JS не шлёт name/token)
            dto.name = Request.Cookies["name"];
            dto.token = Request.Cookies["token"];
            dto.id = _feeds.AddFeed(dto);
            await _hub.Clients.All.SendAsync("newFeed", dto);
            return Ok(dto.id);
        }

        [HttpPost("deletefeed")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<IActionResult> DeleteFeed([FromBody] DtoFeed dto)
        {
            // автор берётся с куки (JS не шлёт name/token)
            dto.name = Request.Cookies["name"];
            dto.token = Request.Cookies["token"];

            _feeds.DeleteFeed(dto.id);
            await _hub.Clients.All.SendAsync("deleteFeed", dto);
            return NoContent();
        }

        [HttpPost("like")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<ActionResult<DtoLike>> Like([FromBody] DtoLike like)
        {
            // автор берётся с куки (JS не шлёт name/token)
            like.token = Request.Cookies["token"];
            like.profileName = Request.Cookies["name"];
            like.id = _feeds.Like(like);
            await _hub.Clients.All.SendAsync("like", like);
            return Ok(like);
        }

        [HttpPost("dislike")]
        [ServiceFilter(typeof(IsAuthenticatedAttribute))]
        public async Task<IActionResult> Dislike([FromBody] DtoLike like)
        {
            _feeds.Dislike(like.id);
            await _hub.Clients.All.SendAsync("unlike", like);
            return NoContent();
        }
    }
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Hubs;
using SimpleSocialNetwork.Service.ModelFeedService;

namespace SimpleSocialNetwork.Controllers
{
    [IsAuthenticated]
    public class FeedController : ApiController
    {
        [HttpGet]
        public string Hello()
        {
            return "Hello there";
        }

        [HttpPost]
        public IEnumerable<DtoFeed> GetFeed(DtoProfile profile)
        {
            return new ModelFeedService().GetFeed();
        }

        [HttpPost]
        public int AddFeed(DtoFeed dtoFeed)
        {
            dtoFeed.id = new ModelFeedService().AddFeed(dtoFeed);
            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.newFeed(dtoFeed);

            return dtoFeed.id;
        }

        [HttpPost]
        public void DeleteFeed(DtoFeed dtoFeed)
        {
            var cookies = Request.Headers.GetCookies().FirstOrDefault();
            var name = cookies["name"];
            var token = cookies["token"];
            if (dtoFeed.name != name.Value || dtoFeed.token != token.Value) throw new HttpException(403, "you are not the author of this post!");
            new ModelFeedService().DeleteFeed(dtoFeed.id);

            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.deleteFeed(dtoFeed);
        }

        [HttpPost]
        public DtoLike Like(DtoLike dtoLike)
        {
            dtoLike.id = new ModelFeedService().Like(dtoLike);

            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.like(dtoLike);

            return dtoLike;
        }

        [HttpPost]
        public void Dislike(DtoLike dtoLike)
        {
            new ModelFeedService().Dislike(dtoLike.id);
             
            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.unlike(dtoLike);
        }
    }
}
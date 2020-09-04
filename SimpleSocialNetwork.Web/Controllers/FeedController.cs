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
    public class FeedController : ApiController
    {
        [HttpGet]
        public string Hello()
        {
            return "Hello there";
        }

        [HttpPost]
        [IsAuthenticated]
        public IEnumerable<DtoFeed> GetFeed(DtoProfile profile)
        {
            return new ModelFeedService().GetFeed();
        }

        [HttpPost]
        [IsAuthenticated]
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
        [IsAuthenticated]
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
        [IsAuthenticated]
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
        [IsAuthenticated]
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
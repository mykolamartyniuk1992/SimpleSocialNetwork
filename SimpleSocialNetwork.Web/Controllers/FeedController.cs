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
        [IsAuthenticated]
        [HttpPost]
        public void Hello()
        {

        }

        [IsAuthenticated]
        [HttpPost]
        public IEnumerable<DtoFeed> GetFeed(DtoProfile profile)
        {
            return new ModelFeedService().GetFeed();
        }

        [IsAuthenticated]
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

        [IsAuthenticated]
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

        [IsAuthenticated]
        [HttpPost]
        public DtoLike Like(DtoLike like)
        {
            like.id = new ModelFeedService().Like(like);

            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.like(like);

            return like;
        }

        [IsAuthenticated]
        [HttpPost]
        public void Dislike(int likeId)
        {
            var like = new ModelFeedService().Dislike(likeId);
             
            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.unlike(like);
        }
    }
}
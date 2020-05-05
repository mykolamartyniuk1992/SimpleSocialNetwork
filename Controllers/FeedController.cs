using SimpleSocialNetwork.App_Code;
using SimpleSocialNetwork.App_Code.Database;
using SimpleSocialNetwork.App_Code.Database.Dto;
using SimpleSocialNetwork.App_Code.Database.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Web;
using System.Web.Http;

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
        public List<DtoFeed> GetFeed(DtoProfile profile)
        {
            List <DtoFeed> dtoFeed = new List<DtoFeed>();
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var feed = context.feed.ToList();
                foreach(var f in feed)
                {
                    var dtoLikes = new List<DtoLike>();
                    foreach (var l in f.Likes)
                    {
                        var dtoLike = new DtoLike()
                        {
                            id = l.Id,
                            feedId = l.FeedId,
                            profileName = l.Profile.Name
                        };
                        dtoLikes.Add(dtoLike);
                    }
                    dtoFeed.Add(new DtoFeed()
                    {
                        name = f.Profile.Name,
                        text = f.Text,
                        date = f.DateAdd.ToString(),
                        id = f.Id,
                        parentId = f.ParentId,
                        likes = dtoLikes
                    });
                }
            }
            return dtoFeed;
        }

        [IsAuthenticated]
        [HttpPost]
        public int AddFeed(DtoFeed dtoFeed)
        {
            ModelFeed modelFeed;
            using (var context = new SimpleSocialNetworkDbContext())
            {
                modelFeed = new ModelFeed()
                {
                    DateAdd = DateTime.Now,
                    ProfileId = context.profiles.Where(p => p.Name == dtoFeed.name && p.Token == dtoFeed.token).FirstOrDefault().Id,
                    Text = dtoFeed.text,
                    ParentId = dtoFeed.parentId
                };
                context.feed.Add(modelFeed);
                context.SaveChanges();
            }

            dtoFeed.id = modelFeed.Id;
            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.newFeed(dtoFeed);

            return modelFeed.Id;
        }

        [IsAuthenticated]
        [HttpPost]
        public void DeleteFeed(DtoFeed dtoFeed)
        {
            var cookies = Request.Headers.GetCookies().FirstOrDefault();
            var name = cookies["name"];
            var token = cookies["token"];
            if (dtoFeed.name != name.Value || dtoFeed.token != token.Value) throw new HttpException(403, "you are not the author of this post!");
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var modelFeed = context.feed.Where(f => f.Id == dtoFeed.id).FirstOrDefault();

                RecoursiveDelete(modelFeed, context);

                context.SaveChanges();
            }

            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.deleteFeed(dtoFeed);
        }

        private void RecoursiveDelete(ModelFeed parent, SimpleSocialNetworkDbContext context)
        {
            if (parent.Children.Count != 0)
            {
                foreach (var child in parent.Children.ToList())
                {
                    RecoursiveDelete(child, context);
                }
            }
            context.likes.RemoveRange(context.likes.Where(l => l.FeedId == parent.Id));
            context.feed.Remove(parent);
        }

        //[IsAuthenticated]
        //[HttpPost]
        //public bool IsLiked(DtoLike like)
        //{
        //    using (var context = new SimpleSocialNetworkDbContext())
        //    {
        //        var modelLike = 
        //    }
        //}

        [IsAuthenticated]
        [HttpPost]
        public DtoLike Like(DtoLike like)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var modelLike = new ModelLike()
                {
                    FeedId = like.feedId,
                    ProfileId = context.profiles.Where(profile => profile.Name == like.profileName && profile.Token == like.token).FirstOrDefault().Id
                };
                context.likes.Add(modelLike);
                context.SaveChanges();
                like.id = modelLike.Id;
                
            }

            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.like(like);

            return like;
        }

        [IsAuthenticated]
        [HttpPost]
        public void Dislike(DtoLike like)
        {
            using (var context = new SimpleSocialNetworkDbContext())
            {
                var model = context.likes.Where(l => l.Id == like.id).FirstOrDefault();
                like.feedId = model.FeedId;
                like.profileName = model.Profile.Name;
                context.likes.Remove(model);
                context.SaveChanges();
            }
             
            // Получаем контекст хаба
            var cntxt =
                Microsoft.AspNet.SignalR.GlobalHost.ConnectionManager.GetHubContext<FeedHub>();
            // отправляем сообщение
            cntxt.Clients.All.unlike(like);
        }
    }
}
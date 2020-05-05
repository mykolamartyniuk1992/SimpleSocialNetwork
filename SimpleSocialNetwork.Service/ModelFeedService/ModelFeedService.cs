using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.DbContexts;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelFeedService
{
    public class ModelFeedService : IModelFeedService
    {
        public IEnumerable<DtoFeed> GetFeed()
        {
            var feedRepo = new ModelFeedRepository();
            var likesRepo = new ModelLikeRepository();
            var dtoFeed = new List<DtoFeed>();

            var feed = feedRepo.GetAll();
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likesRepo.Where(l => l.FeedId == f.Id);
                foreach (var l in likes)
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

            return dtoFeed;
        }

        public int AddFeed(DtoFeed dtoFeed)
        {
            ModelFeed modelFeed;
            var feedRepo = new ModelFeedRepository();
            var profileRepo = new ModelProfileRepository();

            modelFeed = new ModelFeed()
            {
                DateAdd = DateTime.Now,
                ProfileId = profileRepo.FirstOrDefault(p => p.Name == dtoFeed.name && p.Token == dtoFeed.token).Id,
                Text = dtoFeed.text,
                ParentId = dtoFeed.parentId
            };

            return feedRepo.Add(modelFeed).Id;
        }

        public void DeleteFeed(int feedId)
        {
            new ModelFeedRepository().RecoursiveDelete(feedId);
        }

        public int Like(DtoLike like)
        {
            var profileRepo = new ModelProfileRepository();
            var likeRepo = new ModelLikeRepository();
            var modelLike = new ModelLike()
            {
                FeedId = like.feedId,
                ProfileId = profileRepo.FirstOrDefault(profile => profile.Name == like.profileName && profile.Token == like.token).Id
            };
            return likeRepo.Add(modelLike).Id;
        }

        public DtoLike Dislike(int likeId)
        {
            var likeRepo = new ModelLikeRepository();
            var like = new DtoLike();
            var model = likeRepo.FirstOrDefault(l => l.Id == likeId);
            like.feedId = model.FeedId;
            like.profileName = model.Profile.Name;
            likeRepo.Delete(model);
            return like;
        }
    }
}

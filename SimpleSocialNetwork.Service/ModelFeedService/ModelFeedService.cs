using System;
using System.Collections.Generic;
using System.Linq;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelFeedService
{
    // my test commit for CI
    public class ModelFeedService : IModelFeedService
    {
        private static IRepository<ModelFeed> feedRepo;
        private static IRepository<ModelLike> likeRepo;
        private static IRepository<ModelProfile> profileRepo;

        public ModelFeedService()
        {
            feedRepo = new ModelFeedRepository();
            likeRepo = new ModelLikeRepository();
            profileRepo = new ModelProfileRepository();
        }

        public ModelFeedService(
            IRepository<ModelFeed> feedRepo,
            IRepository<ModelLike> likeRepo,
            IRepository<ModelProfile> profileRepo)
        {
            ModelFeedService.feedRepo = feedRepo;
            ModelFeedService.likeRepo = likeRepo;
            ModelFeedService.profileRepo = profileRepo;
        }

        public IEnumerable<DtoFeed> GetFeed()
        {
            var dtoFeed = new List<DtoFeed>();

            var feed = feedRepo.GetAll().ToList();
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                //var likes = likeRepo.Where(l => l.FeedId == f.Id);
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

            return dtoFeed;
        }

        public int AddFeed(DtoFeed dtoFeed)
        {
            ModelFeed modelFeed;
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
            // TODO: someting wrong with this func
            (feedRepo as ModelFeedRepository).RecoursiveDelete(feedId);
        }

        public int Like(DtoLike like)
        {
            var modelLike = new ModelLike()
            {
                FeedId = like.feedId,
                ProfileId = profileRepo.FirstOrDefault(profile => profile.Name == like.profileName && profile.Token == like.token).Id
            };
            return likeRepo.Add(modelLike).Id;
        }

        public DtoLike Dislike(int likeId)
        {
            var like = new DtoLike();
            var model = likeRepo.FirstOrDefault(l => l.Id == likeId);
            like.feedId = model.FeedId;
            like.profileName = model.Profile.Name;
            likeRepo.Delete(model);
            return like;
        }
    }
}

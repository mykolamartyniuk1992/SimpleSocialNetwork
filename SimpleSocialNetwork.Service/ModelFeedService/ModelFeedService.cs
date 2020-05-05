using System;
using System.Collections.Generic;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelFeedService
{
    public class ModelFeedService : IModelFeedService
    {
        private IRepository<ModelFeed> feedRepo;
        private IRepository<ModelLike> likeRepo;
        private IRepository<ModelProfile> profileRepo;

        public ModelFeedService()
        {
            this.feedRepo = new ModelFeedRepository();
            this.likeRepo = new ModelLikeRepository();
            this.profileRepo = new ModelProfileRepository();
        }

        public ModelFeedService(
            IRepository<ModelFeed> feedRepo,
            IRepository<ModelLike> likeRepo,
            IRepository<ModelProfile> profileRepo)
        {
            this.feedRepo = feedRepo;
            this.likeRepo = likeRepo;
            this.profileRepo = profileRepo;
        }

        public IEnumerable<DtoFeed> GetFeed()
        {
            var dtoFeed = new List<DtoFeed>();

            var feed = feedRepo.GetAll();
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likeRepo.Where(l => l.FeedId == f.Id);
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
            (this.feedRepo as ModelFeedRepository).RecoursiveDelete(feedId);
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

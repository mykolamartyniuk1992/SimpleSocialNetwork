using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using SimpleSocialNetwork.Data;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;

namespace SimpleSocialNetwork.Service.ModelFeedService
{
    // my test commit for CI
    public class ModelFeedService : IModelFeedService
    {
        private IRepository<ModelFeed> feedRepo;
        private IRepository<ModelLike> likeRepo;
        private IRepository<ModelProfile> profileRepo;

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

            var feed = feedRepo.GetAllAsync().Result;
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likeRepo.WhereAsync(l => l.FeedId == f.Id).Result;
                if (likes.Any())
                {
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
                }
                ModelProfile modelProfile = profileRepo.FirstOrDefaultAsync(p => p.Id == f.ProfileId).Result;
                if (modelProfile != null)
                {
                    dtoFeed.Add(new DtoFeed()
                    {
                        name = modelProfile.Name,
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

        public int AddFeed(DtoFeed dtoFeed)
        {
            ModelFeed modelFeed;
            int modelProfileId = 0;
            ModelProfile modelProfile = profileRepo.FirstOrDefaultAsync(p => p.Name == dtoFeed.name && p.Token == dtoFeed.token)
                .Result;
            if (modelProfile != null)
            {
                modelProfileId = modelProfile.Id;
            }
            else
            {
                throw new Exception("Profile not found");
            }
            modelFeed = new ModelFeed()
            {
                DateAdd = DateTime.Now,
                ProfileId = modelProfileId,
                Text = dtoFeed.text,
                ParentId = dtoFeed.parentId
            };

            return feedRepo.AddAsync(modelFeed).Result.Id;
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
                ProfileId = profileRepo.FirstOrDefaultAsync(profile => profile.Name == like.profileName && profile.Token == like.token).Result.Id
            };
            return likeRepo.AddAsync(modelLike).Result.Id;
        }

        public DtoLike Dislike(int likeId)
        {
            var like = new DtoLike();
            var model = likeRepo.FirstOrDefaultAsync(l => l.Id == likeId).Result;
            like.feedId = model.FeedId;
            like.profileName = model.Profile.Name;
            likeRepo.DeleteAsync(model);
            return like;
        }
    }
}

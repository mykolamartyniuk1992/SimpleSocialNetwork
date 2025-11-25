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

            // Only get top-level posts (no parent)
            var feed = feedRepo.WhereAsync(f => f.ParentId == null).Result;
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likeRepo.WhereAsync(l => l.FeedId == f.Id).Result;
                if (likes.Any())
                {
                    foreach (var l in likes)
                    {
                        var profile = profileRepo.FirstOrDefaultAsync(p => p.Id == l.ProfileId).Result;
                        var dtoLike = new DtoLike()
                        {
                            id = l.Id,
                            feedId = l.FeedId,
                            profileId = l.ProfileId,
                            profileName = profile.Name
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
                        profileId = f.ProfileId,
                        likes = dtoLikes,
                        profilePhotoPath = modelProfile.PhotoPath
                    });
                }
                
            }

            return dtoFeed;
        }

        public IEnumerable<DtoFeed> GetAllFeeds()
        {
            var dtoFeed = new List<DtoFeed>();

            // Get ALL feeds including comments (no parent filter)
            var feed = feedRepo.GetAllAsync().Result;
            foreach (var f in feed)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likeRepo.WhereAsync(l => l.FeedId == f.Id).Result;
                if (likes.Any())
                {
                    foreach (var l in likes)
                    {
                        var profile = profileRepo.FirstOrDefaultAsync(p => p.Id == l.ProfileId).Result;
                        var dtoLike = new DtoLike()
                        {
                            id = l.Id,
                            feedId = l.FeedId,
                            profileId = l.ProfileId,
                            profileName = profile.Name
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
                        profileId = f.ProfileId,
                        likes = dtoLikes,
                        profilePhotoPath = modelProfile.PhotoPath
                    });
                }
            }

            return dtoFeed;
        }

        public IEnumerable<DtoFeed> GetComments(int feedId)
        {
            var dtoComments = new List<DtoFeed>();

            // Get comments for this feed
            var comments = feedRepo.WhereAsync(f => f.ParentId == feedId).Result;
            foreach (var c in comments)
            {
                var dtoLikes = new List<DtoLike>();
                var likes = likeRepo.WhereAsync(l => l.FeedId == c.Id).Result;
                if (likes.Any())
                {
                    foreach (var l in likes)
                    {
                        var profile = profileRepo.FirstOrDefaultAsync(p => p.Id == l.ProfileId).Result;
                        var dtoLike = new DtoLike()
                        {
                            id = l.Id,
                            feedId = l.FeedId,
                            profileId = l.ProfileId,
                            profileName = profile.Name
                        };
                        dtoLikes.Add(dtoLike);
                    }
                }
                ModelProfile modelProfile = profileRepo.FirstOrDefaultAsync(p => p.Id == c.ProfileId).Result;
                if (modelProfile != null)
                {
                    // Recursively get nested comments
                    var nestedComments = GetComments(c.Id).ToList();
                    
                    dtoComments.Add(new DtoFeed()
                    {
                        name = modelProfile.Name,
                        text = c.Text,
                        date = c.DateAdd.ToString(),
                        id = c.Id,
                        parentId = c.ParentId,
                        profileId = c.ProfileId,
                        likes = dtoLikes,
                        profilePhotoPath = modelProfile.PhotoPath,
                        comments = nestedComments
                    });
                }
            }

            return dtoComments;
        }

        public int AddFeed(DtoFeed dtoFeed, int? userId = null)
        {
            ModelFeed modelFeed;
            int modelProfileId = 0;
            
            if (userId.HasValue && userId.Value > 0)
            {
                // Use provided userId
                modelProfileId = userId.Value;
            }
            else
            {
                // Fallback to name/token lookup
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

        public int Like(DtoLike like, int? userId = null)
        {
            int profileId = 0;
            
            if (userId.HasValue && userId.Value > 0)
            {
                // Use provided userId
                profileId = userId.Value;
            }
            else
            {
                // Fallback to name/token lookup
                var profile = profileRepo.FirstOrDefaultAsync(profile => profile.Name == like.profileName && profile.Token == like.token).Result;
                if (profile != null)
                {
                    profileId = profile.Id;
                } 
                else
                {
                    throw new Exception("Profile not found");
                }
            }
            
            // Check if user already liked this feed
            var existingLike = likeRepo.FirstOrDefaultAsync(l => l.FeedId == like.feedId && l.ProfileId == profileId).Result;
            if (existingLike != null)
            {
                // User already liked this feed, return existing like id
                return existingLike.Id;
            }
            
            var modelLike = new ModelLike()
            {
                FeedId = like.feedId,
                ProfileId = profileId
            };
            return likeRepo.AddAsync(modelLike).Result.Id;
        }

        public DtoLike Dislike(int likeId)
        {
            var like = new DtoLike();
            var model = likeRepo.FirstOrDefaultAsync(l => l.Id == likeId).Result;
            like.feedId = model.FeedId;
            var profile = profileRepo.FirstOrDefaultAsync(p => p.Id == model.ProfileId).Result;
            like.profileName = profile.Name;
            likeRepo.DeleteAsync(model).Wait();
            return like;
        }
    }
}

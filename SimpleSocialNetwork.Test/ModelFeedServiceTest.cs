using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SimpleSocialNetwork.Data.Repositories;
using SimpleSocialNetwork.Dto;
using SimpleSocialNetwork.Models;
using SimpleSocialNetwork.Service.ModelFeedService;
using SimpleSocialNetwork.Test.Stub;

namespace SimpleSocialNetwork.Test
{
    [TestClass]
    public class ModelFeedServiceTest
    {

        [TestMethod]
        public void AddChildFeedTest()
        {
            var feedRepo = new ModelFeedRepositoryStub();
            var profileRepo = new ModelProfileRepositoryStub();
            var modelFeedService = new ModelFeedService(feedRepo, null, profileRepo);
            var username = "username";
            var token = "token";
            profileRepo.Add(new ModelProfile() {Name = username, Token = token});
            var feedParent = new DtoFeed(){name = username, token = token};
            feedParent.id = modelFeedService.AddFeed(feedParent);
            var feedChild = new DtoFeed { parentId = feedParent.id, name = username, token = token};
            feedChild.id = modelFeedService.AddFeed(feedChild);
            var modelChild = feedRepo.FirstOrDefault(f => f.Id == feedChild.id);
            Assert.IsTrue(modelChild.ParentId == feedChild.parentId);
        }
    }
}
using SimpleSocialNetwork.Dto;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Service.ModelFeedService
{
    public interface IModelFeedService
    {
        IEnumerable<DtoFeed> GetFeed();

        IEnumerable<DtoFeed> GetAllFeeds();

        IEnumerable<DtoFeed> GetComments(int feedId);

        int AddFeed(DtoFeed dtoFeed, int? userId = null);

        void DeleteFeed(int feedId);

        int Like(DtoLike like, int? userId = null);

        DtoLike Dislike(int likeId);
    }
}

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

        Task<(IEnumerable<DtoFeed> feeds, int totalCount)> GetFeedPaginatedAsync(int page, int pageSize);

        IEnumerable<DtoFeed> GetAllFeeds();

        IEnumerable<DtoFeed> GetComments(int feedId);

        Task<(IEnumerable<DtoFeed> comments, int totalCount)> GetCommentsPaginatedAsync(int feedId, int page, int pageSize);

        int AddFeed(DtoFeed dtoFeed, int? userId = null);

        void DeleteFeed(int feedId);

        int Like(DtoLike like, int? userId = null);

        DtoLike Dislike(int likeId);
    }
}

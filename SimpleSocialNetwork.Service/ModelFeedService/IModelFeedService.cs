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

        int AddFeed(DtoFeed dtoFeed);

        void DeleteFeed(int feedId);

        int Like(DtoLike like);

        DtoLike Dislike(int likeId);
    }
}

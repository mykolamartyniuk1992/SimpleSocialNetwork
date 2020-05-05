using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Microsoft.AspNet.SignalR;
using Microsoft.AspNet.SignalR.Hubs;

namespace SimpleSocialNetwork
{
    [HubName("feedHub")]
    public class FeedHub : Hub
    {
        //public void newFeed(DtoFeed feed)
        //{
        //    //Clients.All.newFeed(feed);
        //}

        //public void newLike(DtoLike like)
        //{
        //    //Clients.All.newLike(like);
        //}
        //public void newFeed(DtoFeed dtoFeed)
        //{
        //    Clients.Others.newFeed(dtoFeed);
        //}
    }
}
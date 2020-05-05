using Microsoft.AspNet.SignalR;
using Microsoft.AspNet.SignalR.Hubs;

namespace SimpleSocialNetwork.Hubs
{
    [HubName("feedHub")]
    public class FeedHub : Hub
    {
    }
}
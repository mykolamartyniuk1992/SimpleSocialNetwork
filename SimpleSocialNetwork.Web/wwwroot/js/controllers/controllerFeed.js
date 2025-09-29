app.controller('controllerFeed', ['$scope', '$cookies', '$http', function ($scope, $cookies, $http) {
    var $jq;
    try { $jq = jQuery.noConflict(); } catch (e) { console.error(e); }

    // SignalR 2.x (как у тебя сейчас)
    $jq(function () {
        var hub = $jq.connection.feedHub;
        let ulMessages = document.getElementById("ulMessages");
        hub.client.newFeed = function (item) {
            if (item.parentId === null) {
                new Feed(ulMessages, item.name, item.text, item.id, item.parentId, item.likes);
            } else {
                let message = messages.find(function (e) {
                    return e.id === item.parentId;
                });
                if (message) {
                    message.appendChildAnswer(item.name, item.text, item.id, item.parentId, item.likes);
                }
            }
        };

        hub.client.deleteFeed = function (item) {
            let message = messages.find(function (e) {
                return e.id === item.id;
            });
            if (message) {
                message.ul.removeChild(message.li);
            }
        };

        hub.client.like = function (like) {
            let message = messages.find(function (e) {
                return e.id === like.feedId;
            });
            if (message) {
                message.addLike(like);
            }
        };

        hub.client.unlike = function (like) {
            let message = messages.find(function (e) {
                return e.id === like.feedId;
            });
            if (message) {
                message.removeLike(like);
            }
        };
    });

    var messages = [];

    // ⚠️ Без name/token — сервер возьмёт их из HttpOnly куки
    $http.post('/api/feed/getfeed')
        .then(function (response) {
            let ul = document.getElementById("ulMessages");
            response.data.forEach(function (item) {
                if (item.parentId === null) {
                    new Feed(ul, item.name, item.text, item.id, item.parentId, item.likes);
                } else {
                    let msg = messages.find(function (e) { return e.id === item.parentId; });
                    if (msg) msg.appendChildAnswer(item.name, item.text, item.id, item.parentId, item.likes);
                }
            });
        }, function (error) {
            console.log('feed error', error);
        });

    $scope.sendMessage = function () {
        const txt = document.getElementById('txtMessage').value;
        $http.post('/api/feed/addfeed', { text: txt });     // ← только текст
    };

    class Feed {
        constructor(ul, author, text, id, parentId, likes) {
            this.id = id;
            this.parentId = parentId;
            this.likes = likes || [];
            this.author = author;
            this.text = text;
            this.date = new Date();
            this.ul = ul;

            // ... отрисовка как у тебя ...

            // Кнопка лайка: без token/profileName из JS
            this.btn_likes.onclick = function () {
                if (!this.liked) {
                    $http.post('/api/feed/like', { feedId: this.id })  // ← только feedId
                        .then(function () { /* опционально */ }.bind(this));
                } else {
                    // ищем свой лайк по имени из публичной куки 'name' (она не HttpOnly)
                    const myLike = this.likes.find(e => e.profileName === $cookies.get('name'));
                    if (myLike) {
                        $http.post('/api/feed/dislike', { id: myLike.id }) // ← только id лайка
                            .then(function () { this.liked = false; }.bind(this));
                    }
                }
            }.bind(this);
        }

        // ... остальные методы как были ...

        sendAnswer() {
            const txt = this.li.querySelector(".message__answer__text").value;
            $http.post('/api/feed/addfeed', { text: txt, parentId: this.id }) // ← без name/token
                .then(() => this.hideAnswer());
        }

        skipMessage() {
            $http.post('/api/feed/deletefeed', { id: this.id });             // ← только id
        }
    }
}]);

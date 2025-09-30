app.controller('controllerFeed', ['$scope', '$cookies', '$http', function ($scope, $cookies, $http) {

    // Создаём подключение к хабу
    const connection = new signalR.HubConnectionBuilder()
        .withUrl("/hubs/feed")           // тот же путь, что в MapHub
        .withAutomaticReconnect()
        .build();

    // Обработчики входящих событий
    connection.on("NewFeed", function (item) {
        $scope.$evalAsync(() => {
            let ulMessages = document.getElementById("ulMessages");
            if (item.parentId == null) {
                new Feed(ulMessages, item.name, item.text, item.id, item.parentId, item.likes);
            } else {
                let message = messages.find(e => e.id === item.parentId);
                if (message) message.appendChildAnswer(item.name, item.text, item.id, item.parentId, item.likes);
            }
        });
    });

    connection.on("DeleteFeed", function (item) {
        $scope.$evalAsync(() => {
            let message = messages.find(e => e.id === item.id);
            if (message) message.ul.removeChild(message.li);
        });
    });

    connection.on("Like", function (like) {
        $scope.$evalAsync(() => {
            let message = messages.find(e => e.id === like.feedId);
            if (message) message.addLike(like);
        });
    });

    connection.on("Unlike", function (like) {
        $scope.$evalAsync(() => {
            let message = messages.find(e => e.id === like.feedId);
            if (message) message.removeLike(like);
        });
    });

    // Старт подключения
    connection.start().catch(err => console.error("SignalR start error:", err));

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
            if (likes) this.likes = likes;
            else this.likes = [];
            this.author = author;
            this.text = text;
            this.date = new Date();
            this.ul = ul;
            this.li = document.createElement("li");
            this.li.classList.add("list-group-item");
            let div_message_date = document.createElement("kbd");
            div_message_date.classList.add("message__date");
            div_message_date.innerText = moment(this.date).format("DD.MM.YYYY HH\:mm");
            let div_message_author = document.createElement("div");
            div_message_author.classList.add("message__author");
            div_message_author.innerText = "Author: " + this.author;
            if (this.author === $cookies.get('name')) {
                div_message_author.innerText += ' (You)';
                div_message_author.style.fontWeight = 'bold';
            }
            let div_message_text = document.createElement("div");
            div_message_text.classList.add("message__text");
            div_message_text.classList.add("well");
            div_message_text.innerText = this.text;
            let div_message_controls = document.createElement("div");
            div_message_controls.classList.add("message__controls");

            var $jq = jQuery.noConflict();

            let btn_skipMessage = document.createElement("button");
            btn_skipMessage.type = "button";
            btn_skipMessage.classList.add("_skipMessage");
            btn_skipMessage.classList.add("btn");
            btn_skipMessage.innerText = "Skip";
            this.bindAnswerSkip = this.skipMessage.bind(this, this);
            btn_skipMessage.onclick = this.bindAnswerSkip;
            let btn_answerMessage = document.createElement("button");
            btn_answerMessage.type = "button";
            btn_answerMessage.classList.add("_answerMessage");
            btn_answerMessage.classList.add("btn");
            btn_answerMessage.innerText = "Answer";
            this.bindAnswerShow = this.answerMessage.bind(this);
            btn_answerMessage.onclick = this.bindAnswerShow;
            this.btn_likes = document.createElement("button");
            this.btn_likes.classList.add("btn");
            this.btn_likes.dataset.toggle = "tooltip";
            this.btn_likes.dataset.placement = "top";
            this.btn_likes.innerText = "Likes: " + this.likes.length;
            this.liked = false;

            // check if was liked
            let like = this.likes.find(function (e) {
                return e.profileName === $cookies.get('name');
            });
            if (like) {
                this.btn_likes.classList.add("btn-info");
                this.btn_likes.classList.add("active");
                this.liked = true;
            }

            this.getTitle = function () {
                let title = '';
                for (let i = 0; i < this.likes.length; i++) {
                    title += this.likes[i].profileName + '\n';
                }
                return title;
            }

            this.btn_likes.title = this.getTitle();
            $jq(this.btn_likes).tooltip();

            this.btn_likes.onclick = function (e) {
                let feedId = this.id;
                if (!this.liked) {
                    $http({
                        method: 'POST',
                        url: '/api/feed/like',
                        data: {
                            feedId: feedId
                        }
                    }).then(function (response) {
                        //this.addLike(response.data);
                    }.bind(this));
                }
                else {
                    let like = this.likes.find(function (e) {
                        return e.profileName === $cookies.get('name');
                    });
                    $http({
                        method: 'POST',
                        url: '/api/feed/dislike',
                        data: like
                    }).then(function (response) {
                        this.liked = false;
                    }.bind(this));
                }

            }.bind(this);
            this.btn_likes.value = "Likes: " + this.likes.length;
            if (author === $cookies.get('name')) div_message_controls.appendChild(btn_skipMessage);
            div_message_controls.appendChild(btn_answerMessage);
            div_message_controls.appendChild(this.btn_likes);
            this.li.appendChild(div_message_date);
            this.li.appendChild(div_message_author);
            this.li.appendChild(div_message_text);
            this.li.appendChild(div_message_controls);
            this.ul.appendChild(this.li);
            messages.push(this);

        }

        addLike(like) {
            this.likes.push(like);
            this.btn_likes.innerText = "Likes: " + this.likes.length;
            if (like.profileName === $cookies.get('name')) {
                this.btn_likes.classList.add("btn-info");
                this.btn_likes.classList.add("active");
                this.liked = true;
            }
            this.btn_likes.title = this.getTitle();
        }

        removeLike(like) {
            let index = this.likes.findIndex(function (e) {
                return e.id === like.id;
            });
            if (index > -1) {

                this.likes.splice(index, 1);
                this.btn_likes.innerText = "Likes: " + this.likes.length;
                if (like.profileName === $cookies.get('name')) {
                    this.btn_likes.classList.remove("btn-info");
                    this.btn_likes.classList.remove("active");
                    this.liked = false;
                }

                this.btn_likes.title = this.getTitle();
            }
        }

        answerMessage() {
            let div_wrapper = document.createElement("div");
            div_wrapper.classList.add("message__answer");
            let txtMessage = document.createElement("textarea");
            txtMessage.classList.add("form-control");

            txtMessage.classList.add("message__answer__text");
            let btnAddMessage = document.createElement("button");
            btnAddMessage.type = "button";
            btnAddMessage.innerText = "Add message";
            btnAddMessage.classList.add("btn")
            div_wrapper.appendChild(txtMessage);
            div_wrapper.appendChild(document.createElement("br"));
            div_wrapper.appendChild(btnAddMessage);
            this.li.appendChild(div_wrapper);
            let btn_answerMessage = this.li.querySelector("._answerMessage");
            this.bindAnswerHide = this.hideAnswer.bind(this);
            btn_answerMessage.onclick = this.bindAnswerHide;
            this.bindAddMessage = this.sendAnswer.bind(this);
            btnAddMessage.onclick = this.bindAddMessage;
        }

        sendAnswer() {
            let txtMessage = this.li.querySelector(".message__answer__text");
            let id = this.id;
            $http({
                method: 'POST',
                url: '/api/feed/AddFeed',
                data: {
                    text: txtMessage.value,
                    parentId: id
                }
            }).then(function (response) {

                //let id = +response.data;

                //let ul = document.createElement("ul");
                //this.li.appendChild(ul);
                //let answer = new Feed(ul, $cookies.get('name'), txtMessage.value, id, this.id, []);
                this.hideAnswer();
            }.bind(this));
        }

        appendChildAnswer(author, text, id) {
            let ul = document.createElement("ul");
            this.li.appendChild(ul);
            let answer = new Feed(ul, author, text, id, this.id, []);
        }

        hideAnswer() {
            let div_wrapper = this.li.querySelector(".message__answer");
            this.li.removeChild(div_wrapper);
            let btn_answerMessage = this.li.querySelector("._answerMessage");
            btn_answerMessage.onclick = this.bindAnswerShow;
        }

        skipMessage() {
            let id = this.id;
            $http({
                method: 'POST',
                url: '/api/feed/DeleteFeed',
                data: {
                    id: id
                }
            });
            //.then(function (response) {
            //    //this.ul.removeChild(this.li);
            //}.bind(this));


        }
    }
}]);

app.controller('controllerLogin', ['$scope', '$cookies', '$http', function ($scope, $cookies, $http) {
    debugger;
    $scope.login = function () {
        let pass = SHA256($scope.profilePassword);
        let profile = { name: $scope.profileName, password: pass };
        $http({
            method: 'POST',
            url: '/api/login/login',
            data: profile
        }).then(function successCallback(response) {
            if (response.data.name && response.data.token) {
                $cookies.put('name', response.data.name);
                $cookies.put('token', response.data.token);
                location = 'Feed.html';
            }
        }, function errorCallback(response) {
            debugger;
            console.log(response);
            alert(response.data);
        });
    }
}]);
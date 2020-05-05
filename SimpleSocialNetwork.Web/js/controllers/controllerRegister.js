app.controller('controllerRegister', ['$scope', '$cookies', '$http', function ($scope, $cookies, $http) {
    $scope.register = function () {

        let newProfile = { name: $scope.profileName, password: SHA256($scope.profilePassword) };
        $http({
            method: 'POST',
            url: 'http://localhost:58366/api/register/register',
            data: newProfile
        }).then(function successCallback(response) {
            alert('Now you can enter your credentials on login page');
            location = 'Login.html';
        });
    }
}]);
app.controller('controllerHeader', ['$scope', '$cookies', '$http', function ($scope, $cookies, $http) {

    $scope.btnRegisterVisible = function () {
        return strEndsWith(location.toString(), 'Login.html');
    }
    $scope.btnLoginVisible = function () {
        return strEndsWith(location.toString(), 'Register.html');
    }
    $scope.btnLogoutVisible = function () {
        return !strEndsWith(location.toString(), 'Login.html') && !strEndsWith(location.toString(), 'Register.html');
    }

    $scope.spanCurrentUserVisible = function () {
        return !strEndsWith(location.toString(), 'Login.html') && !strEndsWith(location.toString(), 'Register.html');
    }

    $scope.getCurrentUser = function () {
        return $cookies.get('name');
    }

    $scope.btnLogoutClick = function () {
        var cookies = $cookies.getAll();
        angular.forEach(cookies, function (v, k) {
            $cookies.remove(k);
        });
        location = 'Login.html';
    }

    $scope.btnRegisterClick = function () {
        location = 'Register.html';
    }

    $scope.btnLoginClick = function () {
        location = 'Login.html'
    }
}]);
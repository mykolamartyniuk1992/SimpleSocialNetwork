var app = angular.module('appSimpleSocialNetworkApp', ['ngCookies']);
app.run(['$rootScope', '$http', '$cookies', function ($rootScope, $http, $cookies) {

    // cheching if user has logged in alredy and have token in cookies
    //$http({
    //    method: 'POST',
    //    url: '/api/login/isAuthenticated',
    //    data: {
    //        name: $cookies.get('name'),
    //        token: $cookies.get('token')
    //    }
    //}).then(function successCallback(response) {
    //    if (response.data === true) {
    //        if (!strEndsWith(location.toString(), 'Feed.html')) location = 'Feed.html';
    //    } else {
    //        if (!strEndsWith(location.toString(), 'Login.html') && !strEndsWith(location.toString(), 'Register.html')) location = 'Login.html'; 
    //    }
    //});
}]);
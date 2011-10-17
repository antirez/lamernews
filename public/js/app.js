function login() {
    var data = {
        username: $("input[name=username]").val(),
        password: $("input[name=password]").val(),
    };
    $.ajax({
        type: "GET",
        url: ($("input[name=register]").attr("checked")) ?
            "/api/create_account" : "/api/login",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                document.cookie =
                    'auth='+r.auth+
                    '; expires=Thu, 1 Aug 2030 20:00:00 UTC; path=/';
                window.location.href = "/";
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}

function submit() {
    var data = {
        title: $("input[name=title]").val(),
        url: $("input[name=url]").val(),
        text: $("textarea[name=text]").val(),
        apisecret: $("input[name=apisecret]").val()
    };
    $.ajax({
        type: "POST",
        url: "/api/submit",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                window.location.href = "/news/"+r.news_id;
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}

// Install the onclick event in all news arrows the user did not voted already.
$(document).ready(function() {
    $('news').each(function(i,news) {
        var news_id = news.id;
        var up_class = news.children[0].getAttribute("class");
        if (!up_class) {
            news.onclick=function() {alert("x");}
        }
        var down_class = news.children[3].getAttribute("class");
        if (!down_class) {
            news.onclick=function() {alert("y");}
        }
    });
});

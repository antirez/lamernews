function login() {
    var data = {
        username: $("input[name=username]").val(),
        password: $("input[name=password]").val(),
    };
    var register = $("input[name=register]").attr("checked");
    $.ajax({
        type: register ? "POST" : "GET",
        url: register ? "/api/create_account" : "/api/login",
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
        news_id: $("input[name=news_id]").val(),
        title: $("input[name=title]").val(),
        url: $("input[name=url]").val(),
        text: $("textarea[name=text]").val(),
        apisecret: apisecret
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

function update_profile() {
    var data = {
        email: $("input[name=email]").val(),
        about: $("textarea[name=about]").val(),
        apisecret: apisecret
    };
    $.ajax({
        type: "POST",
        url: "/api/updateprofile",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                window.location.reload();
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}

function post_comment() {
    var data = {
        news_id: $("input[name=news_id]").val(),
        comment_id: $("input[name=comment_id]").val(),
        parent_id: $("input[name=parent_id]").val(),
        comment: $("textarea[name=comment]").val(),
        apisecret: apisecret
    };
    $.ajax({
        type: "POST",
        url: "/api/postcomment",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                if (r.op == "insert") {
                    window.location.href = "/news/"+r.news_id+"?r="+Math.random()+"#"+
                        r.news_id+"-"+r.comment_id;
                } else if (r.op == "update") {
                    window.location.href = "/editcomment/"+r.news_id+"/"+
                                           r.comment_id;
                } else if (r.op == "delete") {
                    window.location.href = "/news/"+r.news_id;
                }
            } else {
                $("#errormsg").html(r.error)
            }
        }
    });
    return false;
}

// Install the onclick event in all news arrows the user did not voted already.
$(function() {
    $('news').each(function(i,news) {
        var news_id = news.id;
        var up_class = news.children[0].getAttribute("class");
        if (!up_class) {
            news.children[0].onclick=function() {
                var data = {
                    news_id: news_id,
                    vote_type: "up",
                    apisecret: apisecret
                };
                $.ajax({
                    type: "POST",
                    url: "/api/votenews",
                    data: data,
                    success: function(reply) {
                        var r = jQuery.parseJSON(reply);
                        if (r.status == "ok") {
                            n = $("#"+news_id)[0];
                            n.children[0].setAttribute("class","voted");
                            n.children[3].setAttribute("class","disabled");
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            }
        }
        var down_class = news.children[3].getAttribute("class");
        if (!down_class) {
            news.children[3].onclick=function() {
                var data = {
                    news_id : news_id,
                    vote_type: "down",
                    apisecret: apisecret
                };
                $.ajax({
                    type: "POST",
                    url: "/api/votenews",
                    data: data,
                    success: function(reply) {
                        var r = jQuery.parseJSON(reply);
                        if (r.status == "ok") {
                            n = $("#"+news_id)[0];
                            n.children[0].setAttribute("class","disabled");
                            n.children[3].setAttribute("class","voted");
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            }
        }
    });
});

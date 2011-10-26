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
    var del = $("input[name=del]").length && $("input[name=del]").attr("checked");
    $.ajax({
        type: "POST",
        url: del ? "/api/delnews" : "/api/submit",
        data: data,
        success: function(reply) {
            var r = jQuery.parseJSON(reply);
            if (r.status == "ok") {
                if (r.news_id == -1) {
                    window.location.href = "/";
                } else {
                    window.location.href = "/news/"+r.news_id;
                }
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
        password: $("input[name=password]").val(),
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
    $('#newslist article').each(function(i,news) {
        var news_id = $(news).data("newsId");
        var up_class = news.children[0].getAttribute("class");
        if (!up_class) {
            $(news.children[0]).click(function(e) {
                e.preventDefault();
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
                            n = $("article[data-news-id="+news_id+"]")[0];
                            n.children[0].setAttribute("class","uparrow voted");
                            n.children[3].setAttribute("class","disabled");
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            });
        }
        var down_class = news.children[3].getAttribute("class");
        if (!down_class) {
            $(news.children[3]).click(function(e) {
                e.preventDefault();
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
                            n = $("article[data-news-id="+news_id+"]")[0];
                            n.children[0].setAttribute("class","disabled");
                            n.children[3].setAttribute("class","downarrow voted");
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            });
        }
    });
});

// Install the onclick event in all comments arrows the user did not
// voted already.
$(function() {
    $('#comments article.comment').each(function(i,comment) {
        var comment_id = $(comment).data("commentId");
        comment = $(comment);
        up = comment.find(".uparrow");
        down = comment.find(".downarrow");
        var voted = up.hasClass("voted") || down.hasClass("voted");
        if (!voted) {
            up.click(function(e) {
                e.preventDefault();
                var data = {
                    comment_id: comment_id,
                    vote_type: "up",
                    apisecret: apisecret
                };
                $.ajax({
                    type: "POST",
                    url: "/api/votecomment",
                    data: data,
                    success: function(reply) {
                        var r = jQuery.parseJSON(reply);
                        if (r.status == "ok") {
                            $('article[data-comment-id="'+r.comment_id+'"]').find(".uparrow").addClass("voted")
                            $('article[data-comment-id="'+r.comment_id+'"]').find(".downarrow").addClass("disabled")
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            });
            down.click(function(e) {
                e.preventDefault();
                var data = {
                    comment_id: comment_id,
                    vote_type: "down",
                    apisecret: apisecret
                };
                $.ajax({
                    type: "POST",
                    url: "/api/votecomment",
                    data: data,
                    success: function(reply) {
                        var r = jQuery.parseJSON(reply);
                        if (r.status == "ok") {
                            $('article[data-comment-id="'+r.comment_id+'"]').find(".uparrow").addClass("disabled")
                            $('article[data-comment-id="'+r.comment_id+'"]').find(".downarrow").addClass("voted")
                        } else {
                            alert("Vote not registered: "+r.error);
                        }
                    }
                });
            });
        }
    });
});

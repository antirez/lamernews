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
        success: function(r) {
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

function reset_password() {
    var data = {
        username: $("input[name=username]").val(),
        email: $("input[name=email]").val(),
    };
    $.ajax({
        type: "GET",
        url: "/api/reset-password",
        data: data,
        success: function(r) {
            if (r.status == "ok") {
                window.location.href = "/reset-password-ok";
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
        success: function(r) {
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
        success: function(r) {
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
        success: function(r) {
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

function setKeyboardNavigation() {
    $(function() {
        $(document).keypress(function(e) {
            if ($(':focus').length > 0) return;
            if (e.which == 63) { // for some reason in keyup the '?' is returning 0, along with other keys
                $('#keyboard-help').show();
            }
        });
        $(document).keyup(function(e) {
            if ($(':focus').length > 0) return;
            var active = $('article.active');
            if (e.which == 74 || e.which == 75) {
                var newActive;
                if (active.length == 0) {
                    if (e.which == 74) {
                        newActive = $('article').first();
                    } else {
                        newActive = $('article').last();
                    }
                } else if (e.which == 74){
                    newActive = $($('article').get($('article').index(active)+1));
                } else if (e.which == 75){
                    var index = $('article').index(active);
                    if (index == 0) return;
                    newActive = $($('article').get(index-1));
                }
                if (newActive.length == 0) return;
                active.removeClass('active');
                newActive.addClass('active');
                if ($(window).scrollTop() > newActive.offset().top)
                    $('html, body').animate({ scrollTop: newActive.offset().top - 10 }, 100);
                if ($(window).scrollTop() + $(window).height() < newActive.offset().top)
                    $('html, body').animate({ scrollTop: newActive.offset().top - $(window).height() + newActive.height() + 10 }, 100);
            }
            if (e.which == 13 && active.length > 0) {
                if (active.find('h2 a').length == 0) return;
                location.href = active.find('h2 a').attr('href');
            }
            if (e.which == 65 && active.length > 0) {
                active.find('.uparrow').click();
            }
            if (e.which == 90 && active.length > 0) {
                active.find('.downarrow').click();
            }
            if (e.which == 27) {
                $('#keyboard-help').hide();
            }
        });
        $('#newslist article').each(function(i,news) {
            $(news).click(function() {
                var active = $('article.active');
                active.removeClass('active');
                $(news).addClass('active');
            });
        });
    });
}

// Install the onclick event in all news arrows the user did not voted already.
$(function() {
    $('#newslist article').each(function(i,news) {
        var news_id = $(news).data("newsId");
        news = $(news);
        up = news.find(".uparrow");
        down = news.find(".downarrow");
        var voted = up.hasClass("voted") || down.hasClass("voted");
        if (!voted) {
            up.click(handle_news_vote('up',news_id));
            down.click(handle_news_vote('down',news_id));
        }
    });
});

function handle_news_vote(vote_type,news_id) {
    var uparrowClass = vote_type == 'up' ? 'voted' : 'disabled';
    var downarrowClass = vote_type == 'down' ? 'voted' : 'disabled';

    return function(e) {
        if (typeof(apisecret) == 'undefined') return; // Not logged in
        e.preventDefault();
        var data = {
            news_id: news_id,
            vote_type: vote_type,
            apisecret: apisecret
        };
        $.ajax({
            type: "POST",
            url: "/api/votenews",
            data: data,
            success: function(r) {
                if (r.status == "ok") {
                    var n = $("article[data-news-id="+news_id+"]");
                    n.find(".uparrow").addClass(uparrowClass);
                    n.find(".downarrow").addClass(downarrowClass);
                } else {
                    alert(r.error);
                }
            }
        });
    }
}

// Install the onclick event in all comments arrows the user did not
// voted already.
$(function() {
    $('#comments article.comment, .singlecomment article.comment').each(function(i,comment) {
        var comment_id = $(comment).data("commentId");
        comment = $(comment);
        up = comment.find(".uparrow");
        down = comment.find(".downarrow");
        var voted = up.hasClass("voted") || down.hasClass("voted");
        if (!voted) {
            up.click(handle_comment_vote('up',comment_id));
            down.click(handle_comment_vote('down',comment_id));
        }
    });
});

function handle_comment_vote(vote_type,comment_id) {
    var uparrowClass = vote_type == 'up' ? 'voted' : 'disabled';
    var downarrowClass = vote_type == 'down' ? 'voted' : 'disabled';

    return function(e) {
        if (typeof(apisecret) == 'undefined') return; // Not logged in
        e.preventDefault();
        var data = {
            comment_id: comment_id,
            vote_type: vote_type,
            apisecret: apisecret
        };
        $.ajax({
            type: "POST",
            url: "/api/votecomment",
            data: data,
            success: function(r) {
                if (r.status == "ok") {
                    var c = $('article[data-comment-id="'+r.comment_id+'"]');
                    c.find(".uparrow").addClass(uparrowClass);
                    c.find(".downarrow").addClass(downarrowClass);
                } else {
                    alert(r.error);
                }
            }
        });
    }
}

# Copyright 2011 Salvatore Sanfilippo. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY SALVATORE SANFILIPPO ''AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL SALVATORE SANFILIPPO OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Salvatore Sanfilippo.

require 'app_config'
require 'rubygems'
require 'hiredis'
require 'redis'
require 'page'
require 'sinatra'
require 'json'
require 'digest/sha1'
require 'digest/md5'
require 'comments'
require 'pbkdf2'
require 'openssl' if UseOpenSSL

Version = "0.5.0"

configure do
  set :redis_server, Redis.new(:host => RedisHost, :port => RedisPort)
end

before do
    H = HTMLGen.new if !defined?(H)
    if !defined?(Comments)
        Comments = RedisComments.new(settings.redis_server,"comment",proc{|c,level|
            c.sort {|a,b|
                ascore = compute_comment_score a
                bscore = compute_comment_score b
                if ascore == bscore
                    # If score is the same favor newer comments
                    b['ctime'].to_i <=> a['ctime'].to_i
                else
                    # If score is different order by score.
                    # FIXME: do something smarter favouring newest comments
                    # but only in the short time.
                    bscore <=> ascore
                end
            }
        })
    end
    $user = nil
    auth_user(request.cookies['auth'])
    increment_karma_if_needed if $user
end

get '/' do
    H.set_title "Top News - #{SiteName}"
    news = get_top_news
    H.page {
        H.h2 {"Top news"}+news_list_to_html(news)
    }
end

get '/rss' do
    content_type 'text/xml', :charset => 'utf-8'
    news = get_latest_news
    H.rss(:version => "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom") {
        H.channel {
            H.title {
                "Lamer News"
            } + " " +
            H.link {
                "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
            } + " " +
            H.description {
                "Description pending"
            } + " " +
            news_list_to_rss(news)
        }
    }
end

get '/latest' do
    H.set_title "Latest news - #{SiteName}"
    news = get_latest_news
    H.page {
        H.h2 {"Latest news"}+news_list_to_html(news)
    }
end

get '/saved/:start' do
    redirect "/login" if !$user
    start = params[:start].to_i
    start = 0 if start < 0
    H.set_title "Saved news - #{SiteName}"
    news,count = get_saved_news($user['id'],start)
    paginate = {
        :start => start,
        :count => count,
        :perpage => SavedNewsPerPage,
        :link => "/saved/$"
    }
    H.page {
        H.h2 {"Your saved news"}+news_list_to_html(news,paginate)
    }
end

get '/login' do
    H.set_title "Login - #{SiteName}"
    H.page {
        H.div(:id => "login") {
            H.form(:name=>"f") {
                H.label(:for => "username") {"username"}+
                H.inputtext(:id => "username", :name => "username")+
                H.label(:for => "password") {"password"}+
                H.inputpass(:id => "password", :name => "password")+H.br+
                H.checkbox(:name => "register", :value => "1")+
                "create account"+H.br+
                H.button(:name => "do_login", :value => "Login")
            }
        }+
        H.div(:id => "errormsg"){}+
        H.script() {'
            $(function() {
                $("input[name=do_login]").click(login);
            });
        '}
    }
end

get '/submit' do
    redirect "/login" if !$user
    H.set_title "Submit a new story - #{SiteName}"
    H.page {
        H.h2 {"Submit a new story"}+
        H.form(:id => "submitform") {
            H.form(:name=>"f") {
                H.inputhidden(:name => "news_id", :value => -1)+
                H.label(:for => "title") {"title"}+
                H.inputtext(:id => "title", :name => "title", :size => 80)+H.br+
                H.label(:for => "url") {"url"}+H.br+
                H.inputtext(:id => "url", :name => "url", :size => 60)+H.br+
                "or if you don't have an url type some text"+
                H.br+
                H.label(:for => "text") {"text"}+
                H.textarea(:id => "text", :name => "text", :cols => 60, :rows => 10) {}+
                H.button(:name => "do_submit", :value => "Submit")
            }
        }+
        H.div(:id => "errormsg"){}+
        H.script() {'
            $(function() {
                $("input[name=do_submit]").click(submit);
            });
        '}
    }
end

get '/logout' do
    if $user and check_api_secret
        update_auth_token($user["id"])
    end
    redirect "/"
end

get "/news/:news_id" do
    news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !news
    # Show the news text if it is a news without URL.
    if !news_domain(news)
        c = {
            "body" => news_text(news),
            "ctime" => news["ctime"],
            "user_id" => news["user_id"],
            "topcomment" => true
        }
        user = get_user_by_id(news["user_id"]) or DeletedUser
        top_comment = H.topcomment {comment_to_html(c,user,news['id'])}
    else
        top_comment = ""
    end
    H.set_title "#{H.entities news["title"]} - #{SiteName}"
    H.page {
        H.section(:id => "newslist") {
            news_to_html(news)
        }+top_comment+
        if $user
            H.form(:name=>"f") {
                H.inputhidden(:name => "news_id", :value => news["id"])+
                H.inputhidden(:name => "comment_id", :value => -1)+
                H.inputhidden(:name => "parent_id", :value => -1)+
                H.textarea(:name => "comment", :cols => 60, :rows => 10) {}+H.br+
                H.button(:name => "post_comment", :value => "Send comment")
            }+H.div(:id => "errormsg"){}
        else
            H.br
        end +
        render_comments_for_news(news["id"])+
        H.script() {'
            $(function() {
                $("input[name=post_comment]").click(post_comment);
            });
        '}
    }
end

get "/comment/:news_id/:comment_id" do
    news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !news
    comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !comment
    H.page {
        H.section(:id => "newslist") {
            news_to_html(news)
        }+H.div(:class => "singlecomment") {
            u = get_user_by_id(comment["user_id"]) or DeletedUser
            comment_to_html(comment,u,news["news_id"])
        }+H.div(:class => "commentreplies") {
            H.h2 {"Replies"}
        }+
        render_comments_for_news(news["id"],params["comment_id"].to_i)
    }
end

get "/reply/:news_id/:comment_id" do
    redirect "/login" if !$user
    news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !news
    comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !comment
    user = get_user_by_id(comment["user_id"]) or DeletedUser
    comment["id"] = params["comment_id"]

    H.set_title "Reply to comment - #{SiteName}"
    H.page {
        news_to_html(news)+
        comment_to_html(comment,user,params["news_id"])+
        H.form(:name=>"f") {
            H.inputhidden(:name => "news_id", :value => news["id"])+
            H.inputhidden(:name => "comment_id", :value => -1)+
            H.inputhidden(:name => "parent_id", :value => params["comment_id"])+
            H.textarea(:name => "comment", :cols => 60, :rows => 10) {}+H.br+
            H.button(:name => "post_comment", :value => "Reply")
        }+H.div(:id => "errormsg"){}+
        H.script() {'
            $(function() {
                $("input[name=post_comment]").click(post_comment);
            });
        '}
    }
end

get "/editcomment/:news_id/:comment_id" do
    redirect "/login" if !$user
    news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !news
    comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !comment
    user = get_user_by_id(comment["user_id"]) or DeletedUser
    halt(500,"Permission denied.") if $user['id'].to_i != user['id'].to_i
    comment["id"] = params["comment_id"]

    H.set_title "Edit comment - #{SiteName}"
    H.page {
        news_to_html(news)+
        comment_to_html(comment,user,params["news_id"])+
        H.form(:name=>"f") {
            H.inputhidden(:name => "news_id", :value => news["id"])+
            H.inputhidden(:name => "comment_id",:value => params["comment_id"])+
            H.inputhidden(:name => "parent_id", :value => -1)+
            H.textarea(:name => "comment", :cols => 60, :rows => 10) {
                H.entities comment['body']
            }+H.br+
            H.button(:name => "post_comment", :value => "Edit")
        }+H.div(:id => "errormsg"){}+
        H.note {
            "Note: to remove the comment remove all the text and press Edit."
        }+
        H.script() {'
            $(function() {
                $("input[name=post_comment]").click(post_comment);
            });
        '}
    }
end

get "/editnews/:news_id" do
    redirect "/login" if !$user
    news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !news
    halt(500,"Permission denied.") if $user['id'].to_i != news['user_id'].to_i

    if news_domain(news)
        text = ""
    else
        text = news_text(news)
        news['url'] = ""
    end
    H.set_title "Edit news - #{SiteName}"
    H.page {
        news_to_html(news)+
        H.form(:id => "submitform") {
            H.form(:name=>"f") {
                H.inputhidden(:name => "news_id", :value => news['id'])+
                H.label(:for => "title") {"title"}+
                H.inputtext(:id => "title", :name => "title", :size => 80,
                            :value => H.entities(news['title']))+H.br+
                H.label(:for => "url") {"url"}+H.br+
                H.inputtext(:id => "url", :name => "url", :size => 60,
                            :value => H.entities(news['url']))+H.br+
                "or if you don't have an url type some text"+
                H.br+
                H.label(:for => "text") {"text"}+
                H.textarea(:id => "text", :name => "text", :cols => 60, :rows => 10) {
                    H.entities(text)
                }+H.br+
                H.checkbox(:name => "del", :value => "1")+
                "delete this news"+H.br+
                H.button(:name => "edit_news", :value => "Edit")
            }
        }+
        H.div(:id => "errormsg"){}+
        H.script() {'
            $(function() {
                $("input[name=edit_news]").click(submit);
            });
        '}
    }
end

get "/user/:username" do
    user = get_user_by_username(params[:username])
    halt(404,"Non existing user") if !user
    posted_news,posted_comments = settings.redis_server.pipelined {
        settings.redis_server.zcard("user.posted:#{user['id']}")
        settings.redis_server.zcard("user.comments:#{user['id']}")
    }
    H.set_title "#{H.entities user['username']} - #{SiteName}"
    owner = $user && ($user['id'].to_i == user['id'].to_i)
    H.page {
        H.div(:class => "userinfo") {
            H.span(:class => "avatar") {
                email = user["email"] || ""
                digest = Digest::MD5.hexdigest(email)
                H.img(:src=>"http://gravatar.com/avatar/#{digest}?s=48&d=mm")
            }+" "+
            H.h2 {H.entities user['username']}+
            H.pre {
                H.entities user['about']
            }+
            H.ul {
                H.li {
                    H.b {"created "}+
                    "#{(Time.now.to_i-user['ctime'].to_i)/(3600*24)} days ago"
                }+
                H.li {H.b {"karma "}+ "#{user['karma']} points"}+
                H.li {H.b {"posted news "}+posted_news.to_s}+
                H.li {H.b {"posted comments "}+posted_comments.to_s}+
                if owner
                    H.li {H.a(:href=>"/saved/0") {"saved news"}}
                else "" end
            }
        }+if owner
            H.br+H.form(:name=>"f") {
                H.label(:for => "email") {
                    "email (not visible, used for gravatar)"
                }+H.br+
                H.inputtext(:id => "email", :name => "email", :size => 40,
                            :value => H.entities(user['email']))+H.br+
                H.label(:for => "password") {
                    "change password (optional)"
                }+H.br+
                H.inputpass(:name => "password", :size => 40)+H.br+
                H.label(:for => "about") {"about"}+H.br+
                H.textarea(:id => "about", :name => "about", :cols => 60, :rows => 10){
                    H.entities(user['about'])
                }+H.br+
                H.button(:name => "update_profile", :value => "Update profile")
            }+
            H.div(:id => "errormsg"){}+
            H.script() {'
                $(function() {
                    $("input[name=update_profile]").click(update_profile);
                });
            '}
        else "" end
    }
end

###############################################################################
# API implementation
###############################################################################

post '/api/logout' do
    if $user and check_api_secret
        update_auth_token($user["id"])
        return {:status => "ok"}.to_json
    else
        return {
            :status => "err",
            :error => "Wrong auth credentials or API secret."
        }.to_json
    end
end

get '/api/login' do
    auth,apisecret = check_user_credentials(params[:username],
                                            params[:password])
    if auth 
        return {
            :status => "ok",
            :auth => auth,
            :apisecret => apisecret
        }.to_json
    else
        return {
            :status => "err",
            :error => "No match for the specified username / password pair."
        }.to_json
    end
end

post '/api/create_account' do
    if (!check_params "username","password")
        return {
            :status => "err",
            :error => "Username and password are two required fields."
        }.to_json
    end
    if params[:password].length < PasswordMinLength
        return {
            :status => "err",
            :error => "Password is too short. Min length: #{PasswordMinLength}"
        }.to_json
    end
    auth,errmsg = create_user(params[:username],params[:password])
    if auth 
        return {:status => "ok", :auth => auth}.to_json
    else
        return {
            :status => "err",
            :error => errmsg
        }.to_json
    end
end

post '/api/submit' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end

    # We can have an empty url or an empty first comment, but not both.
    if (!check_params "title","news_id",:url,:text) or
                               (params[:url].length == 0 and
                                params[:text].length == 0)
        return {
            :status => "err",
            :error => "Please specify a news title and address or text."
        }.to_json
    end
    # Make sure the URL is about an acceptable protocol, that is
    # http:// or https:// for now.
    if params[:url].length != 0
        if params[:url].index("http://") != 0 and
           params[:url].index("https://") != 0
            return {
                :status => "err",
                :error => "We only accept http:// and https:// news."
            }.to_json
        end
    end
    if params[:news_id].to_i == -1
        if submitted_recently
            return {
                :status => "err",
                :error => "You have submitted a story too recently, "+
                "please wait #{allowed_to_post_in_seconds} seconds."
            }.to_json
        end
        news_id = insert_news(params[:title],params[:url],params[:text],
                              $user["id"])
    else
        news_id = edit_news(params[:news_id],params[:title],params[:url],
                            params[:text],$user["id"])
        if !news_id
            return {
                :status => "err",
                :error => "Invalid parameters, news too old to be modified "+
                          "or url recently posted."
            }.to_json
        end
    end
    return  {
        :status => "ok",
        :news_id => news_id.to_i
    }.to_json
end

post '/api/delnews' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end
    if (!check_params "news_id")
        return {
            :status => "err",
            :error => "Please specify a news title."
        }.to_json
    end
    if del_news(params[:news_id],$user["id"])
        return {:status => "ok", :news_id => -1}.to_json
    end
    return {:status => "err", :error => "News too old or wrong ID/owner."}.to_json
end

post '/api/votenews' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end
    # Params sanity check
    if (!check_params "news_id","vote_type") or (params["vote_type"] != "up" and
                                                 params["vote_type"] != "down")
        return {
            :status => "err",
            :error => "Missing news ID or invalid vote type."
        }.to_json
    end
    # Vote the news
    vote_type = params["vote_type"].to_sym
    karma,error = vote_news(params["news_id"].to_i,$user["id"],vote_type)
    if karma
        return { :status => "ok" }.to_json
    else
        return { :status => "err", 
                 :error => error }.to_json
    end
end

post '/api/postcomment' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end
    # Params sanity check
    if (!check_params "news_id","comment_id","parent_id",:comment)
        return {
            :status => "err",
            :error => "Missing news_id, comment_id, parent_id, or comment
                       parameter."
        }.to_json
    end
    info = insert_comment(params["news_id"].to_i,$user['id'],
                          params["comment_id"].to_i,
                          params["parent_id"].to_i,params["comment"])
    return {
        :status => "err",
        :error => "Invalid news, comment, or edit time expired."
    }.to_json if !info
    return {
        :status => "ok",
        :op => info['op'],
        :comment_id => info['comment_id'],
        :parent_id => params['parent_id'],
        :news_id => params['news_id']
    }.to_json
end

post '/api/updateprofile' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if !check_params(:about, :email, :password)
        return {:status => "err", :error => "Missing parameters."}.to_json
    end
    if params[:password].length > 0
        if params[:password].length < PasswordMinLength
            return {
                :status => "err",
                :error => "Password is too short. "+
                          "Min length: #{PasswordMinLength}"
            }.to_json
        end
        settings.redis_server.hmset("user:#{$user['id']}","password",
            hash_password(params[:password],$user['salt']))
    end
    settings.redis_server.hmset("user:#{$user['id']}",
        "about", params[:about][0..4095],
        "email", params[:email][0..255])
    return {:status => "ok"}.to_json
end

post '/api/votecomment' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end
    # Params sanity check
    if (!check_params "comment_id","vote_type") or
                                            (params["vote_type"] != "up" and
                                             params["vote_type"] != "down")
        return {
            :status => "err",
            :error => "Missing news ID or invalid vote type."
        }.to_json
    end
    # Vote the news
    vote_type = params["vote_type"].to_sym
    news_id,comment_id = params["comment_id"].split("-")
    if vote_comment(news_id.to_i,comment_id.to_i,$user["id"],vote_type)
        return { :status => "ok", :comment_id => params["comment_id"] }.to_json
    else
        return { :status => "err", 
                 :error => "Invalid parameters or duplicated vote." }.to_json
    end
end

# Check that the list of parameters specified exist.
# If at least one is missing false is returned, otherwise true is returned.
#
# If a parameter is specified as as symbol only existence is tested.
# If it is specified as a string the parameter must also meet the condition
# of being a non empty string.
def check_params *required
    required.each{|p|
        if !params[p] or (p.is_a? String and params[p].length == 0)
            return false
        end
    }
    true
end

def check_params_or_halt *required
    return if check_parameters *required
    halt 500, H.h1{"500"}+H.p{"Missing parameters"}
end

def check_api_secret
    return false if !$user
    params["apisecret"] and (params["apisecret"] == $user["apisecret"])
end

def application_header
    navitems = [    ["top","/"],
                    ["latest","/latest"],
                    ["submit","/submit"]]
    navbar = H.nav {
        navitems.map{|ni|
            H.a(:href=>ni[1]) {H.entities ni[0]}
        }.inject{|a,b| a+"\n"+b}
    }
    rnavbar = H.nav(:id => "account") {
        if $user
            H.a(:href => "/user/"+H.urlencode($user['username'])) { 
                $user['username']+" (#{$user['karma']})"
            }+" | "+
            H.a(:href =>
                "/logout?apisecret=#{$user['apisecret']}") {
                "logout"
            }
        else
            H.a(:href => "/login") {"login / register"}
        end
    }
    H.header {
        H.h1 {
            H.a(:href => "/") {H.entities SiteName}+" "+
            H.small {Version}
        }+navbar+" "+rnavbar
    }
end

def application_footer
    if $user
        apisecret = H.script() {
            "var apisecret = '#{$user['apisecret']}';";
        }
    else
        apisecret = ""
    end
    H.footer {
        links = [
            ["source code", "http://github.com/antirez/lamernews"],
            ["rss feed", "/rss"],
            ["twitter", FooterTwitterLink],
            ["google group", FooterGoogleGroupLink]
        ]
        links.map{|l| l[1] ?
            H.a(:href => l[1]) {H.entities l[0]} :
            nil
        }.select{|l| l}.join(" | ")
    }+apisecret
end

################################################################################
# User and authentication
################################################################################

# Try to authenticate the user, if the credentials are ok we populate the
# $user global with the user information.
# Otherwise $user is set to nil, so you can test for authenticated user
# just with: if $user ...
#
# Return value: none, the function works by side effect.
def auth_user(auth)
    return if !auth
    id = settings.redis_server.get("auth:#{auth}")
    return if !id
    user = settings.redis_server.hgetall("user:#{id}")
    $user = user if user.length > 0
end

# In Lamer News users get karma visiting the site.
# Increment the user karma by KarmaIncrementAmount if the latest increment
# was performed more than KarmaIncrementInterval seconds ago.
#
# Return value: none.
#
# Notes: this function must be called only in the context of a logged in
#        user.
#
# Side effects: the user karma is incremented and the $user hash updated.
def increment_karma_if_needed
    if $user['karma_incr_time'].to_i < (Time.now.to_i-KarmaIncrementInterval)
        userkey = "user:#{$user['id']}"
        settings.redis_server.hset(userkey,"karma_incr_time",Time.now.to_i)
        increment_user_karma_by($user['id'],KarmaIncrementAmount)
    end
end

# Increment the user karma by the specified amount and make sure to
# update $user to reflect the change if it is the same user id.
def increment_user_karma_by(user_id,increment)
    userkey = "user:#{user_id}"
    settings.redis_server.hincrby(userkey,"karma",increment)
    if $user and ($user['id'].to_i == user_id.to_i)
        $user['karma'] = $user['karma'].to_i + increment
    end
end

# Return the specified user karma.
def get_user_karma(user_id)
    return $user['karma'].to_i if $user and (user_id.to_i == $user['id'].to_i)
    userkey = "user:#{user_id}"
    karma = settings.redis_server.hget(userkey,"karma")
    karma ? karma.to_i : 0
end

# Return the hex representation of an unguessable 160 bit random number.
def get_rand
    rand = "";
    File.open("/dev/urandom").read(20).each_byte{|x| rand << sprintf("%02x",x)}
    rand
end

# Create a new user with the specified username/password
#
# Return value: the function returns two values, the first is the
#               auth token if the registration succeeded, otherwise
#               is nil. The second is the error message if the function
#               failed (detected testing the first return value).
def create_user(username,password)
    if settings.redis_server.exists("username.to.id:#{username.downcase}")
        return nil, "Username is busy, please try a different one."
    end
    if rate_limit_by_ip(3600*15,"create_user",request.ip)
        return nil, "Please wait some time before creating a new user."
    end
    id = settings.redis_server.incr("users.count")
    auth_token = get_rand
    salt = get_rand
    settings.redis_server.hmset("user:#{id}",
        "id",id,
        "username",username,
        "salt",salt,
        "password",hash_password(password,salt),
        "ctime",Time.now.to_i,
        "karma",UserInitialKarma,
        "about","",
        "email","",
        "auth",auth_token,
        "apisecret",get_rand,
        "flags","",
        "karma_incr_time",Time.new.to_i)
    settings.redis_server.set("username.to.id:#{username.downcase}",id)
    settings.redis_server.set("auth:#{auth_token}",id)
    return auth_token,nil
end

# Update the specified user authentication token with a random generated
# one. This in other words means to logout all the sessions open for that
# user.
#
# Return value: on success the new token is returned. Otherwise nil.
# Side effect: the auth token is modified.
def update_auth_token(user_id)
    user = get_user_by_id(user_id)
    return nil if !user
    settings.redis_server.del("auth:#{user['auth']}")
    new_auth_token = get_rand
    settings.redis_server.hmset("user:#{user_id}","auth",new_auth_token)
    settings.redis_server.set("auth:#{new_auth_token}",user_id)
    return new_auth_token
end

# Turn the password into an hashed one, using PBKDF2 with HMAC-SHA1
# and 160 bit output.
def hash_password(password,salt)
    p = PBKDF2.new do |p|
        p.iterations = PBKDF2Iterations
        p.password = password
        p.salt = salt
        p.key_length = 160/8
    end
    p.hex_string
end

# Return the user from the ID.
def get_user_by_id(id)
    settings.redis_server.hgetall("user:#{id}")
end

# Return the user from the username.
def get_user_by_username(username)
    id = settings.redis_server.get("username.to.id:#{username.downcase}")
    return nil if !id
    get_user_by_id(id)
end

# Check if the username/password pair identifies an user.
# If so the auth token and form secret are returned, otherwise nil is returned.
def check_user_credentials(username,password)
    user = get_user_by_username(username)
    return nil if !user
    hp = hash_password(password,user['salt'])
    (user['password'] == hp) ? [user['auth'],user['apisecret']] : nil
end

# Has the user submitted a news story in the last `NewsSubmissionBreak` seconds?
def submitted_recently
  allowed_to_post_in_seconds > 0
end

# Indicates when the user is allowed to submit another story after the last.
def allowed_to_post_in_seconds
  settings.redis_server.ttl("user:#{$user['id']}:submitted_recently")
end

################################################################################
# News
################################################################################

# Fetch one or more (if an Array is passed) news from Redis by id.
# Note that we also load other informations about the news like
# the username of the poster and other informations needed to render
# the news into HTML.
#
# Doing this in a centralized way offers us the ability to exploit
# Redis pipelining.
def get_news_by_id(news_ids,opt={})
    result = []
    if !news_ids.is_a? Array
        opt[:single] = true
        news_ids = [news_ids]
    end
    news = settings.redis_server.pipelined {
        news_ids.each{|nid|
            settings.redis_server.hgetall("news:#{nid}")
        }
    }
    return [] if !news # Can happen only if news_ids is an empty array.

    # Remove empty elements
    news = news.select{|x| x.length > 0}
    if news.length == 0
        return opt[:single] ? nil : []
    end

    # Get all the news
    settings.redis_server.pipelined {
        news.each{|n|
            # Adjust rank if too different from the real-time value.
            hash = {}
            n.each_slice(2) {|k,v|
                hash[k] = v
            }
            update_news_rank_if_needed(hash) if opt[:update_rank]
            result << hash
        }
    }

    # Get the associated users information
    usernames = settings.redis_server.pipelined {
        result.each{|n|
            settings.redis_server.hget("user:#{n["user_id"]}","username")
        }
    }
    result.each_with_index{|n,i|
        n["username"] = usernames[i]
    }

    # Load $User vote information if we are in the context of a
    # registered user.
    if $user
        votes = settings.redis_server.pipelined {
            result.each{|n|
                settings.redis_server.zscore("news.up:#{n["id"]}",$user["id"])
                settings.redis_server.zscore("news.down:#{n["id"]}",$user["id"])
            }
        }
        result.each_with_index{|n,i|
            if votes[i*2]
                n["voted"] = :up
            elsif votes[(i*2)+1]
                n["voted"] = :down
            end
        }
    end

    # Return an array if we got an array as input, otherwise
    # the single element the caller requested.
    opt[:single] ? result[0] : result
end

# Vote the specified news in the context of a given user.
# type is either :up or :down
# 
# The function takes care of the following:
# 1) The vote is not duplicated.
# 2) That the karma is decreased from voting user, accordingly to vote type.
# 3) That the karma is transfered to the author of the post, if different.
# 4) That the news score is updaed.
#
# Return value: two return values are returned: rank,error
#
# If the fucntion is successful rank is not nil, and represents the news karma
# after the vote was registered. The error is set to nil.
#
# On error the returned karma is false, and error is a string describing the
# error that prevented the vote.
def vote_news(news_id,user_id,vote_type)
    # Fetch news and user
    user = ($user and $user["id"] == user_id) ? $user : get_user_by_id(user_id)
    news = get_news_by_id(news_id)
    return false,"No such news or user." if !news or !user

    # Now it's time to check if the user already voted that news, either
    # up or down. If so return now.
    if settings.redis_server.zscore("news.up:#{news_id}",user_id) or
       settings.redis_server.zscore("news.down:#{news_id}",user_id)
       return false,"Duplicated vote."
    end

    # Check if the user has enough karma to perform this operation
    if $user['id'] != news['user_id']
        if (vote_type == :up and
             (get_user_karma(user_id) < NewsUpvoteMinKarma)) or
           (vote_type == :down and
             (get_user_karma(user_id) < NewsDownvoteMinKarma))
            return false,"You don't have enough karma to vote #{vote_type}"
        end
    end

    # News was not already voted by that user. Add the vote.
    # Note that even if there is a race condition here and the user may be
    # voting from another device/API in the time between the ZSCORE check
    # and the zadd, this will not result in inconsistencies as we will just
    # update the vote time with ZADD.
    if settings.redis_server.zadd("news.#{vote_type}:#{news_id}", Time.now.to_i, user_id)
        settings.redis_server.hincrby("news:#{news_id}",vote_type,1)
    end
    settings.redis_server.zadd("user.saved:#{user_id}", Time.now.to_i, news_id) if vote_type == :up

    # Compute the new values of score and karma, updating the news accordingly.
    score = compute_news_score(news)
    news["score"] = score
    rank = compute_news_rank(news)
    settings.redis_server.hmset("news:#{news_id}",
        "score",score,
        "rank",rank)
    settings.redis_server.zadd("news.top",rank,news_id)

    # Remove some karma to the user if needed, and transfer karma to the
    # news owner in the case of an upvote.
    if $user['id'] != news['user_id']
        if vote_type == :up
            increment_user_karma_by(user_id,-NewsUpvoteKarmaCost)
            increment_user_karma_by(news['user_id'],NewsUpvoteKarmaTransfered)
        else
            increment_user_karma_by(user_id,-NewsDownvoteKarmaCost)
        end
    end

    return rank,nil
end

# Given the news compute its score.
# No side effects.
def compute_news_score(news)
    upvotes = settings.redis_server.zrange("news.up:#{news["id"]}",0,-1,:withscores => true)
    downvotes = settings.redis_server.zrange("news.down:#{news["id"]}",0,-1,:withscores => true)
    # FIXME: For now we are doing a naive sum of votes, without time-based
    # filtering, nor IP filtering.
    # We could use just ZCARD here of course, but I'm using ZRANGE already
    # since this is what is needed in the long term for vote analysis.
    score = (upvotes.length/2) - (downvotes.length/2)
    # Now let's add the logarithm of the sum of all the votes, since
    # something with 5 up and 5 down is less interesting than something
    # with 50 up and 50 donw.
    votes = upvotes.length/2+downvotes.length/2
    if votes > NewsScoreLogStart
        score += Math.log(votes-NewsScoreLogStart)*NewsScoreLogBooster
    end
    score
end

# Given the news compute its rank, that is function of time and score.
#
# The general forumla is RANK = SCORE / (AGE ^ AGING_FACTOR)
def compute_news_rank(news)
    age = (Time.now.to_i - news["ctime"].to_i)+NewsAgePadding
    return (news["score"].to_f)/((age/3600)**RankAgingFactor)
end

# Add a news with the specified url or text.
#
# If an url is passed but was already posted in the latest 48 hours the
# news is not inserted, and the ID of the old news with the same URL is
# returned.
#
# Return value: the ID of the inserted news, or the ID of the news with
# the same URL recently added.
def insert_news(title,url,text,user_id)
    # If we don't have an url but a comment, we turn the url into
    # text://....first comment..., so it is just a special case of
    # title+url anyway.
    textpost = url.length == 0
    if url.length == 0
        url = "text://"+text[0...CommentMaxLength]
    end
    # Check for already posted news with the same URL.
    if !textpost and (id = settings.redis_server.get("url:"+url))
        return id.to_i
    end
    # We can finally insert the news.
    ctime = Time.new.to_i
    news_id = settings.redis_server.incr("news.count")
    settings.redis_server.hmset("news:#{news_id}",
        "id", news_id,
        "title", title,
        "url", url,
        "user_id", user_id,
        "ctime", ctime,
        "score", 0,
        "rank", 0,
        "up", 0,
        "down", 0,
        "comments", 0)
    # The posting user virtually upvoted the news posting it
    rank,error = vote_news(news_id,user_id,:up)
    # Add the news to the user submitted news
    settings.redis_server.zadd("user.posted:#{user_id}",ctime,news_id)
    # Add the news into the chronological view
    settings.redis_server.zadd("news.cron",ctime,news_id)
    # Add the news into the top view
    settings.redis_server.zadd("news.top",rank,news_id)
    # Add the news url for some time to avoid reposts in short time
    settings.redis_server.setex("url:"+url,PreventRepostTime,news_id) if !textpost
    # Set a timeout indicating when the user may post again
    settings.redis_server.setex("user:#{$user['id']}:submitted_recently",NewsSubmissionBreak,'1')
    return news_id
end

# Edit an already existing news.
#
# On success the news_id is returned.
# On success but when a news deletion is performed (empty title) -1 is returned.
# On failure (for instance news_id does not exist or does not match
#             the specified user_id) false is returned.
def edit_news(news_id,title,url,text,user_id)
    news = get_news_by_id(news_id)
    return false if !news or news['user_id'].to_i != user_id.to_i
    return false if !(news['ctime'].to_i > (Time.now.to_i - NewsEditTime))

    # If we don't have an url but a comment, we turn the url into
    # text://....first comment..., so it is just a special case of
    # title+url anyway.
    textpost = url.length == 0
    if url.length == 0
        url = "text://"+text[0...CommentMaxLength]
    end
    # Even for edits don't allow to change the URL to the one of a
    # recently posted news.
    if !textpost and url != news['url']
        return false if settings.redis_server.get("url:"+url)
        # No problems with this new url, but the url changed
        # so we unblock the old one and set the block in the new one.
        # Otherwise it is easy to mount a DOS attack.
        settings.redis_server.del("url:"+news['url'])
        settings.redis_server.setex("url:"+url,PreventRepostTime,news_id) if !textpost
    end
    # Edit the news fields.
    settings.redis_server.hmset("news:#{news_id}",
        "title", title,
        "url", url)
    return news_id
end

# Mark an existing news as removed.
def del_news(news_id,user_id)
    news = get_news_by_id(news_id)
    return false if !news or news['user_id'].to_i != user_id.to_i
    return false if !(news['ctime'].to_i > (Time.now.to_i - NewsEditTime))

    settings.redis_server.hmset("news:#{news_id}","del",1)
    settings.redis_server.zrem("news.top",news_id)
    settings.redis_server.zrem("news.cron",news_id)
    return true
end

# Return the host part of the news URL field.
# If the url is in the form text:// nil is returned.
def news_domain(news)
    su = news["url"].split("/")
    domain = (su[0] == "text:") ? nil : su[2]
end

# Assuming the news has an url in the form text:// returns the text
# inside. Otherwise nil is returned.
def news_text(news)
    su = news["url"].split("/")
    (su[0] == "text:") ? news["url"][7..-1] : nil
end

# Turn the news into its RSS representation
# This function expects as input a news entry as obtained from
# the get_news_by_id function.
def news_to_rss(news)
    domain = news_domain(news)
    news = {}.merge(news) # Copy the object so we can modify it as we wish.
    news["ln_url"] = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}/news/#{news["id"]}"
    news["url"] = news["ln_url"] if !domain

    H.item {
        H.title {
            H.entities news["title"]
        } + " " +
        H.guid {
            H.entities news["url"]
        } + " " +
        H.link {
            H.entities news["url"]
        } + " " +
        H.description {
            "<![CDATA[" +
            H.a(:href=>news["ln_url"]) {
                "Comments"
            } + "]]>"
        } + " " +
        H.comments {
            H.entities news["ln_url"]
        }
    }+"\n"
end


# Turn the news into its HTML representation, that is
# a linked title with buttons to up/down vote plus additional info.
# This function expects as input a news entry as obtained from
# the get_news_by_id function.
def news_to_html(news)
    return H.article(:class => "deleted") {
        "[deleted news]"
    } if news["del"]
    domain = news_domain(news)
    news = {}.merge(news) # Copy the object so we can modify it as we wish.
    news["url"] = "/news/#{news["id"]}" if !domain
    upclass = "uparrow"
    downclass = "downarrow"
    if news["voted"] == :up
        upclass << " voted"
        downclass << " disabled"
    elsif news["voted"] == :down
        downclass << " voted"
        upclass << " disabled"
    end
    H.article("data-news-id" => news["id"]) {
        H.a(:href => "#up", :class => upclass) {
            "&#9650;"
        }+" "+
        H.h2 {
            H.a(:href=>news["url"]) {
                H.entities news["title"]
            }
        }+" "+
        H.address {
            if domain
                "at "+H.entities(domain)
            else "" end +
            if ($user and $user['id'].to_i == news['user_id'].to_i and
                news['ctime'].to_i > (Time.now.to_i - NewsEditTime))
                " " + H.a(:href => "/editnews/#{news["id"]}") {
                    "[edit]"
                }
            else "" end
        }+
        H.a(:href => "#down", :class =>  downclass) {
            "&#9660;"
        }+
        H.p {
            "#{news["up"]} up and #{news["down"]} down, posted by "+
            H.username {
                H.a(:href=>"/user/"+H.urlencode(news["username"])) {
                    H.entities news["username"]
                }
            }+" "+str_elapsed(news["ctime"].to_i)+" "+
            H.a(:href => "/news/#{news["id"]}") {
                news["comments"]+" comments"
            }
        }#+"score: "+news["score"].to_s+" old rank:"+news["rank"].to_s+" new rank:"+compute_news_rank(news).to_s
    }+"\n"
end

# If 'news' is a list of news entries (Ruby hashes with the same fields of
# the Redis hash representing the news in the DB) this function will render
# the RSS needed to show this news.
def news_list_to_rss(news)
    aux = ""
    news.each{|n|
        aux << news_to_rss(n)
    }
    aux
end

# If 'news' is a list of news entries (Ruby hashes with the same fields of
# the Redis hash representing the news in the DB) this function will render
# the HTML needed to show this news.
def news_list_to_html(news,paginate=nil)
    H.section(:id => "newslist") {
        aux = ""
        news.each{|n|
            aux << news_to_html(n)
        }
        if paginate
            last_displayed = paginate[:start]+paginate[:perpage]
            if last_displayed < paginate[:count]
                nextpage = paginate[:link].sub("$",
                           (paginate[:start]+paginate[:perpage]).to_s)
                aux << H.a(:href => nextpage,:class=> "more") {"[more]"}
            end
        end
        aux
    }
end

# Updating the rank would require some cron job and worker in theory as
# it is time dependent and we don't want to do any sorting operation at
# page view time. But instead what we do is to compute the rank from the
# score and update it in the sorted set only if there is some sensible error.
# This way ranks are updated incrementally and "live" at every page view
# only for the news where this makes sense, that is, top news.
#
# Note: this function can be called in the context of redis.pipelined {...}
def update_news_rank_if_needed(n)
    real_rank = compute_news_rank(n)
    if (real_rank-n["rank"].to_f).abs > 0.001
        settings.redis_server.hmset("news:#{n["id"]}","rank",real_rank)
        settings.redis_server.zadd("news.top",real_rank,n["id"])
        n["rank"] = real_rank.to_s
    end
end

# Generate the main page of the web site, the one where news are ordered by
# rank.
# 
# As a side effect thsi function take care of checking if the rank stored
# in the DB is no longer correct (as time is passing) and updates it if
# needed.
#
# This way we can completely avoid having a cron job adjusting our news
# score since this is done incrementally when there are pageviews on the
# site.
def get_top_news
    news_ids = settings.redis_server.zrevrange("news.top",0,TopNewsPerPage-1)
    result = get_news_by_id(news_ids,:update_rank => true)
    # Sort by rank before returning, since we adjusted ranks during iteration.
    result.sort{|a,b| b["rank"].to_f <=> a["rank"].to_f}
end

# Get news in chronological order.
def get_latest_news
    news_ids = settings.redis_server.zrevrange("news.cron",0,LatestNewsPerPage-1)
    get_news_by_id(news_ids,:update_rank => true)
end

# Get saved news of current user
def get_saved_news(user_id,start=0)
    count = settings.redis_server.zcard("user.saved:#{user_id}").to_i
    news_ids = settings.redis_server.zrevrange("user.saved:#{user_id}",start,start+(SavedNewsPerPage-1))
    return get_news_by_id(news_ids),count
end

###############################################################################
# Comments
###############################################################################

# This function has different behaviors, depending on the arguments:
#
# 1) If comment_id is -1 insert a new comment into the specified news.
# 2) If comment_id is an already existing comment in the context of the
#    specified news, updates the comment.
# 3) If comment_id is an already existing comment in the context of the
#    specified news, but the comment is an empty string, delete the comment.
#
# Return value:
#
# If news_id does not exist or comment_id is not -1 but neither a valid
# comment for that news, nil is returned.
# Otherwise an hash is returned with the following fields:
#   news_id: the news id
#   comment_id: the updated comment id, or the new comment id
#   op: the operation performed: "insert", "update", or "delete"
#
# More informations:
#
# The parent_id is only used for inserts (when comment_id == -1), otherwise
# is ignored.
def insert_comment(news_id,user_id,comment_id,parent_id,body)
    news = get_news_by_id(news_id)
    return false if !news
    if comment_id == -1
        comment = {"score" => 0,
                   "body" => body,
                   "parent_id" => parent_id,
                   "user_id" => user_id,
                   "ctime" => Time.now.to_i,
                   "up" => [user_id.to_i] };
        comment_id = Comments.insert(news_id,comment)
        return false if !comment_id
        settings.redis_server.hincrby("news:#{news_id}","comments",1);
        settings.redis_server.zadd("user.comments:#{user_id}",
            Time.now.to_i,
            news_id.to_s+"-"+comment_id.to_s);
        return {
            "news_id" => news_id,
            "comment_id" => comment_id,
            "op" => "insert"
        }
        increment_user_karma_by(user_id,KarmaIncrementComment)
    end

    # If we reached this point the next step is either to update or
    # delete the comment. So we make sure the user_id of the request
    # matches the user_id of the comment.
    # We also make sure the user is in time for an edit operation.
    c = Comments.fetch(news_id,comment_id)
    return false if !c or c['user_id'].to_i != user_id.to_i
    return false if !(c['ctime'].to_i > (Time.now.to_i - CommentEditTime))

    if body.length == 0
        return false if !Comments.del_comment(news_id,comment_id)
        settings.redis_server.hincrby("news:#{news_id}","comments",-1);
        return {
            "news_id" => news_id,
            "comment_id" => comment_id,
            "op" => "delete"
        }
    else
        update = {"body" => body}
        update = {"del" => 0} if c['del'].to_i == 1
        return false if !Comments.edit(news_id,comment_id,update)
        return {
            "news_id" => news_id,
            "comment_id" => comment_id,
            "op" => "update"
        }
    end
end

# Compute the comment score
def compute_comment_score(c)
    upcount = (c['up'] ? c['up'].length : 0)
    downcount = (c['down'] ? c['down'].length : 0)
    upcount-downcount
end

# Render a comment into HTML.
# 'c' is the comment representation as a Ruby hash.
# 'u' is the user, obtained from the user_id by the caller.
def comment_to_html(c,u,news_id)
    indent = "margin-left:#{c['level'].to_i*CommentReplyShift}px"
    score = compute_comment_score(c)

    if c['del'] and c['del'].to_i == 1
        return H.article(:style => indent,:class=>"commented deleted") {
            "[comment deleted]"
        }
    end
    show_edit_link = !c['topcomment'] &&
                ($user && ($user['id'].to_i == c['user_id'].to_i)) &&
                (c['ctime'].to_i > (Time.now.to_i - CommentEditTime))

    H.article(:class => "comment", :style=>indent, "data-comment-id"=>"#{news_id}-#{c['id']}") {
        H.span(:class => "avatar") {
            email = u["email"] || ""
            digest = Digest::MD5.hexdigest(email)
            H.img(:src=>"http://gravatar.com/avatar/#{digest}?s=48&d=mm")
        }+H.span(:class => "info") {
            H.span(:class => "username") {
                H.a(:href=>"/user/"+H.urlencode(u["username"])) {
                    H.entities u["username"]
                }
            }+" "+str_elapsed(c["ctime"].to_i)+". "+
            if !c['topcomment']
                H.a(:href=>"/comment/#{news_id}/#{c["id"]}", :class=>"reply") {
                    "link"
                }+" "
            else "" end +
            if $user and !c['topcomment']
                H.a(:href=>"/reply/#{news_id}/#{c["id"]}", :class=>"reply") {
                    "reply"
                }+" "
            else " " end +
            if !c['topcomment']
                upclass = "uparrow"
                downclass = "downarrow"
                if $user and c['up'] and c['up'].index($user['id'].to_i)
                    upclass << " voted"
                    downclass << " disabled"
                elsif $user and c['down'] and c['down'].index($user['id'].to_i)
                    downclass << " voted"
                    upclass << " disabled"
                end
                "#{score} points "+
                H.a(:href => "#up", :class => upclass) {
                    "&#9650;"
                }+" "+
                H.a(:href => "#down", :class => downclass) {
                    "&#9660;"
                }
            else " " end +
            if show_edit_link
                H.a(:href=> "/editcomment/#{news_id}/#{c["id"]}",
                    :class =>"reply") {"edit"}+
                    " (#{
                        (CommentEditTime - (Time.now.to_i-c['ctime'].to_i))/60
                    } minutes left)"
            else "" end
        }+H.pre {
            H.entities(c["body"].strip)
        }
    }
end

def render_comments_for_news(news_id,root=-1)
    html = ""
    user = {}
    Comments.render_comments(news_id,root) {|c|
        user[c["id"]] = get_user_by_id(c["user_id"]) if !user[c["id"]]
        user[c["id"]] = DeletedUser if !user[c["id"]]
        u = user[c["id"]]
        html << comment_to_html(c,u,news_id)
    }
    H.div("id" => "comments") {html}
end

def vote_comment(news_id,comment_id,user_id,vote_type)
    user_id = user_id.to_i
    comment = Comments.fetch(news_id,comment_id)
    return false if !comment
    varray = (comment[vote_type.to_s] or [])
    return false if varray.index(user_id)
    varray << user_id
    return Comments.edit(news_id,comment_id,{vote_type.to_s => varray})
end

###############################################################################
# Utility functions
###############################################################################

# Given an unix time in the past returns a string stating how much time
# has elapsed from the specified time, in the form "2 hours ago".
def str_elapsed(t)
    seconds = Time.now.to_i - t
    return "now" if seconds <= 1
    return "#{seconds} seconds ago" if seconds < 60
    return "#{seconds/60} minutes ago" if seconds < 60*60
    return "#{seconds/60/60} hours ago" if seconds < 60*60*24
    return "#{seconds/60/60/24} days ago"
end

# Generic API limiting function
def rate_limit_by_ip(delay,*tags)
    key = "limit:"+tags.join(".")
    return true if settings.redis_server.exists(key)
    settings.redis_server.setex(key,delay,1)
    return false
end

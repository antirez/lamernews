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
# policies, either expressed or implied, of Salvaore Sanfilippo.

require 'rubygems'
require 'hiredis'
require 'redis'
require 'page'
require 'app_config'
require 'sinatra'
require 'json'
require 'digest/sha1'

before do
    $r = Redis.new(:host => RedisHost, :port => RedisPort) if !$r
    H = HTMLGen.new if !defined?(H)
    $user = nil
    auth_user(request.cookies['auth'])
end

get '/' do
    H.set_title "Top News - #{SiteName}"
    news = get_top_news
    H.page {
        H.h2 {"Top news"}+news_list_to_html(news)
    }
end

get '/latest' do
    H.set_title "Latest news - #{SiteName}"
    news = get_latest_news
    H.page {
        H.h2 {"Latest news"}+news_list_to_html(news)
    }
end

get '/login' do
    H.set_title "Login - #{SiteName}"
    H.page {
        H.login {
            H.form(:name=>"f") {
                H.label(:for => "username") {"username"}+
                H.inputtext(:name => "username")+
                H.label(:for => "password") {"password"}+
                H.inputtext(:name => "password")+H.br+
                H.checkbox(:name => "register", :value => "1")+
                "create account"+H.br+
                H.button(:name => "do_login", :value => "Login")
            }
        }+
        H.div(:id => "errormsg"){}+
        H.script(:type=>"text/javascript") {'
            $(document).ready(function() {
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
        H.submitform {
            H.form(:name=>"f") {
                H.label(:for => "title") {"title"}+
                H.inputtext(:name => "title", :size => 80)+H.br+
                H.label(:for => "url") {"url"}+H.br+
                H.inputtext(:name => "url", :size => 60)+H.br+
                "or if you don't have an url type some text"+
                H.br+
                H.label(:for => "text") {"text"}+
                H.textarea(:name => "text", :cols => 60, :rows => 10) {}+
                H.inputhidden(:name => "apisecret",
                              :value => $user['apisecret']) {}+
                H.button(:name => "do_submit", :value => "Submit")
            }
        }+
        H.div(:id => "errormsg"){}+
        H.script(:type=>"text/javascript") {'
            $(document).ready(function() {
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
    H.set_title "#{H.entities news["title"]} - #{SiteName}"
    H.page {
        news_to_html(news)
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
        }
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
    auth = create_user(params[:username],params[:password])
    if auth 
        return {:status => "ok", :auth => auth}.to_json
    else
        return {
            :status => "err",
            :error => "Username is busy. Please select a different one."
        }.to_json
    end
end

post '/api/submit' do
    return {:status => "err", :error => "Not authenticated."}.to_json if !$user
    if not check_api_secret
        return {:status => "err", :error => "Wrong form secret."}.to_json
    end
    # We can have an empty url or an empty first comment, but not both.
    if (!check_params "title",:url,:text) or (params[:url].length == 0 and
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
    news_id = submit_news(params[:title],params[:url],params[:text],$user["id"])
    return  {
        :status => "ok",
        :news_id => news_id
    }.to_json
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
    rnavbar = H.rnav {
        if $user
            text = $user['username']
            link = "/user/"+H.urlencode($user['username'])
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
            H.entities SiteName
        }+navbar+" "+rnavbar
    }
end

def application_footer
    H.footer {
        "Lamer News source code is located "+
        H.a(:href=>"http://github.com/antirez/lamernews"){"here"}
    }
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
    id = $r.get("auth:#{auth}")
    return if !id
    user = $r.hgetall("user:#{id}")
    $user = user if user.length > 0
end

# Return the hex representation of an unguessable 160 bit random number.
def get_rand
    rand = "";
    File.open("/dev/urandom").read(20).each_byte{|x| rand << sprintf("%02x",x)}
    rand
end

# Create a new user with the specified username/password
#
# Return value: the auth token if the user was correctly creaed.
#               nil if the username already exists.
def create_user(username,password)
    return nil if $r.exists("username.to.id:#{username.downcase}")
    id = $r.incr("users.count")
    auth_token = get_rand
    $r.hmset("user:#{id}",
        "id",id,
        "username",username,
        "password",hash_password(password),
        "ctime",Time.now.to_i,
        "karma",10,
        "about","",
        "email","",
        "auth",auth_token,
        "apisecret",get_rand,
        "flags","",
        "karma_incr_time",Time.new.to_i)
    $r.set("username.to.id:#{username.downcase}",id)
    $r.set("auth:#{auth_token}",id)
    return auth_token
end

# Update the specified user authentication token with a random generated
# one. This in other words means to logout all the sessions open for that
# user.
#
# Return value: on success the new token is returned. Otherwise nil.
# Side effect: the auth token is modified.
def update_auth_token(user_id)
    user = get_user_by_id(user_id)
    puts user.inspect
    return nil if !user
    $r.del("auth:#{user['auth']}")
    new_auth_token = get_rand
    $r.hmset("user:#{user_id}","auth",new_auth_token)
    $r.set("auth:#{new_auth_token}",user_id)
    return new_auth_token
end

# Turn the password into an hashed one, using
# SHA1(salt|password).
def hash_password(password)
    Digest::SHA1.hexdigest(PasswordSalt+password)
end

# Return the user from the ID.
def get_user_by_id(id)
    $r.hgetall("user:#{id}")
end

# Return the user from the username.
def get_user_by_username(username)
    id = $r.get("username.to.id:#{username.downcase}")
    return nil if !id
    get_user_by_id(id)
end

# Check if the username/password pair identifies an user.
# If so the auth token and form secret are returned, otherwise nil is returned.
def check_user_credentials(username,password)
    hp = hash_password(password)
    user = get_user_by_username(username)
    return nil if !user
    (user['password'] == hp) ? [user['auth'],user['apisecret']] : nil
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
    news = $r.pipelined {
        news_ids.each{|nid|
            $r.hgetall("news:#{nid}")
        }
    }

    # Get all the news
    $r.pipelined {
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
    usernames = $r.pipelined {
        result.each{|n|
            $r.hget("user:#{n["user_id"]}","username")
        }
    }
    result.each_with_index{|n,i|
        n["username"] = usernames[i]
    }

    # Load $User vote information if we are in the context of a
    # registered user.
    if $user
        votes = $r.pipelined {
            result.each{|n|
                $r.zscore("news.up:#{n["id"]}",$user["id"])
                $r.zscore("news.down:#{n["id"]}",$user["id"])
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
# Return value: true if the vote was inserted, otherwise
# if the vote was duplicated, or user_id or news_id don't match any
# existing user or news, false is returned.
def vote_news(news_id,user_id,vote_type)
    # Fetch news and user
    user = ($user and $user["id"] == user_id) ? $user : get_user_by_id(user_id)
    news = get_news_by_id(news_id)
    return false if !news or !user

    # Now it's time to check if the user already voted that news, either
    # up or down. If so return now.
    if $r.zscore("news.up:#{news_id}",user_id) or
       $r.zscore("news.down:#{news_id}",user_id)
       return false
    end

    # News was not already voted by that user. Add the vote.
    if $r.zadd("news.#{vote_type}:#{news_id}", Time.now.to_i, user_id)
        $r.hincrby("news:#{news_id}",vote_type,1)
    end
    $r.zadd("user.saved:#{user_id}", Time.now.to_i, news_id) if vote_type == :up
    return true
end

# Given the news compute its score.
# No side effects.
def compute_news_score(news)
    upvotes = $r.zrange("news.up:#{news["id"]}",0,-1,:withscores => true)
    downvotes = $r.zrange("news.down:#{news["id"]}",0,-1,:withscores => true)
    # FIXME: For now we are doing a naive sum of votes, without time-based
    # filtering, nor IP filtering.
    # We could use just ZCARD here of course, but I'm using ZRANGE already
    # since this is what is needed in the long term for vote analysis.
    return (upvotes.length/2) - (downvotes.length/2)
end

# Given the news compute its rank, that is function of time and score.
#
# The general forumla is RANK = SCORE / (AGE ^ AGING_FACTOR)
def compute_news_rank(news)
    age = (Time.now.to_i - news["ctime"].to_i)+NewsAgePadding
    return (news["score"].to_f*1000)/(age**RankAgingFactor)
end

# Add a news with the specified url or text.
#
# If an url is passed but was already posted in the latest 48 hours the
# news is not inserted, and the ID of the old news with the same URL is
# returned.
#
# Return value: the ID of the inserted news, or the ID of the news with
# the same URL recently added.
def submit_news(title,url,text,user_id)
    # If we don't have an url but a comment, we turn the url into
    # text://....first comment..., so it is just a special case of
    # title+url anyway.
    textpost = url.length == 0
    if url.length == 0
        url = "text://"+text[0...CommentMaxLength]
    end
    # Check for already posted news with the same URL.
    if !textpost and (id = $r.get("url:"+url))
        return id.to_i
    end
    # We can finally insert the news.
    ctime = Time.new.to_i
    news_id = $r.incr("news.count")
    $r.hmset("news:#{news_id}",
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
    vote_news(news_id,user_id,:up)
    news = get_news_by_id(news_id)
    score = compute_news_score(news)
    news["score"] = score
    rank = compute_news_rank(news)
    $r.hmset("news:#{news_id}",
        "score",score,
        "rank",rank)
    # Add the news to the user submitted news
    $r.zadd("user.posted:#{user_id}",ctime,news_id)
    # Add the news into the chronological view
    $r.zadd("news.cron",ctime,news_id)
    # Add the news into the top view
    $r.zadd("news.top",rank,news_id)
    # Add the news url for some time to avoid reposts in short time
    if !textpost
        $r.setex("url:"+url,PreventRepostTime,news_id)
    end
    return news_id
end

# Turn the news into its HTML representation, that is
# a linked title with buttons to up/down vote plus additional info.
# This function expects as input a news entry as obtained from
# the get_news_by_id function.
def news_to_html(news)
    su = news["url"].split("/")
    domain = (su[0] == "text:") ? "comment" : su[2]
    if news["voted"] == :up
        upclass = "voted"
        downclass = "disabled"
    elsif news["voted"] == :down
        downclass = "voted"
        upclass = "disabled"
    end
    H.news(:id => news["id"]) {
        H.uparrow(:class => upclass) {
            "&#9650;"
        }+" "+
        H.h2 {
            H.a(:href=>news["url"]) {
                H.entities news["title"]
            }
        }+" "+
        H.address {
            "at "+H.entities(domain)
        }+" "+
        H.downarrow(:class => downclass) {
            "&#9660;"
        }+
        H.p {
            "#{news["up"]} up and #{news["down"]} down, posted by "+
            H.username {
                H.a(:href=>"/user/"+H.urlencode(news["username"])) {
                    news["username"]
                }
            }+" "+str_elapsed(news["ctime"].to_i)+" "+
            H.a(:href => "/news/#{news["id"]}") {
                news["comments"]+" comments"
            }
        }
        #+news["score"]+","+news["rank"]+","+compute_news_rank(news).to_s
    }+"\n"
end

# If 'news' is a list of news entries (Ruby hashes with the same fields of
# the Redis hash representing the news in the DB) this function will render
# the HTML needed to show this news.
def news_list_to_html(news)
    H.newslist {
        aux = ""
        news.each{|n|
            aux << news_to_html(n)
        }
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
        $r.hmset("news:#{n["id"]}","rank",real_rank)
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
    news_ids = $r.zrevrange("news.top",0,NewsPerPage-1)
    result = get_news_by_id(news_ids,:update_rank => true)
    # Sort by rank before returning, since we adjusted ranks during iteration.
    result.sort{|a,b| b["rank"].to_f <=> a["rank"].to_f}
end

# Get news in chronological order.
def get_latest_news
    news_ids = $r.zrevrange("news.cron",0,NewsPerPage-1)
    result = get_news_by_id(news_ids,:update_rank => true)
end

###############################################################################
# Utilit functions
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

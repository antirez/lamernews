require 'sinatra'

###############################################################################
# API implementation
###############################################################################

module Lamernews
  class API < Sinatra::Base
  
    post '/api/logout' do
        content_type 'application/json'
        if $user and check_api_secret
            update_auth_token($user)
            return {:status => "ok"}.to_json
        else
            return {
                :status => "err",
                :error => "Wrong auth credentials or API secret."
            }.to_json
        end
    end
    
    get '/api/login' do
        content_type 'application/json'
        if (!check_params "username","password")
            return {
                :status => "err",
                :error => "Username and password are two required fields."
            }.to_json
        end
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
    
    get '/api/reset-password' do
        content_type 'application/json'
        if (!check_params "username","email")
            return {
                :status => "err",
                :error => "Username and email are two required fields."
            }.to_json
        end
    
        user = get_user_by_username(params[:username])
        if user && user['email'] && user['email'] == params[:email]
            id = user['id']
            # Rate limit password reset attempts.
            if (user['pwd_reset'] &&
                (Time.now.to_i - user['pwd_reset'].to_i) < PasswordResetDelay)
                return {
                    :status => "err",
                    :error => "Sorry, not enough time elapsed since last password reset request."
                }.to_json
            end
    
            if send_reset_password_email(user)
                # All fine, set the last password reset time to the current time
                # for rate limiting purposes, and send the email with the reset
                # link.
                $r.hset("user:#{id}","pwd_reset",Time.now.to_i)
                return {:status => "ok"}.to_json
            else
                return {
                    :status => "err",
                    :error => "Problem sending the email, please contact the site admin."
                }.to_json
            end
        else
            return {
                :status => "err",
                :error => "No match for the specified username / email pair."
            }.to_json
        end
    end
    
    post '/api/create_account' do
        content_type 'application/json'
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
        content_type 'application/json'
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
        content_type 'application/json'
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
        content_type 'application/json'
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
        content_type 'application/json'
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
        content_type 'application/json'
        return {:status => "err", :error => "Not authenticated."}.to_json if !$user
        if not check_api_secret
            return {:status => "err", :error => "Wrong form secret."}.to_json
        end
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
            $r.hmset("user:#{$user['id']}","password",
                hash_password(params[:password],$user['salt']))
        end
        $r.hmset("user:#{$user['id']}",
            "about", params[:about][0..4095],
            "email", params[:email][0..255])
        return {:status => "ok"}.to_json
    end
    
    post '/api/votecomment' do
        content_type 'application/json'
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
                :error => "Missing comment ID or invalid vote type."
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
    
    get  '/api/getnews/:sort/:start/:count' do
        content_type 'application/json'
        sort = params[:sort].to_sym
        start = params[:start].to_i
        count = params[:count].to_i
        if not [:latest,:top].index(sort)
            return {:status => "err", :error => "Invalid sort parameter"}.to_json
        end
        return {:status => "err", :error => "Count is too big"}.to_json if count > APIMaxNewsCount
    
        start = 0 if start < 0
        getfunc = method((sort == :latest) ? :get_latest_news : :get_top_news)
        news,numitems = getfunc.call(start,count)
        news.each{|n|
            ['rank','score','user_id'].each{|field| n.delete(field)}
        }
        return { :status => "ok", :news => news, :count => numitems }.to_json
    end
    
    get  '/api/getcomments/:news_id' do
        content_type 'application/json'
        return {
            :status => "err",
            :error => "Wrong news ID."
        }.to_json if not get_news_by_id(params[:news_id])
        thread = Comments.fetch_thread(params[:news_id])
        top_comments = []
        thread.each{|parent,replies|
            if parent.to_i == -1
                top_comments = replies
            end
            replies.each{|r|
                user = get_user_by_id(r['user_id']) || DeletedUser
                r['username'] = user['username']
                r['replies'] = thread[r['id']] || []
                if r['up']
                    r['voted'] = :up if $user && r['up'].index($user['id'].to_i)
                    r['up'] = r['up'].length
                end
                if r['down']
                    r['voted'] = :down if $user && r['down'].index($user['id'].to_i)
                    r['down'] = r['down'].length
                end
                ['id','thread_id','score','parent_id','user_id'].each{|f|
                    r.delete(f)
                }
            }
        }
        return { :status => "ok", :comments => top_comments }.to_json
    end
    
  end
end

require 'rubygems'
require 'redis'
require 'page'
require 'app_config'
require 'sinatra'
require 'json'
require 'digest/sha1'

before do
    if !$r
    then
        $r = Redis.new(:host => RedisHost, :port => RedisPort)
        H = HTMLGen.new
    end
    $user = nil
    auth_user(request.cookies['auth'])
end

get '/' do
    H.set_title "Top News - #{SiteName}"
    H.page {
        "Hello World"
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

get '/api/login' do
    auth = check_user_credentials(params[:username],params[:password])
    if auth 
        return {:status => "ok", :auth => auth}.to_json
    else
        return {
            :status => "err",
            :error => "No match for the specified username / password pair."
        }.to_json
    end
end

get '/api/create_account' do
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

def application_header
    navitems = [    ["top","/"],
                    ["latest","/latest"]]
    navbar = H.nav {
        navitems.map{|ni|
            H.a(:href=>ni[1]) {H.entities ni[0]}
        }.inject{|a,b| a+"\n"+b}
    }
    rnavbar = H.rnav {
        if $user
            text = $user['username']
            link = "/user/"+H.urlencode($user['username'])
        else
            text = "login / register"
            link = "/login"
        end
        H.a(:href => link) {text}
    }
    H.header {
        H.h1 {
            H.entities SiteName
        }+navbar+" "+rnavbar
    }
end

def application_footer
    H.footer {
        "Lamer News source code is located "+H.a(:href=>""){"here"}
    }
end

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
        "username",username,
        "password",hash_password(password),
        "ctime",Time.now.to_i,
        "karma",10,
        "about","",
        "email","",
        "auth",auth_token)
    $r.set("username.to.id:#{username.downcase}",id)
    $r.set("auth:#{auth_token}",id)
    return auth_token
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
# If so the auth token is returned, otherwise nil is returned.
def check_user_credentials(username,password)
    hp = hash_password(password)
    user = get_user_by_username(username)
    return nil if !user
    (user['password'] == hp) ? user['auth'] : nil
end

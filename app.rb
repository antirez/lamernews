require 'rubygems'
require 'redis'
require 'page'
require 'app_config'
require 'sinatra'
require 'json'

before do
    if !$r
    then
        $r = Redis.new(:host => RedisHost, :port => RedisPort)
        H = HTMLGen.new
    end
    $user = nil
    check_auth(request.cookies[:auth])
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
    if params[:username] == 'antirez' and params[:password] == 'ANTIREZ'
        return {:status => "ok", :token => "foobar"}.to_json
    else
        return {:status => "err", :error => "no such user/pass"}.to_json
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
def check_auth(auth)
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
# Return value: true if the user was correctly creaed.
#               false if the username already exists.
def create_user(username,password)
    return false if $r.exists("useranme.to.id:#{username.downcase}")
    id = $r.incr("users.count")
    auth_token = get_rand
    $r.hmset("user:#{id}",
        "username",username,
        "password",password,
        "ctime",Time.now.to_i,
        "karma",10,
        "about","",
        "email","",
        "auth",auth_token)
    $r.set("useranme.to.id:#{username.downcase}",id)
    $r.set("auth:#{auth_token}",auth_token)
    return true
end

require 'rubygems'
require 'redis'
require 'page'
require 'app_config'
require 'sinatra'
require 'json'

before do
    $r = Redis.new(:host => RedisHost, :port => RedisPort)
    H = HTMLGen.new
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
    navitems = [    ["login / register","/login"],
                    ["top","/top"],
                    ["latest","/latest"]]
    navbar = H.nav {
        navitems.map{|ni|
            H.a(:href=>ni[1]) {H.entities ni[0]}
        }.inject{|a,b| a+"\n"+b}
    }
    H.header {
        H.h1 {
            H.entities SiteName
        }+navbar
    }
end

def application_footer
    H.footer {
        "Lamer News source code is located "+H.a(:href=>""){"here"}
    }
end

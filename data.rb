module Lamernews

  class RedisSetup
    def setup(uri=RedisURL)
        uri = URI.parse(uri)
        @r = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) unless @r
    end

    def initialize(app)
      setup
      @app = app 
    end 

    def call(env)
      env['redis'] = @r
      env['users'] = Users.new(@r, Rack::Request.new(env))
      @app.call(env)
    end 
  end
end

class Users

  attr_reader :r, :request

  def initialize(r, request)
    @r = r
    @request = request
  end

  # Create a new user with the specified username/password
  #
  # Return value: the function returns two values, the first is the
  #               auth token if the registration succeeded, otherwise
  #               is nil. The second is the error message if the function
  #               failed (detected testing the first return value).
  def create(username, password)
      if @r.exists("username.to.id:#{username.downcase}")
          return nil, "Username is already taken, please try a different one."
      end
      if rate_limit_by_ip(3600*15,"create_user", request.ip)
          return nil, "Please wait some time before creating a new user."
      end
      id = @r.incr("users.count")
      auth_token = get_rand
      salt = get_rand
      @r.hmset("user:#{id}",
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
      @r.set("username.to.id:#{username.downcase}",id)
      @r.set("auth:#{auth_token}",id)
  
      # First user ever created (id = 1) is an admin
      @r.hmset("user:#{id}","flags","a") if id.to_i == 1
      return auth_token,nil
  end
end

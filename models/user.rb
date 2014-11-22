class User
  attr_accessor :id, :name, :salt, :password, :ctime, :karma, :about, :email,
                :auth, :apisecret, :flags, :karma_incr_time, :replies

  def initialize args={}
    args.each do |key, val|
      send "#{key}=", val
    end
  end

  def self.find_or_create_using_google_oauth2 auth_data
    find_or_create auth_data['info']['name'], auth_data['info']['email']
  end

  def self.find_or_create name, email
    find_by_email(email) || create(name, email)
  end

  def self.create name, email
    id = $r.incr("users.count")
    auth_token = generate_auth_token
    apisecret = generate_api_secret
    $r.hmset "user:#{id}",
    "id",              id,
    "name",            name,
    "ctime",           Time.now.to_i,
    "karma",           UserInitialKarma,
    "about",           "",
    "email",           email,
    "auth",            auth_token,
    "apisecret",       apisecret,
    "flags",           "",
    "karma_incr_time", Time.now.to_i
    $r.set "email.to.id:#{email}", id
    $r.set "auth:#{auth_token}", id
    find(id)
  end

  def self.find_by_email email
    id = $r.get("email.to.id:#{email}")
    id && find(id) || nil
  end

  def self.find_by_auth_token auth
    id = $r.get("auth:#{auth}")
    id && find(id) || nil
  end

  def self.find id
    values = $r.hgetall("user:#{id}")
    new values if values.any?
  end

  def self.deleted_one
    @deleted_one ||= new
  end

  private

  def self.generate_auth_token
    get_rand
  end

  def self.generate_api_secret
    get_rand
  end
end

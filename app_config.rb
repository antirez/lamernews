# General
SiteName = "Lamer News"

# Redis config
RedisConfig = {:host => "127.0.0.1", :port => 10000}
## Check for Cloud Foundry
vcap_services = JSON.parse(ENV['VCAP_SERVICES']) if ENV['VCAP_SERVICES']
if vcap_services
  redis = vcap_services['redis-2.2'][0]
  RedisConfig = {:host => redis['credentials']['hostname'],
                 :port => redis['credentials']['port'],
                 :password => redis['credentials']['password']}
end

# Security
PasswordSalt = "*LAMER*news*"

# Comments
CommentMaxLength = 4096
CommentEditTime = 3600*2
CommentReplyShift = 30

# User
KarmaIncrementInterval = 3600*3
KarmaIncrementAmount = 1
DeletedUser = {"username" => "deleted_user", "email" => "", "id" => -1}

# News and ranking
NewsAgePadding = 60*10
TopNewsPerPage = 30
LatestNewsPerPage = 100
NewsEditTime = 60*15
NewsScoreLogBooster = 5
RankAgingFactor = 1.3
PreventRepostTime = 3600*48

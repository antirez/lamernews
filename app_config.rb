# General
SiteName = "Lamer News"

# Redis config
RedisHost = "127.0.0.1"
RedisPort = ENV["REDIS_PORT"] || 6379

# Security
PBKDF2Iterations = 1000 # Set this to 5000 to improve security. But it is slow.
UseOpenSSL = false
PasswordMinLength = 8

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

# General
SiteName = "Lamer News"

# Redis config
RedisHost = "127.0.0.1"
RedisPort = 10000

# Security
PBKDF2Iterations = 10000 # 10000 will make an attack harder but is slow.
PasswordSalt = "*LAMER*news*"
UseOpenSSL = true

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

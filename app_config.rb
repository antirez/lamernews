# General
SiteName = "Lamer News"

# Redis config
RedisHost = "127.0.0.1"
RedisPort = 10000

# Security
PBKDF2Iterations = 1000 # Set this to 5000 to improve security. But it is slow.
UseOpenSSL = false
PasswordMinLength = 8

# Comments
CommentMaxLength = 4096
CommentEditTime = 3600*2
CommentReplyShift = 60

# Karma
UserInitialKarma = 1
KarmaIncrementInterval = 3600
KarmaIncrementAmount = 1
NewsDownvoteMinKarma = 30
NewsDownvoteKarmaCost = 6
NewsUpvoteMinKarma = 0
NewsUpvoteKarmaCost = 1
NewsUpvoteKarmaTransfered = 1
KarmaIncrementComment = 1

# User
DeletedUser = {"username" => "deleted_user", "email" => "", "id" => -1}

# News and ranking
NewsAgePadding = 60*60*8
TopNewsPerPage = 30
LatestNewsPerPage = 100
NewsEditTime = 60*15
NewsScoreLogStart = 10
NewsScoreLogBooster = 2
RankAgingFactor = 1.6
PreventRepostTime = 3600*48
NewsSubmissionBreak = 60*15
SavedNewsPerPage = 10

# Footer links
FooterTwitterLink = false
FooterGoogleGroupLink = false

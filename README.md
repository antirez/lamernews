About
===

Lamer news is an implementation of a Reddit / Hacker News style news web site
written using Ruby, Sinatra, Redis and jQuery.

The goal is to have a system that is very simple to understand and modify and
that is able to handle a very high load using a small virtual server, ensuring
at the same time a very low latency user experience.

This project was created in order to run http://lamernews.com but is free for
everybody to use, fork, and have fun with.

We believe it is also a good programming example for Redis as a sole DB of a
nontrivial, real world, web application.

Installation
===

Lamer news is a Ruby/Sinatra/Redis/jQuery application.
You need to install Redis and Ruby 1.9.2+ with the following gems:

* redis 3.0 or greater
* hiredis
* sinatra
* json
* ruby-hmac
* net/smtp
* openssl (not needed but will speedup the authentication if available).

Please note that Redis uses port 6379 by default, so you should either change
the port number in the configuration file (which is set to use port 10000), or
configure Redis to use a matching port.

How to contribute
===

I plan to hack on Lamer News in my free time as it is interesting to have
a non trivial open source example for Redis that is also an useful application.
However contributions are welcomed. Just make sure to:

* Keep it simple. No complex code, no extreme ruby programming. Ideally non ruby people should understand the code without much efforts.
* Don't use templates, they suck.
* If your code slows down significantly the page generation time it will not get merged.
* Do everything you can to avoid depending on new ruby gems.
* Open an issue on github before firing your editor to see if there are good chances that your changes will be merged.
* If you don't want to follow all this rules, forking the code is *encouraged*! The license is two clause BSD, do with this code what you want. Run your site, turn it into a blog, hack it to the extreme consequences. Have fun :)

Web sites using this code
===

* http://lamernews.com Programming News.
* http://hackingitalia.com Programming and Startup News (In Italian).
* http://www.echojs.com JavaScript News.

Data Layout
===

Users
---

Every user is represented by the following fields:

A Redis hash named `user:<user id>` with the following fields:

    id -> user ID
    username -> The username
    password -> Hashed password, PBKDF2(salt|password) note: | means concatenation
    ctime -> Registration time (unix time)
    karma -> User karma, earned visiting the site and posting good stuff
    about -> Some optional info about the user
    email -> Optional, used to show gravatars
    auth -> authentication token
    apisecret -> api POST requests secret code, to prevent CSRF attacks.
    flags -> user flags. "a" enables administrative privileges.
    karma_incr_time -> last time karma was incremented
    pwd_reset -> unix time of the last password reset requested.
    replies -> number of unread replies

Additionally for every user there is the following key:

    `username.to.id:<lowercase_username>` -> User ID

This is used to lookup users by name.

Frequency of user posting is limited by a key named
`user:<user_id>:submitted_recently` with TTL 15 minutes. If a user
attempts to post before that key has expired an error message notifies
the user of the amount of time until posting is permitted.

Account creation is rate limited by IP address with a key named
`limit:create_user:<ip_address>` with TTL 15 hours.

Authentication
---

Users receive an authentication token after a valid pair of username/password
is received.
This token is in the form of a SHA1-sized hex number.
The representation is a simple Redis key in the form:

    `auth:<lowercase_token>` -> User ID

News
---

News are represented as an hash with key name `news:<news id>`.
The hash has the following fields:

    id -> News id
    title -> News title
    url -> News url
    user_id => The User ID that posted the news
    ctime -> News creation time. Unix time.
    score -> News score. See source to check how this is computed.
    rank -> News score adjusted by age: RANK = SCORE / AGE^ALPHA
    up -> Counter with number of upvotes
    down -> Counter with number of downvotes
    comments -> number of comments

Note: up, down, comments fields are also available in other ways but we
denormalize for speed.

Also recently posted urls have a key named `url:<actual full url>` with TTL 48
hours and set to the news ID of a recently posted news having this url.

So if another user will try to post a given content again within 48 hours the
system will simply redirect it to the previous news.

News is never deleted, but just marked as deleted adding the "del"
field with value 1 to the news object. However when the post is
rendered into HTML, it is displayed as [deleted news] text.

News votes
---

Every news has a sorted set with user upvotes and downvotes. The keys are named
respectively `news.up:<news id>` and `news.down:<news id>`.

In the sorted sets the score is the unix time of the vote creation, the element
is the user ID of the voting user.

Posting a news will automatically register an up vote from the user posting
the news.

Saved news
---

The system stores a list of upvoted news for every user using a sorted set named
`user.saved:<user id>`, index by unix time. The value of the sorted set elements
is the `<news id>`.

Submitted news
---

Like saved news every user has an associated sorted set with news he posted.
The key is called `user.posted:<user id>`. Again the score is the unix time and
the element is the news id.

Top and Latest news
---

news.cron is used to generate the "Latest News" page.
It is a sorted set where the score is the Unix time the news was posted, and the
value is the news ID.

news.top is used to generate the "Top News" page.
It is a sorted set where the score is the "RANK" of the news, and the value is
the news ID.

Comments
---

Comments are represented using a very memory efficient pattern.
The system is implemented in the comments.rb file.

In short every thread (that is a collection of comments for a given
news) is represented by an hash. Every hash entry represents a
single comment:

* The hash field is the comment ID.
* The hash value is a JSON representation of the "comment object".

The comment object has many fields, like `ctime` (creation time), `body`,
`user_id`, and so forth. In order to render all the comments for a thread
we simply do an HGETALL to fetch everything. Then we run the list of
returned comments and build a graph of comments, calling a recursive
function with this graph as input.

Comments are never deleted, but just marked as deleted adding the "del"
field with value 1 to the comment object. However when the thread is
rendered into HTML deleted comments without childs are not displayed.
Deleted comments with childs are displayed as [deleted comment] text.

Please check comments.rb for details, it is trivial to read.

User comments
---

All the comments posted by a given user are also taken into a sorted set
of comments, keyed by creation time. The key name is: `user.comments:<userid>`.

In this sorted set the score is the unix time and the value is a string composed in this way: `<newsid>-<commentid>`. So a unique comment is referenced by the news id and the id of the comment inside the hash of comments for this news. Example of an actual comment pointer: `882-15`.

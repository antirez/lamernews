FROM ubuntu:14.04
MAINTAINER Giovanni Intini <giovanni@mikamai.com>

ENV REFRESHED_AT 2014-11-22

RUN apt-get -yqq update && apt-get install -yqq autoconf \
		build-essential \
		# imagemagick \
		# libbz2-dev \
		# libcurl4-openssl-dev \
		# libevent-dev \
		# libffi-dev \
		# libglib2.0-dev \
		# libjpeg-dev \
		# libmagickcore-dev \
		# libmagickwand-dev \
		# libmysqlclient-dev \
		# libncurses-dev \
		# libpq-dev \
		# libreadline-dev \
		# libsqlite3-dev \
		libssl-dev \
		# libxml2-dev \
		# libxslt-dev \
		libyaml-dev \
		zlib1g-dev \

                git-core \

                curl
                # procps \

		# node \
  && rm -rf /var/lib/apt/lists/*

ENV RUBY_MAJOR 2.1
ENV RUBY_VERSION 2.1.5

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN apt-get -yqq update \
	&& apt-get -yqq install -y bison ruby \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /usr/src/ruby \
	&& curl -SL "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.bz2" \
		| tar -xjC /usr/src/ruby --strip-components=1 \
	&& cd /usr/src/ruby \
	&& autoconf \
	&& ./configure --disable-install-doc \
	&& make -j"$(nproc)" \
	&& apt-get purge -y --auto-remove bison ruby \
	&& make install \
	&& rm -r /usr/src/ruby

RUN echo 'gem: --no-rdoc --no-ri' >> $HOME/.gemrc
RUN gem install bundler
RUN bundle config path /app/vendor/remote_gems

RUN git clone https://github.com/mikamai/lamernews.git /app

WORKDIR /app

RUN bundle install --without test development

EXPOSE 9292

RUN git fetch
RUN git checkout intinig/docker-fantasies

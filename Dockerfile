FROM ruby:3.2.2

RUN set -x; \
  apt-get update && apt-get install -y --no-install-recommends \
  zlib1g-dev \
  build-essential \
  libssl-dev \
  libreadline-dev \
  libyaml-dev \
  libxml2-dev \
  libxslt1-dev \
  libcurl4-openssl-dev \
  libffi-dev \
  nodejs \
  imagemagick \
  libmagickwand-dev \
  libsqlite3-dev \
  sqlite3 \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/shared/log /var/www/shared/pids /var/www/shared/sockets

ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV UNICORN_CENIT_SERVER=true

ENV RAILS_ROOT=/var/www/cenit
RUN mkdir -p $RAILS_ROOT
WORKDIR /var/www/cenit

RUN gem install bundler -v 2.4.22
COPY Gemfile .
COPY Gemfile.lock .

RUN bundle config set deployment true \
  && bundle config set without 'development test' \
  && bundle install --jobs 4 --retry 3

COPY . .
RUN chmod +x env.sh

CMD ["/bin/bash", "-c", "/var/www/cenit/env.sh; bundle exec unicorn_rails -c config/unicorn.rb"]

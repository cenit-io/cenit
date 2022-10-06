FROM ruby:2.7.4

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN set -x; \
  apt-get update && apt-get install -y --no-install-recommends \
  openssh-server \
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
  yarn \
  imagemagick \
  libmagickwand-dev \
  libsqlite3-dev \
  sqlite3 \
  libxslt1-dev


# Intall software-properties-common for add-apt-repository
RUN apt-get install -qq -y software-properties-common

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV UNICORN_CENIT_SERVER=true

ENV RAILS_ROOT /var/www/cenit
RUN mkdir -p $RAILS_ROOT
WORKDIR /var/www/cenit

RUN gem install bundler:2.3
COPY Gemfile .
COPY Gemfile.lock .
RUN gem install rails bundler
RUN bundle install --without development test
COPY . .
RUN chmod +x env.sh

RUN yarn install --check-files

CMD ["/bin/bash", "-c", "/var/www/cenit/env.sh; bundle exec unicorn_rails -c config/unicorn.rb"]

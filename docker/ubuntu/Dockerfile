FROM ruby:2.5.5

# Install dependencies:
#   - build-essential: To ensure certain gems can be compiled
#   - nodejs: Compile assets
RUN set -x; \
  apt update \
  && apt upgrade -y \
  && apt install -y --no-install-recommends \
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
  imagemagick \
  libmagickwand-dev \
  libsqlite3-dev \
  sqlite3 \
  libxslt1-dev


RUN git clone --single-branch --branch master https://github.com/cenit-io/cenit.git /var/www/cenit

ENV RAILS_ROOT /var/www/cenit

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

# Set working directory
WORKDIR $RAILS_ROOT

ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV UNICORN_CENIT_SERVER=true

RUN gem install bundler

RUN bundle install --jobs 20 --retry 5 --without development test

EXPOSE 8080

![cenit_io](https://user-images.githubusercontent.com/4213488/150586701-53545c9b-b4f9-497f-9782-ef6a19715ecd.svg)

[![Code Climate](https://codeclimate.com/github/openjaf/cenit/badges/gpa.svg)](https://codeclimate.com/github/openjaf/cenit)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()

[![OpenAPIs in collection][numApis-image]][apisDir-link]
[![OpenAPI specs][numSpecs-image]][apisDir-link]
[![Endpoints][endpoints-image]][apisDir-link]

[![Follow on Twitter][twitterFollow-image]][twitterFollow-link]


* [Join our Slack][join-slack-link]
[(cenitio.slack.com)][join-slack-link]
* [docs](https://cenit-io.github.io/docs)
* [Shared Collections](https://cenit.io/setup~shared_collection)
* support@cenit.io

# Cenit [(https://cenit.io)](https://cenit.io)
# New Dockerfile use by backend
```
FROM ruby:2.7.4 as build

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
  libxslt1-dev\
  net-tools\
  vim

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
COPY . .
COPY ./config/application.example.yml ./config/application.yml 
RUN gem install bundler:2.3
RUN gem install rails bundler
RUN bundle install --without development test

RUN yarn install --check-files


RUN chmod +x env.sh
EXPOSE 8080

CMD [ "bash -c 'rm -fR /var/www/shared/pids/* ; bundle exec unicorn_rails -c config/unicorn.rb'" ]

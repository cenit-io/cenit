FROM ruby:2.5.5

ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV UNICORN_CENIT_SERVER=true

RUN set -x; \
  apt update \
  && apt upgrade -y \
  && apt install -y --no-install-recommends \
  openssh-server \
  build-essential \
  nodejs \
  git \
  imagemagick \
  libmagickwand-dev

RUN git clone https://github.com/cenit-io/cenit.git -b master /var/www/cenit

WORKDIR /var/www/cenit

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

ENV SKIP_DB_INITIALIZATION=false
ENV SKIP_RABBIT_MQ=true

RUN bundle install --jobs 20 --retry 5 --without development test

CMD ["bundle", "exec", "unicorn", "-c", "config/unicorn.rb"]

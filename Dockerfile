FROM ruby:2.5.5

# Install dependencies:
#   - build-essential: To ensure certain gems can be compiled
#   - nodejs: Compile assets
RUN set -x; \
  apt-get update \
  && apt-get install -y --no-install-recommends \
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
  git \
  imagemagick \
  libmagickwand-dev

# Set an environment variable where the Rails app is installed to inside of Docker image
ENV RAILS_ROOT /var/www/cenit
RUN mkdir -p $RAILS_ROOT

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

# Set working directory
WORKDIR $RAILS_ROOT

# Setting env up
ENV RAILS_ENV='production'
ENV RACK_ENV='production'

# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN bundle install --jobs 20 --retry 5 --without development test

# Adding project files
COPY . .

RUN set -x; \
  SKIP_MONGO_CLIENT='true' bundle exec rake assets:precompile

EXPOSE 8080

CMD bundle exec unicorn -c config/unicorn.rb

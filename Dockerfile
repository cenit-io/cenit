FROM ruby:2.5.5

# Install dependencies:
#   - build-essential: To ensure certain gems can be compiled
#   - nodejs: Compile assets
RUN set -x; \
  apt update \
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
  git \
  imagemagick \
  libmagickwand-dev

# Set an environment variable where the Rails app is installed to inside of Docker image
ENV DIR_ROOT /var/www
ENV RAILS_ROOT $DIR_ROOT/cenit
RUN mkdir -p $RAILS_ROOT

RUN mkdir -p $DIR_ROOT/shared/log
RUN mkdir -p $DIR_ROOT/shared/pids
RUN mkdir -p $DIR_ROOT/shared/sockets

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

ENV SKIP_MONGO_CLIENT='true'

RUN set -x; \
   bundle exec rake assets:precompile

EXPOSE 8080

CMD ["bundle", "exec", "unicorn", "-c", "config/unicorn.rb"]

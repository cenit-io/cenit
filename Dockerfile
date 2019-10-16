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
  libmagickwand-dev \
  nginx

# Set an environment variable where the Rails app is installed to inside of Docker image

RUN git clone https://github.com/cenit-io/cenit.git /var/www/cenit
ENV RAILS_ROOT /var/www/cenit

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

# Set working directory
WORKDIR $RAILS_ROOT

RUN git checkout docker-branch

# Setting env up
ENV RAILS_ENV='production'
ENV RACK_ENV='production'

RUN bundle install --jobs 20 --retry 5 --without development test

RUN gem install foreman

ENV SKIP_MONGO_CLIENT='true'
COPY config/mongoid.yml config/mongoid.yml

RUN set -x; \
   bundle exec rake assets:precompile

RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf
RUN chown -R www-data:www-data /var/lib/nginx

RUN cp server_config/cenit.conf /etc/nginx/sites-enabled/cenit.conf
RUN rm /etc/nginx/sites-enabled/default

EXPOSE 80 3000

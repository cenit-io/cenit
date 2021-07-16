FROM drecom/centos-base:7 AS rubybuild
RUN git clone git://github.com/rbenv/ruby-build.git /usr/local/plugins/ruby-build \
&&  /usr/local/plugins/ruby-build/install.sh
RUN yum -y install jemalloc-devel
RUN RUBY_CONFIGURE_OPTS=--with-jemalloc ruby-build 2.5.5 /usr/local/

#------------------------------------------------------------------------
#------------------------------------------------------------------------

FROM newrelic/infrastructure:latest-centos

ENV PATH /usr/local/bin:$PATH
RUN yum -y install \
        epel-release 
RUN yum update -y; \
	curl -sL https://rpm.nodesource.com/setup_14.x | bash -; \
	yum -y install \
	jemalloc-devel \
	make \
	gcc-c++ \
	gcc \
	git \
	openssl-devel \
	zlib-devel \
	mysql-devel \
	redis \
	sqlite-devel \
	bzip2 \
	nodejs \
	ImageMagick \
	ImageMagick-devel

COPY --from=rubybuild /usr/local /usr/local

RUN gem update --system

RUN git clone --single-branch --branch master https://github.com/cenit-io/cenit.git /var/www/cenit

WORKDIR /var/www/cenit

RUN mkdir -p /var/www/shared/log
RUN mkdir -p /var/www/shared/pids
RUN mkdir -p /var/www/shared/sockets

ENV RAILS_ENV='production'
ENV RACK_ENV='production'
ENV UNICORN_CENIT_SERVER=true

RUN gem install bundler:1.17.3

RUN bundle install --jobs 20 --retry 5 --without development test

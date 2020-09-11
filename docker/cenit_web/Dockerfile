FROM cenit:latest

ENV SKIP_DB_INITIALIZATION=true
ENV ENABLE_RERECAPTCHA=false
ENV SKIP_RABBIT_MQ=true
ENV MAXIMUM_UNICORN_CONSUMERS=0

RUN set -x; \
   bundle exec rake assets:precompile

EXPOSE 8080

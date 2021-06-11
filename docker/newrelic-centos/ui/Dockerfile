ARG COMMIT_VERSION
FROM cenitgroup/backend:newrelic-centos-${COMMIT_VERSION}

ENV SKIP_DB_INITIALIZATION=true
ENV SKIP_RABBIT_MQ=true

RUN set -x; \
   bundle exec rake assets:precompile

EXPOSE 8080
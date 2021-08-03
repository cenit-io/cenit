ARG COMMIT
ARG IMAGE=ubuntu
FROM cenitio/backend:${IMAGE}-${COMMIT}

ENV SKIP_DB_INITIALIZATION=true
ENV SKIP_RABBIT_MQ=true

RUN set -x; \
   bundle exec rake assets:precompile

EXPOSE 8080

FROM alpine:3.21

LABEL org.opencontainers.image.source=https://github.com/NVFB/model-syncer
LABEL org.opencontainers.image.description="Model syncer"
LABEL org.opencontainers.image.licenses=Apache-2.0

# bash: required by cronsync.sh shebang and set -o pipefail
# rsync: sync engine
# util-linux: provides flock compatible with fd usage (flock -n 200)
# dcron: provides crond and crontab directory support (/etc/crontabs)
RUN apk add --no-cache bash rsync util-linux dcron ca-certificates tzdata tini

WORKDIR /app

COPY cronsync.sh /usr/local/bin/cronsync.sh
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /usr/local/bin/cronsync.sh /docker-entrypoint.sh \
  && mkdir -p /etc/crontabs

ENV SRC=/scratch/models/
ENV DST=/raid/models/

ENTRYPOINT ["/docker-entrypoint.sh"]

# Run cron in foreground by default (entrypoint will exec crond)
CMD []

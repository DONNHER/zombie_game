FROM heroiclabs/nakama:3.37.0

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
LABEL org.opencontainers.image.revision=${APP_VERSION}

COPY nakama/data/local.yml /nakama/data/local.yml
COPY nakama/data/modules/index.js /nakama/data/modules/index.js
COPY deploy/start-nakama.sh /usr/local/bin/start-ranger-nakama

ENTRYPOINT ["/bin/sh", "/usr/local/bin/start-ranger-nakama"]

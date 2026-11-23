#!/bin/sh
set -eu

database="postgres:${POSTGRES_PASSWORD}@postgres:5432/nakama"
/nakama/nakama migrate up --database.address "$database"

exec /nakama/nakama --config /nakama/data/local.yml \
  --database.address "$database" \
  --socket.server_key "$NAKAMA_SERVER_KEY" \
  --console.password "$NAKAMA_CONSOLE_PASSWORD" \
  --console.signing_key "$NAKAMA_CONSOLE_SIGNING_KEY" \
  --session.encryption_key "$NAKAMA_SESSION_KEY" \
  --session.refresh_encryption_key "$NAKAMA_REFRESH_KEY" \
  --runtime.http_key "$NAKAMA_HTTP_KEY" \
  --runtime.env "APP_VERSION=$APP_VERSION"

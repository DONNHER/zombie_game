#!/usr/bin/env bash
set -euo pipefail

command=${1:-}
release=${2:-}
env_file=${RANGER_SERVER_ENV:-"$HOME/.config/ranger-outbreak/server.env"}
project=${RANGER_COMPOSE_PROJECT:-ranger-outbreak-server}
deploy_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $command == init ]]; then
  umask 077
  mkdir -p -- "$(dirname -- "$env_file")"
  if [[ -e $env_file ]]; then
    printf 'Keeping existing server environment at %s\n' "$env_file"
    exit 0
  fi
  {
    printf 'NAKAMA_SERVER_KEY=%s\n' "${RANGER_CLIENT_KEY:-defaultkey}"
    for variable in POSTGRES_PASSWORD NAKAMA_CONSOLE_PASSWORD NAKAMA_CONSOLE_SIGNING_KEY NAKAMA_SESSION_KEY NAKAMA_REFRESH_KEY NAKAMA_HTTP_KEY; do
      secret=$(openssl rand -hex 32)
      printf '%s=%s\n' "$variable" "$secret"
    done
  } > "$env_file"
  printf 'Created server environment at %s\n' "$env_file"
  exit 0
fi

if [[ ! $release =~ ^([0-9a-f]{40}|[a-zA-Z0-9][a-zA-Z0-9.-]{0,31})$ || ! -f $env_file ]]; then
  printf 'Run %s init, then use deploy, verify, rollback or down with a release tag.\n' "$0" >&2
  exit 2
fi

export APP_VERSION=$release
compose=(docker compose --env-file "$env_file" -f "$deploy_dir/compose.yaml" -p "$project")

verify() {
  local container mapping host port base http_key response
  container=$("${compose[@]}" ps -q nakama)
  http_key=$(docker exec "$container" printenv NAKAMA_HTTP_KEY)
  mapping=$("${compose[@]}" port nakama 7350)
  host=${mapping%:*}
  port=${mapping##*:}
  [[ $host != 0.0.0.0 ]] || host=127.0.0.1
  base="http://$host:$port"
  curl --fail --silent --show-error --max-time 5 "$base/healthcheck" > /dev/null
  response=$(curl --fail --silent --show-error --max-time 5 --get \
    --data-urlencode "http_key=$http_key" --data 'unwrap=true' "$base/v2/rpc/deployment_status")
  if [[ $response != "{\"status\":\"ok\",\"version\":\"$release\"}" ]]; then
    printf 'Unexpected release response: %s\n' "$response" >&2
    return 1
  fi
  printf '%s\n' "$response"
}

case $command in
  deploy)
    "${compose[@]}" up -d --build --wait --wait-timeout 120
    verify
    ;;
  verify)
    verify
    ;;
  rollback)
    docker image inspect "ranger-outbreak-nakama:$release" >/dev/null
    "${compose[@]}" up -d --no-build --wait --wait-timeout 120
    verify
    ;;
  down)
    "${compose[@]}" down
    ;;
  *)
    printf 'Unknown command: %s\n' "$command" >&2
    exit 2
    ;;
esac

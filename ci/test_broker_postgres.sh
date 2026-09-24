#!/usr/bin/env bash
# The broker's store against a real Postgres (T-697, D-121). Starts a
# throwaway server whose TLS certificate comes from a test CA made here, runs
# the tests tagged `postgres`, and removes the server again. Needs docker and
# openssl. CLIDE_TEST_POSTGRES_REQUIRED makes a missing server a failure, not
# a skip, so this run cannot pass by testing nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${CLIDE_TEST_POSTGRES_IMAGE:-postgres:16-alpine@sha256:3c5c8892d184f738f4fe282d14ddaa613a38f00f4189d2d94725ebe6f2909ddb}"
work="$(mktemp -d "${TMPDIR:-/tmp}/clide-broker-pg.XXXXXX")"
name="clide-broker-pg-$$"
cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

# A CA, and a server certificate it signs for the name localhost only, so a
# connection to 127.0.0.1 fails host verification and one to localhost passes.
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=clide broker test CA' \
  -keyout "$work/ca.key" -out "$work/ca.crt" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' -keyout "$work/server.key" -out "$work/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:localhost\n' >"$work/san.ext"
openssl x509 -req -in "$work/server.csr" -CA "$work/ca.crt" -CAkey "$work/ca.key" -CAcreateserial -days 1 \
  -extfile "$work/san.ext" -out "$work/server.crt" 2>/dev/null
chmod 644 "$work/server.key" # read once by the container's root, then copied to 0600

password="$(openssl rand -hex 24)"
echo "==> postgres ($IMAGE) with TLS"
# Postgres wants its key owned by its own user and private, which a bind
# mount cannot give; the entrypoint copies it first.
docker run -d --name "$name" -e POSTGRES_PASSWORD="$password" -p 127.0.0.1::5432 -v "$work:/certs:ro" \
  --entrypoint sh "$IMAGE" -c '
    cp /certs/server.crt /certs/server.key /tmp/ &&
    chown postgres /tmp/server.crt /tmp/server.key && chmod 600 /tmp/server.key &&
    exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tmp/server.crt -c ssl_key_file=/tmp/server.key' >/dev/null
port="$(docker port "$name" 5432/tcp | head -1 | cut -d: -f2)"

ready=0
for _ in $(seq 1 60); do
  if docker exec "$name" pg_isready -U postgres -h 127.0.0.1 >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "==> postgres did not become ready" >&2
  docker logs "$name" >&2 || true
  exit 1
fi

echo "==> broker store tests against postgres on port $port"
CLIDE_TEST_POSTGRES_PORT="$port" \
  CLIDE_TEST_POSTGRES_PASSWORD="$password" \
  CLIDE_TEST_POSTGRES_CA="$work/ca.crt" \
  CLIDE_TEST_POSTGRES_REQUIRED=1 \
  dart test -r "${TEST_REPORTER:-expanded}" --tags postgres --timeout 120s test/broker

# syntax=docker/dockerfile:1
#
# The web UI's container (D-117). Caddy serves clide's WebAssembly build over
# TLS, with the cross-origin-isolation headers Skwasm needs. The broker signs
# browsers in and answers Caddy's check on every other request (D-118, T-664);
# it runs under tini and supervises Caddy (D-120). This is a dev container.
# The release image, its signing and its scans are Epic F.
#
#   make ui-container          # build, issue a token, serve https://localhost:8443/
#   make ui-container-stop
#
# The store and the sign-in settings come from the environment the container
# runs with, never from the image (D-121).
#
# Every download is pinned: the base image by digest; the Flutter SDK (the
# version .fvmrc names) and Go by SHA-256; Caddy by commit (D-61).

ARG BASE=debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

# ---- the web bundle, built with the SDK .fvmrc pins --------------------------
FROM ${BASE} AS web
ARG FLUTTER_VERSION=3.44.1
ARG FLUTTER_SHA256=287937458126a53284ed112c8c7dbc647bea2d09ab65d46e2d5cf94e901aac69
ARG COMMIT=unknown
ARG DATE=unknown
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils unzip make brotli \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --strict \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz
ENV PATH=/opt/flutter/bin:$PATH
RUN git config --global --add safe.directory /opt/flutter \
 && flutter --disable-analytics \
 && flutter precache --web
WORKDIR /src
COPY . .
# --no-web-resources-cdn: the renderer is served from the bundle, never from
# a CDN (D-60, T-660).
RUN flutter pub get \
 && make gen-build-info COMMIT="${COMMIT}" DATE="${DATE}" \
 && flutter build web --wasm --no-web-resources-cdn
# Caddy serves these .br/.gz siblings instead of compressing per request.
RUN find build/web -type f \( -name '*.wasm' -o -name '*.mjs' -o -name '*.js' -o -name '*.json' \
      -o -name '*.html' -o -name '*.css' -o -name '*.svg' -o -name '*.ttf' -o -name '*.otf' \) \
      -exec gzip -9 -k {} \; -exec brotli -q 11 -k {} \;
# The broker (D-117), and the stub that stands in for the workspace host until
# the real one exists (C4): Flutter-free, each one native executable.
RUN mkdir -p /out \
 && dart compile exe bin/clide_broker.dart -o /out/clide_broker \
 && dart compile exe bin/clide_stub_host.dart -o /out/clide_stub_host

# ---- Caddy, built from a pinned commit ---------------------------------------
FROM ${BASE} AS caddy
ARG GO_VERSION=1.25.14
ARG GO_SHA256=a21ae5633a269bcd7e90cf767e48225633795e99d831742cbf3397064fee7712
ARG CADDY_TAG=v2.11.4
ARG CADDY_COMMIT=e2eee6a7fce366321294c9c2a79f3146891dcbdf
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
 && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum --check --strict \
 && tar -xzf /tmp/go.tar.gz -C /usr/local \
 && rm /tmp/go.tar.gz
ENV PATH=/usr/local/go/bin:$PATH CGO_ENABLED=0 GOTOOLCHAIN=local
RUN git clone --quiet --depth 1 --branch "${CADDY_TAG}" https://github.com/caddyserver/caddy.git /src/caddy \
 && test "$(git -C /src/caddy rev-parse HEAD)" = "${CADDY_COMMIT}"
# go.sum pins every module, and -mod=readonly refuses to change it.
RUN cd /src/caddy/cmd/caddy && go build -trimpath -mod=readonly -ldflags '-s -w' -o /out/caddy .

# ---- the edge and the broker --------------------------------------------------
FROM ${BASE}
# tini is PID 1: it forwards signals to the broker and reaps the processes its
# children leave behind (D-120). The broker binds the system SQLite (D-121),
# and checks the TLS of a Postgres store or an identity provider against the
# CA certificates.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini libsqlite3-0 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=caddy /out/caddy /usr/local/bin/caddy
COPY --from=web /out/clide_broker /usr/local/bin/clide_broker
COPY --from=web /out/clide_stub_host /usr/local/bin/clide_stub_host
COPY --from=web /src/build/web /srv/web
COPY docker/web/Caddyfile /etc/caddy/Caddyfile
# Everything the container writes goes to the state volume, which any UID
# can write: an install runs the container as its own Linux account (D-119).
RUN mkdir -p /clide/state && chmod 1777 /clide/state
VOLUME /clide/state
# Caddy keeps its internal CA and its certificates in the state volume, so a
# browser that trusts the CA keeps trusting it across upgrades.
ENV XDG_DATA_HOME=/clide/state/caddy/data XDG_CONFIG_HOME=/clide/state/caddy/config
USER 10001
EXPOSE 8443
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/clide_broker"]
# Each user's workspaces are the folders mounted at /clide/users/<N>/projects
# (D-119). A session starts that workspace's host.
CMD ["serve", "--socket", "/clide/state/run/broker.sock", "--caddy", "/usr/local/bin/caddy", "--caddy-config", "/etc/caddy/Caddyfile", \
     "--users", "/clide/users", "--host", "/usr/local/bin/clide_stub_host"]

# syntax=docker/dockerfile:1
#
# The web UI's walking skeleton (T-663, D-117): Caddy serving clide's
# WebAssembly build over TLS, with the cross-origin-isolation headers Skwasm
# needs. This is a dev container. The release image, its signing and its
# scans are Epic F.
#
#   make ui-container          # build, then serve https://localhost:8443/u/0/w/<slug>/
#   make ui-container-stop
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

# ---- the edge ----------------------------------------------------------------
FROM ${BASE}
RUN useradd --system --uid 10001 --create-home --home-dir /var/lib/caddy caddy
COPY --from=caddy /out/caddy /usr/local/bin/caddy
COPY --from=web /src/build/web /srv/web
COPY docker/web/Caddyfile /etc/caddy/Caddyfile
USER caddy
# Caddy keeps its internal CA and its certificates here.
ENV XDG_DATA_HOME=/var/lib/caddy/data XDG_CONFIG_HOME=/var/lib/caddy/config
EXPOSE 8443
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

FROM ubuntu:jammy

LABEL org.opencontainers.image.source https://github.com/garvbox/factorio-server
LABEL org.opencontainers.image.description Factorio Headless Server

# version and checksum of the archive to download
ARG FACTORIO_VERSION
ARG FACTORIO_SHA256

ARG PUID=845
ARG PGID=845
ARG BASE_DIR=/factorio
ARG DOWNLOAD_RETRIES=8
ARG DEBIAN_FRONTEND=noninteractive

ENV USER=factorio \
    GROUP=factorio \
    SERVER_PORT=34197 \
    RCON_PORT=27015

# Factorio Binary downloader
RUN /bin/bash -c 'set -ox pipefail \
    && test -n "$FACTORIO_VERSION" || (echo "build-arg VERSION is required" && exit 1) \
    && test -n "$FACTORIO_SHA256" || (echo "build-arg SHA256 is required" && exit) \
    && archive="/tmp/factorio_headless_x64_$FACTORIO_VERSION.tar.xz" \
    && apt-get update && apt-get install -y curl coreutils file xz-utils pwgen && rm -rf /var/lib/apt/lists/* \
    && curl -sSL "https://www.factorio.com/get-download/$FACTORIO_VERSION/headless/linux64" -o "$archive" --retry $DOWNLOAD_RETRIES\
    && echo "$FACTORIO_SHA256  $archive" | sha256sum -c || (sha256sum "$archive" && file "$archive" && exit 1) \
    && mkdir -p /opt/factorio /factorio \
    && tar xf "$archive" --directory /opt \
    && rm "$archive" \
    && addgroup --system --gid "$PGID" "$GROUP" \
    && adduser --system --uid "$PUID" --gid "$PGID" --shell /bin/sh "$USER" \
    && chown -R "$USER":"$GROUP" /opt/factorio/ /factorio'

COPY --chown=${PUID}:${PGID} files/config-path.cfg /opt/factorio/
COPY --chmod=755 --chown=${PUID}:${PGID} scripts/*.sh /

VOLUME /factorio
EXPOSE $SERVER_PORT/udp $RCON_PORT/tcp
USER factorio
ENTRYPOINT ["/docker-entrypoint.sh"]

FROM ghcr.io/sv-tools/roas:1.1.0 AS src

FROM debian:trixie-slim
# Don't pin ca-certificates: we want the latest CA bundle for TLS roots,
# and Debian's revision-suffixed versions are GC'd from mirrors over time.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=src /usr/local/bin/roas /usr/local/bin/roas
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

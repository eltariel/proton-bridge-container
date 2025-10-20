# ---- Builder image
FROM golang:alpine AS builder

ARG BRIDGE_REPO=https://github.com/ProtonMail/proton-bridge.git
ARG BRIDGE_VERSION

RUN apk update && \
    apk upgrade && \
    apk add git make bash gcc musl-dev libsecret-dev

WORKDIR /build/
RUN git clone -b "$BRIDGE_VERSION" "$BRIDGE_REPO" repo && \
    cd repo && \
    make build-nogui vault-editor


# --- Runtime image
FROM alpine:latest
LABEL authors="Ellie Tomkins"
LABEL org.opencontainers.image.source="https://github.com/eltariel/proton-bridge-container"

ARG ENV_SMTP_PORT=1025
ARG ENV_IMAP_PORT=1143
ENV SMTP_PORT=$ENV_SMTP_PORT
ENV IMAP_PORT=$ENV_IMAP_PORT

EXPOSE ${ENV_SMTP_PORT}/tcp
EXPOSE ${ENV_IMAP_PORT}/tcp

# Add user to run the bridge
RUN addgroup \
      -S \
      -g 1000 \
      protonbridge && \
    adduser \
      -S \
      -G protonbridge \
      -h /data \
      -D \
      -u 1000 \
      protonbridge

# Install dependencies
RUN apk update && \
    apk upgrade && \
    apk add pass gpg-agent socat libsecret

WORKDIR /usr/bin/
COPY --from=builder /build/repo/bridge /usr/bin/
COPY --from=builder /build/repo/proton-bridge /usr/bin/
COPY --from=builder /build/repo/vault-editor /usr/bin/

WORKDIR /app/
COPY entrypoint.sh /app/
RUN chown -R protonbridge:protonbridge /app && \
    chmod u+x /app/entrypoint.sh

USER protonbridge:protonbridge

# Persistance for bridge and pass configuration
VOLUME /data/bridge
VOLUME /data/security

ENTRYPOINT ["/app/entrypoint.sh"]

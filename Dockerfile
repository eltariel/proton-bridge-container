# ---- Builder image
FROM golang:alpine AS builder

ARG BRIDGE_REPO=https://github.com/ProtonMail/proton-bridge.git
ARG BRIDGE_VERSION

RUN apk update && \
    apk upgrade && \
    apk add git make bash gcc musl-dev libsecret-dev

ADD --keep-git-dir "${BRIDGE_REPO}#${BRIDGE_VERSION}" /build/
WORKDIR /build/
RUN make build-nogui vault-editor


# --- Runtime image
FROM alpine:latest
ARG BRIDGE_VERSION
ARG ENV_SMTP_PORT=8025
ARG ENV_IMAP_PORT=8143
ENV SMTP_PORT=$ENV_SMTP_PORT
ENV IMAP_PORT=$ENV_IMAP_PORT

LABEL \
  name="Proton Bridge Container" \
  authors="Ellie Tomkins"

EXPOSE ${ENV_SMTP_PORT}/tcp
EXPOSE ${ENV_IMAP_PORT}/tcp

# Add user to run the bridge
RUN addgroup -g 1000 protonbridge && \
    adduser -D -G protonbridge -h /data -u 1000 protonbridge

# Install dependencies
RUN apk update && \
    apk upgrade && \
    apk add pass gpg-agent socat libsecret

WORKDIR /usr/bin/
COPY --from=builder /build/bridge /usr/bin/
COPY --from=builder /build/proton-bridge /usr/bin/
COPY --from=builder /build/vault-editor /usr/bin/

WORKDIR /app/
COPY entrypoint.sh /app/
RUN chown -R protonbridge:protonbridge /app && \
    chmod u+x /app/entrypoint.sh

USER protonbridge:protonbridge

# Persistance for bridge and pass configuration
VOLUME /data/bridge
VOLUME /data/security

ENTRYPOINT ["/app/entrypoint.sh"]

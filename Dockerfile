FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

ENV GIT_CLONE_MODE=https

RUN apk --no-cache add aws-cli bash coreutils curl git github-cli jq openssh-client-default && \
    adduser -D -u 1000 backupper && \
    mkdir -p /app/backups && \
    chown backupper:backupper /app/backups

# Pinned GitHub host keys instead of trusting whatever ssh-keyscan returns at build time
COPY ssh_known_hosts /etc/ssh/ssh_known_hosts

WORKDIR /app

COPY *.sh ./

USER backupper

ENTRYPOINT ["/app/backup.sh"]

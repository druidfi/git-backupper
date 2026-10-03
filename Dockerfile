FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

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

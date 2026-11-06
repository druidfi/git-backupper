FROM alpine:3.24@sha256:3f4d6b32e26703c6082839234f43769d5046b3ac7c910033911d1e71d8cd630a

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

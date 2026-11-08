FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

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

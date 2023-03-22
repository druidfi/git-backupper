FROM alpine

ENV GIT_CLONE_MODE=https

RUN apk --no-cache add bash coreutils jq openssh && \
    apk -X https://dl-cdn.alpinelinux.org/alpine/edge/community --no-cache add aws-cli github-cli && \
    mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

WORKDIR /app

COPY . .

ENTRYPOINT ["/app/backup.sh"]

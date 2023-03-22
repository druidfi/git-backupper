#!/bin/bash

set -eu

source utils.sh

SCOPE_EXT="*.tar.gz"
DATA_PATH="backups/${SCOPE_EXT}"
S3_PATH="s3://${S3_BUCKET}/"
S3_REGION=${S3_REGION:-"eu-central-1"}

# Delete possible empty files before sync
find backups -type f -empty -delete

if ! test -n "$(find ./backups -maxdepth 1 -name "${SCOPE_EXT}" -print -quit)"
then

    info "There are no backups to sync to S3, skipping."
    exit 0

fi

SYNC="aws s3 sync backups ${S3_PATH} --region ${S3_REGION}"

# Sync backups to S3
if aws s3 sync backups ${S3_PATH} --region ${S3_REGION} --no-progress;
then

  rm -f backups/*
  success "Backups were successfully synced to S3"

else

  error "ERROR syncing backups to S3"

fi

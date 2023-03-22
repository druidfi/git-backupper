#!/bin/bash

DEBUG=${DEBUG:-0}

# The function `run` will exit the script if the given command fails.
run () {
  "$@"
  status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: Encountered error (${status}) while running the following:" >&2
    echo "           $@"  >&2
    echo "       (at line ${BASH_LINENO[0]} of file $0.)"  >&2
    echo "       Aborting." >&2
    exit $status
  fi
}

debug () {
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "🔹 $NOW [DEBUG] $1"
}

info () {
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "🔸 $NOW [INFO] $1"
}

warning () {
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "🔸 $NOW [WARNING] $1"
}

success () {
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "👍 $NOW [SUCCESS] $1"
  slack "$1" ":white_check_mark:"
}

error () {
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "🔺 $NOW [ERROR] $1"
  slack "$1" ":warning:"
}

slack () {
  # Slack hook is added as ENV variable
  SLACK_HOOK="${SLACK_HOOK:-""}"

  if [ "$DEBUG" == "1" ]
  then

    debug "Not flooding Slack in debug mode: $1"
    exit 0

  elif [ -z "${SLACK_HOOK}" ]
  then

    info "No Slack webhook supplied. You need to give Slack webhook as an ENV variable SLACK_HOOK."
    exit 0

  fi

  TEXT=$1
  EMOJI=$2
  MSG="$EMOJI $TEXT"
  DATA="$(printf '{"text": "%s"}' "${MSG}" )"

  curl -s -o /dev/null -X POST -H 'Content-type: application/json' --data "$DATA" "$SLACK_HOOK"
}

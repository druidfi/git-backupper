#!/bin/bash

DEBUG=${DEBUG:-0}

# The function `run` will exit the script if the given command fails.
# The command itself is not printed, as it may contain repository names.
run () {
  local status=0
  "$@" || status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: Encountered error (${status}) at line ${BASH_LINENO[0]} of file $0. Aborting." >&2
    exit $status
  fi
}

# The function `quiet` runs a command and shows its stderr only if it fails.
quiet () {
  local status=0 log
  log=$(mktemp)
  "$@" 2> "$log" || status=$?
  if [ $status -ne 0 ]; then
    sed 's/^/    /' "$log" >&2
  fi
  rm -f "$log"
  return $status
}

# The function `mask` hides the given value from GitHub Actions logs.
mask () {
  if [ "${GITHUB_ACTIONS:-}" == "true" ] && [ -n "$1" ]; then
    echo "::add-mask::$1"
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
    return 0

  elif [ -z "${SLACK_HOOK}" ]
  then

    info "No Slack webhook supplied. You need to give Slack webhook as an ENV variable SLACK_HOOK."
    return 0

  fi

  jq -n --arg text "$2 $1" '{text: $text}' \
    | curl -s -o /dev/null -X POST -H 'Content-type: application/json' --data @- "$SLACK_HOOK" \
    || warning "Could not send Slack notification"
}

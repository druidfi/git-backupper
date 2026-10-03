#!/bin/bash

set -euo pipefail

source utils.sh

GH_OWNER=${GH_OWNER:-"octocat"}
GH_LIST_LIMIT=${GH_LIST_LIMIT:-1000}
GIT_CLONE_MODE=${GIT_CLONE_MODE:-"https"}
SKIP_FORKS=${SKIP_FORKS:-false}
SKIP_ARCHIVED=${SKIP_ARCHIVED:-false}
SKIP_ISSUES=${SKIP_ISSUES:-false}
SKIP_ISSUE_COMMENTS=${SKIP_ISSUE_COMMENTS:-false}

# Never wait for interactive credential prompts
export GIT_TERMINAL_PROMPT=0

trap 'error "Backup aborted unexpectedly at line ${LINENO}."' ERR

GH_LIST_FLAGS=()
if [ "${SKIP_FORKS}" == "true" ] ; then GH_LIST_FLAGS+=(--source) ; fi
if [ "${SKIP_ARCHIVED}" == "true" ] ; then GH_LIST_FLAGS+=(--no-archived) ; fi

# Mirror clone with plain git. `gh repo clone` would also add and fetch an
# `upstream` remote for forks, which bloats the backup and logs the parent repo.
# For https, gh is used as the credential helper so GH_TOKEN/GITHUB_TOKEN is used.
function git_mirror {
  if [ "${GIT_CLONE_MODE}" == "https" ] ; then
    git -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
      clone --quiet --mirror "https://github.com/$1.git" "$2"
  else
    git clone --quiet --mirror "git@github.com:$1.git" "$2"
  fi
}

# Dump a paginated GitHub API list ($1) into a JSON file ($2), remove it if empty
function dump_json {
  quiet gh api --paginate "$1" > "$2" || return 1
  local count
  count=$(jq 'length' "$2") || return 1
  if [ "${count}" -eq 0 ] ; then rm "$2" ; else info "- found ${count} items" ; fi
}

# Back up one repository ($1 = name, $2 = owner/name) into backups/<name>.tar.gz.
# Called in a condition, so `set -e` is not active here: every step must check its own status.
function backup_repo {
  local dir="backups/$1"

  rm -rf "${dir}" "${dir}.tar.gz"
  mkdir -p "${dir}" || return 1

  info "- Cloning repository..."
  quiet git_mirror "$2" "${dir}/repository" || return 1

  if [ "${SKIP_ISSUES}" != "true" ] ; then
    info "- Download issues as JSON..."
    dump_json "repos/$2/issues?state=all&per_page=100" "${dir}/issues.json" || return 1
  fi

  if [ "${SKIP_ISSUE_COMMENTS}" != "true" ] ; then
    info "- Download issue comments as JSON..."
    dump_json "repos/$2/issues/comments?per_page=100" "${dir}/issue-comments.json" || return 1
  fi

  info "- Cloning wiki..."
  git_mirror "$2.wiki" "${dir}/wiki" 2>/dev/null || info "- No wiki found..."

  info "- Create archive..."
  tar zcf "${dir}.tar.gz" "${dir}/" && rm -rf "${dir}"
}

REPOS=$(run gh repo list "${GH_OWNER}" --json name,nameWithOwner --limit "${GH_LIST_LIMIT}" ${GH_LIST_FLAGS[@]+"${GH_LIST_FLAGS[@]}"})
TOTAL=$(echo "${REPOS}" | jq 'length')

# Hide all repository names from the (public) workflow logs before doing anything else
while IFS=$'\t' read -r NAME NAME_WITH_OWNER ; do
  mask "${NAME}"
  mask "${NAME_WITH_OWNER}"
done < <(echo "${REPOS}" | jq -r '.[] | [.name, .nameWithOwner] | @tsv')

if [ "${TOTAL}" -ge "${GH_LIST_LIMIT}" ] ; then
  warning "Found ${TOTAL} repositories, which is the GH_LIST_LIMIT. Some repositories may be left out, increase GH_LIST_LIMIT."
fi

FAILED=0
INDEX=0

# Read the list from fd 3 so that commands in the loop can't consume it from stdin
while IFS=$'\t' read -r NAME NAME_WITH_OWNER <&3 ; do
  INDEX=$((INDEX + 1))
  info "Backup repository ${INDEX}/${TOTAL}"

  if ! backup_repo "${NAME}" "${NAME_WITH_OWNER}" ; then
    FAILED=$((FAILED + 1))
    warning "- Backup of repository ${INDEX}/${TOTAL} failed"
    rm -rf "backups/${NAME}" "backups/${NAME}.tar.gz"
  fi
done 3< <(echo "${REPOS}" | jq -r '.[] | [.name, .nameWithOwner] | @tsv')

if [ "${FAILED}" -gt 0 ] ; then
  error "Backup of ${FAILED}/${TOTAL} repositories failed."
  exit 1
fi

success "Success! All ${TOTAL} repositories backed up."

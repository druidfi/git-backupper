#!/bin/bash

GH_OWNER=${GH_OWNER-"octocat"}
GH_LIST_LIMIT=${GH_LIST_LIMIT-100}
GIT_CLONE_FLAGS="--quiet --mirror"

# The function `run` will exit the script if the given command fails.
function run {
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

# The function `tgz` will create a gzipped tar archive of the specified file ($1) and then remove the original
function tgz {
   run tar zcf $1.tar.gz $1 && run rm -rf $1
}

REPOS=`run gh repo list ${GH_OWNER} --json name,nameWithOwner,sshUrl --limit ${GH_LIST_LIMIT}`

for row in $(echo "${REPOS}" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    REPO=git@github.com:$(_jq '.nameWithOwner').git
    WIKI_REPO=git@github.com:$(_jq '.nameWithOwner').wiki.git

    echo Cloning $(_jq '.nameWithOwner')...
    #run gh repo clone ${REPO} backups/$(_jq '.name') -- ${GIT_CLONE_FLAGS} && tgz backups/$(_jq '.name')

    echo Download issues for $(_jq '.nameWithOwner')...
    run gh api repos/$(_jq '.nameWithOwner')/issues > backups/$(_jq '.name')-issues.json

    echo Cloning $(_jq '.nameWithOwner') wiki...
    #gh repo clone ${WIKI_REPO} backups/$(_jq '.name')-wiki -- ${GIT_CLONE_FLAGS} 2>/dev/null && tgz backups/$(_jq '.name')-wiki || echo "No wiki..."

done

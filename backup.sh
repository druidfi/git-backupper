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

# The function `compress` will create a gzipped tar archive of the specified file ($1) and then remove the original
function compress {
   run tar zcf $1.tar.gz $2 && run rm -rf $2
}

REPOS=`run gh repo list ${GH_OWNER} --json name,nameWithOwner,sshUrl --limit ${GH_LIST_LIMIT}`

for row in $(echo "${REPOS}" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    echo "Backup repository $(_jq '.nameWithOwner')"

    REPO=git@github.com:$(_jq '.nameWithOwner').git
    WIKI_REPO=git@github.com:$(_jq '.nameWithOwner').wiki.git
    BACKUP_DIR=backups/$(_jq '.name')
    ISSUE_JSON=backups/$(_jq '.name')/issues.json

    mkdir -p ${BACKUP_DIR}

    echo "- Cloning repository..."
    run gh repo clone ${REPO} ${BACKUP_DIR}/repository -- ${GIT_CLONE_FLAGS}

    echo "- Download issues as JSON..."
    run gh api repos/$(_jq '.nameWithOwner')/issues --paginate | jq . > ${ISSUE_JSON}
    ISSUE_COUNT=$(jq '. | length' ${ISSUE_JSON})
    if [ ${ISSUE_COUNT} -eq 0 ] ; then rm ${ISSUE_JSON} ; else echo "- found ${ISSUE_COUNT} issues" ; fi

    echo "- Cloning wiki..."
    gh repo clone ${WIKI_REPO} backups/$(_jq '.name')/wiki -- ${GIT_CLONE_FLAGS} 2>/dev/null || echo "- No wiki found..."

    echo "- Create archive..."
    run compress backups/$(_jq '.name') ${BACKUP_DIR}/

done

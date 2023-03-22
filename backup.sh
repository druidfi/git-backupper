#!/bin/bash

set -eu

source utils.sh

GH_CLI_TOKEN=${GH_CLI_TOKEN-""}
GH_OWNER=${GH_OWNER-"octocat"}
GH_LIST_LIMIT=${GH_LIST_LIMIT-100}
GIT_CLONE_MODE=${GIT_CLONE_MODE-"ssh"}
GIT_CLONE_FLAGS="--quiet --mirror"

# The function `compress` will create a gzipped tar archive of the specified file ($1) and then remove the original
function compress {
   run tar zcf $1.tar.gz $2 && run rm -rf $2
}

REPOS=`run gh repo list ${GH_OWNER} --json name,nameWithOwner,sshUrl --limit ${GH_LIST_LIMIT}`

for row in $(echo "${REPOS}" | jq -r '.[] | @base64'); do
    _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
    }

    info "Backup repository $(_jq '.nameWithOwner')"

    if [ "${GIT_CLONE_MODE}" == "https" ] ; then
      REPO=https://github.com/$(_jq '.nameWithOwner').git
    else
      REPO=git@github.com:$(_jq '.nameWithOwner').git
    fi

    WIKI_REPO=git@github.com:$(_jq '.nameWithOwner').wiki.git
    BACKUP_DIR=backups/$(_jq '.name')
    ISSUE_JSON=backups/$(_jq '.name')/issues.json

    mkdir -p ${BACKUP_DIR}

    info "- Cloning repository (${GIT_CLONE_MODE})..."
    run gh repo clone ${REPO} ${BACKUP_DIR}/repository -- ${GIT_CLONE_FLAGS}

    info "- Download issues as JSON..."
    run gh api repos/$(_jq '.nameWithOwner')/issues --paginate | jq . > ${ISSUE_JSON}
    ISSUE_COUNT=$(jq '. | length' ${ISSUE_JSON})
    if [ ${ISSUE_COUNT} -eq 0 ] ; then rm ${ISSUE_JSON} ; else info "- found ${ISSUE_COUNT} issues" ; fi

    info "- Cloning wiki..."
    gh repo clone ${WIKI_REPO} backups/$(_jq '.name')/wiki -- ${GIT_CLONE_FLAGS} 2>/dev/null || info "- No wiki found..."

    info "- Create archive..."
    compress backups/$(_jq '.name') ${BACKUP_DIR}/

done

success "Success! All repositories backupped."

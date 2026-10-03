#!/bin/bash

set -euo pipefail

source utils.sh

GH_REPO=${GH_REPO-"octocat/git-backupper"}

GITHUB_RUN_ID=${GITHUB_RUN_ID:?GITHUB_RUN_ID must be set, the current run is never deleted}

run gh cache delete --all --succeed-on-no-caches

workflow_ids=$(run gh api "repos/${GH_REPO}/actions/workflows" --jq '.workflows[].id')

for workflow_id in ${workflow_ids}
do
  info "- Listing runs for the workflow ID $workflow_id"
  run_ids=$(run gh api "repos/${GH_REPO}/actions/workflows/${workflow_id}/runs" --paginate --jq '.workflow_runs[].id')
  for run_id in ${run_ids}
  do
    # delete if not the current run
    if [ "${run_id}" -eq "${GITHUB_RUN_ID}" ]
    then
      info "- Skipping current run ID $run_id"
      continue
    fi

    info "- Deleting Run ID $run_id"
    # e.g. runs still in progress can't be deleted, they will be removed next time
    gh api "repos/${GH_REPO}/actions/runs/${run_id}" -X DELETE >/dev/null \
      || warning "- Could not delete run ID $run_id"
  done
done

#!/bin/bash

set -eu

source utils.sh

GH_REPO=${GH_REPO-"octocat/git-backupper"}

run gh cache delete --all

# gh api repos/druidfi/git-backupper/actions/workflows | jq '.workflows[] | .id'
workflow_ids=($(run gh api repos/$GH_REPO/actions/workflows | jq '.workflows[] | .id'))

for workflow_id in "${workflow_ids[@]}"
do
  info "- Listing runs for the workflow ID $workflow_id"
  # # gh api repos/druidfi/git-backupper/actions/workflows/51826721/runs --paginate | jq '.workflow_runs[].id'
  run_ids=( $(run gh api repos/$GH_REPO/actions/workflows/$workflow_id/runs --paginate | jq '.workflow_runs[].id') )
  for run_id in "${run_ids[@]}"
  do
    info "- Deleting Run ID $run_id"
    #gh api repos/$GH_OWNER/$GH_REPO/actions/runs/$run_id -X DELETE >/dev/null
    run gh run delete $run_id
  done
done

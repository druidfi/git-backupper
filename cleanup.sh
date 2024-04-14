#!/bin/bash

set -eu

source utils.sh

GH_OWNER=${GH_OWNER-"octocat"}
GH_REPO=${GH_REPO-"git-backupper"}

gh extension install actions/gh-actions-cache

cacheKeys=$(gh actions-cache list -R $GH_OWNER/$GH_REPO | cut -f 1)

## Setting this to not fail the workflow while deleting cache keys.
set +e

for cacheKey in $cacheKeys
do
    gh actions-cache delete $cacheKey -R $GH_OWNER/$GH_REPO --confirm
done

# gh api repos/druidfi/git-backupper/actions/workflows | jq '.workflows[] | .id'
workflow_ids=($(gh api repos/$GH_OWNER/$GH_REPO/actions/workflows | jq '.workflows[] | .id'))

for workflow_id in "${workflow_ids[@]}"
do
  info "- Listing runs for the workflow ID $workflow_id"
  # # gh api repos/druidfi/git-backupper/actions/workflows/51826721/runs --paginate | jq '.workflow_runs[].id'
  run_ids=( $(gh api repos/$GH_OWNER/$GH_REPO/actions/workflows/$workflow_id/runs --paginate | jq '.workflow_runs[].id') )
  for run_id in "${run_ids[@]}"
  do
    info "- Deleting Run ID $run_id"
    gh api repos/$GH_OWNER/$GH_REPO/actions/runs/$run_id -X DELETE >/dev/null
  done
done

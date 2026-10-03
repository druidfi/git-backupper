# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

Plain Bash scripts that back up every repository of a GitHub organization (mirror clone, wiki, issues as JSON) into `backups/<repo>.tar.gz` and sync the archives to S3 or an S3-compatible store (e.g. UpCloud). No build system, no tests, no linter config. Runtime dependencies: `gh`, `jq`, `aws` CLI.

## Running

Scripts `source utils.sh` with a relative path, so they must be run from the repo root.

```console
GH_OWNER=myorg GH_LIST_LIMIT=5 ./backup.sh          # clone + archive into ./backups
S3_BUCKET=b ENDPOINT_URL= AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… ./s3.sh
DEBUG=1 ./backup.sh                                  # suppress Slack notifications
docker build . --progress plain -t git-backupper    # image entrypoint is backup.sh only
```

For a quick manual check, use a small `GH_LIST_LIMIT`. `shellcheck *.sh` is the practical way to lint.

## Architecture

- `backup.sh` — lists repos via `gh repo list` (optionally `--source`/`--no-archived`), registers every name with `::add-mask::`, then calls `backup_repo` per repo: plain `git clone --mirror` of repo and wiki (gh as credential helper; wiki failure is tolerated), all issues and issue comments via `gh api --paginate` (unless `SKIP_ISSUES`/`SKIP_ISSUE_COMMENTS`), then tars and removes the directory. A failing repo is counted and skipped; the script exits 1 at the end if any failed.
- `s3.sh` — deletes empty files in `backups/`, `aws s3 sync`s `*.tar.gz` to the bucket, then empties `backups/` on success. Forces `AWS_REQUEST_CHECKSUM_CALCULATION`/`AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` because non-AWS endpoints reject newer aws-cli checksums.
- `cleanup.sh` — CI-only: deletes all Actions caches and all workflow runs of `GH_REPO` except the current one (`GITHUB_RUN_ID` must be set).
- `utils.sh` — `run` (abort on failure, prints only exit code and line), `quiet` (show stderr only on failure), `mask` (`::add-mask::` in GitHub Actions), log helpers `info`/`warning`/`debug`, and `success`/`error` which also post to Slack via `SLACK_HOOK`.

### CI flow (`.github/workflows/backup.yml`)

Nightly at 00:00 UTC, two jobs: `backup` (runs `backup.sh` then `s3.sh` — the sync also runs when some repos failed — plus a Slack notice on failure) → `cleanup` (runs even if `backup` failed; deletes caches and old runs). Backup and sync deliberately share one job: this repo is public, so backup data must never be handed between jobs via `actions/cache` or artifacts. The `backup` job only runs when the repo variable `BACKUP_ENABLED` is `true`, so repos created from this template stay inactive until configured. Optional vars: `GH_OWNER`, `GH_LIST_LIMIT` (defaults to 1000 in CI), `SKIP_FORKS`, `SKIP_ARCHIVED`, `SKIP_ISSUES`, `SKIP_ISSUE_COMMENTS` (`true` to skip), `S3_REGION`; secrets: `GH_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, `ENDPOINT_URL`, `SLACK_HOOK`. `build-docker-image.yaml` pushes multi-arch `ghcr.io/druidfi/git-backupper:latest` on changes to `main`.

GitHub Actions are pinned to commit SHAs with a version comment; Renovate keeps them updated. Keep that format when adding or changing actions.

## Gotchas

- This repo is public, so repository names must never appear in workflow logs. Logs show only a counter (`Backup repository 12/82`), names are registered with `mask` before any per-repo work, and `run` never prints its command. Keep it that way, and never use `set -x`.
- `gh repo clone` is deliberately not used: for forks it adds and fetches an `upstream` remote, which bloats the archive and logs the parent repo URL.
- `backup_repo` is called in an `if`, so `set -e` is inactive inside it; every step needs its own `|| return 1`.
- `slack()` returns without posting when `DEBUG=1` or `SLACK_HOOK` is unset. `error` does not exit by itself; callers must `exit 1` after it (as `s3.sh` does).
- `GIT_CLONE_MODE` defaults to `https` in `backup.sh`; the Docker image also sets `https`.

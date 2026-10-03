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

- `backup.sh` — lists repos via `gh repo list`, iterates rows as base64-encoded JSON (`_jq` helper decodes per row), mirror-clones repo and wiki (wiki failure is tolerated), dumps issues with `gh api --paginate`, then tars and removes the directory.
- `s3.sh` — deletes empty files in `backups/`, `aws s3 sync`s `*.tar.gz` to the bucket, then empties `backups/` on success. Forces `AWS_REQUEST_CHECKSUM_CALCULATION`/`AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` because non-AWS endpoints reject newer aws-cli checksums.
- `cleanup.sh` — CI-only: deletes all Actions caches and all workflow runs of `GH_REPO` except the current one (`GITHUB_RUN_ID` must be set).
- `utils.sh` — `run` (abort with diagnostics on failure), log helpers `info`/`warning`/`debug`, and `success`/`error` which also post to Slack via `SLACK_HOOK`.

### CI flow (`.github/workflows/backup.yml`)

Nightly at 00:00 UTC, two jobs: `backup` (runs `backup.sh` then `s3.sh`, plus a Slack notice on failure) → `cleanup` (runs even if `backup` failed; deletes caches and old runs). Backup and sync deliberately share one job: this repo is public, so backup data must never be handed between jobs via `actions/cache` or artifacts. The `backup` job only runs when the repo variable `BACKUP_ENABLED` is `true`, so repos created from this template stay inactive until configured. Optional vars: `GH_OWNER`, `GH_LIST_LIMIT` (defaults to 1000 in CI), `S3_REGION`; secrets: `GH_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, `ENDPOINT_URL`, `SLACK_HOOK`. `build-docker-image.yaml` pushes multi-arch `ghcr.io/druidfi/git-backupper:latest` on changes to `main`.

GitHub Actions are pinned to commit SHAs with a version comment; Renovate keeps them updated. Keep that format when adding or changing actions.

## Gotchas

- Repository names are deliberately masked in logs (`info "Backup repository *******"`) because workflow logs may be visible; don't reintroduce names in output. The `--reveal` flag is parsed but not wired to anything yet.
- `slack()` returns without posting when `DEBUG=1` or `SLACK_HOOK` is unset. `error` does not exit by itself; callers must `exit 1` after it (as `s3.sh` does).
- `s3.sh` runs under `set -u` and references `ENDPOINT_URL` directly, so it must be set (empty is fine) when running against AWS.
- `GIT_CLONE_MODE` defaults to `https` in `backup.sh` (the README table says `ssh`); the Docker image also sets `https`.

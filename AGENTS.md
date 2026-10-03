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

Nightly at 00:00 UTC, three chained jobs: `backup` → `sync` → `cleanup`. The `backups/` directory is handed from `backup` to `sync` through `actions/cache` keyed by `github.run_id` (not artifacts), and `cleanup` then wipes caches and old runs so backup data doesn't linger in GitHub. `build-docker-image.yaml` pushes multi-arch `ghcr.io/druidfi/git-backupper:latest` on changes to `main`.

GitHub Actions are pinned to commit SHAs with a version comment; Renovate keeps them updated. Keep that format when adding or changing actions.

## Gotchas

- Repository names are deliberately masked in logs (`info "Backup repository *******"`) because workflow logs may be visible; don't reintroduce names in output. The `--reveal` flag is parsed but not wired to anything yet.
- `slack()` calls `exit 0` when `DEBUG=1` or `SLACK_HOOK` is unset. Since `success`/`error` call it, they terminate the whole script with status 0 in those cases — including on S3 sync failure.
- `s3.sh` runs under `set -u` and references `ENDPOINT_URL` directly, so it must be set (empty is fine) when running against AWS.
- `GIT_CLONE_MODE` defaults to `https` in `backup.sh` (the README table says `ssh`); the Docker image also sets `https`.

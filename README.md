# Git Backupper

Backup organization's GitHub repositories with Github CLI.

- Clones repository with --mirror mode
- Clones repository wiki if exists
- Gets repository issues as JSON
- Creates tar.gz archive file

Syncs backups to S3 bucket

## Requirements

- Github CLI
- jq
- AWS credentials for S3 sync

## Usage

This script can be used with e.g. CI workflow, Docker container or as it is:

```shell
GH_OWNER=myorg ./backup.sh
```

## Environment variables

| Name          | Value   |
|---------------|---------|
| GH_OWNER      | octocat |
| GH_LIST_LIMIT | 100     |

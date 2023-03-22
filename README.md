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
GH_OWNER=myorg GH_LIST_LIMIT=5 ./backup.sh
```

See [Github workflow](.github/workflows/backup.yml) to see how to use with Github Actions workflow.

## Environment variables

| Name           | Value   | Description                     |
|----------------|---------|---------------------------------|
| GH_CLI_TOKEN   |         | Specific token to use           |
| GH_OWNER       | octocat | GitHub organization             |
| GH_LIST_LIMIT  | 100     | How many repositories to backup |
| GIT_CLONE_MODE | ssh     | Clone using ssh or https        |

## TODO

- S3 sync script
- S3 workflow running that script
- Possibility to backup custom repositories

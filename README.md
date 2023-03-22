# Git Backupper

Backup organization's GitHub repositories with Github CLI.

- Clones repository with --mirror mode
- Clones repository wiki if exists
- Gets repository issues as JSON
- Creates tar.gz archive file
- Sync backup archives to S3 bucket

## Requirements

- Github CLI
- jq
- awscli

Note: all these are pre-installed on Github Action runners and in Docker image (see below).

## Usage

These scripts can be used with e.g. CI workflow, Docker container or as it is:

```shell
GH_OWNER=myorg GH_LIST_LIMIT=5 ./backup.sh
```

```shell
S3_BUCKET=mybucket AWS_ACCESS_KEY_ID=mykey AWS_SECRET_ACCESS_KEY=mysecret ./s3.sh
```

See [Github workflow](.github/workflows/backup.yml) to see how to use with Github Actions workflow.

## Environment variables

For `backup.sh`:

| Name           | Value   | Description                     |
|----------------|---------|---------------------------------|
| GH_TOKEN       |         | Specific token to use           |
| GH_OWNER       | octocat | GitHub organization             |
| GH_LIST_LIMIT  | 100     | How many repositories to backup |
| GIT_CLONE_MODE | ssh     | Clone using ssh or https        |

For `s3.sh`:

| Name                  | Value        | Description                  |
|-----------------------|--------------|------------------------------|
| S3_BUCKET             |              | Target S3 bucket for backups |
| AWS_ACCESS_KEY_ID     |              | awscli credential            |
| AWS_SECRET_ACCESS_KEY |              | awscli credential            |
| S3_REGION             | eu-central-1 | Default region               |

## Docker image

Use prebuild image:

```shell
docker run -ti --rm -e GH_TOKEN=YOUR_PAT -e GH_OWNER=myorg -e GH_LIST_LIMIT=5 \
  -v `pwd`/backups:/app/backups ghcr.io/druidfi/git-backupper
```

Build image as `git-backupper:latest`:

```shell
docker build . --progress plain -t git-backupper
```

## TODO

- Possibility to backup custom repositories

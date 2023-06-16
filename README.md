# Restic backup

Restic backup and handling scripts

## General

Execute a command on the restic repository configured in `.env`:

```console
$ task <command>
```

Execute a command on the restic repository configured in `.env_$REPO`:

```console
$ REPO=prod task <command>
```

Available commands:
  * `init` - Initialize restic repository
  * `snapshots` - List all available snapshots
  * `list` - List files in given or latest snapshot
    * e.g.: `task list -- <snapshot>`
  * `restore` - Restore files from given or latest snapshot
    * e.g.: `task restore -- <snapshot>`
  * `status` - Print statistics about the repository
  * `check` - Check the restic repository
  * `unlock` - Unlock the restic repository
  * `cleanup` - Clean up restic cache

## License

[MIT](https://github.com/dreknix/tools-restic-backup/blob/main/LICENSE)


#!/usr/bin/env bash

if [[ ${DEBUG-} =~ ^1|yes|true$ ]]
then
  set -o xtrace
fi

if ! (return 0 2> /dev/null)
then
  set -o errexit
  set -o nounset
  set -o pipefail
fi
set -o errtrace

TMPFILE="$(mktemp /tmp/make_backup_XXXXXXXXXX)"

script_failed=false

# restic config file
RESTIC_CONFIG_FILE="./.env"
if [ ! -r "${RESTIC_CONFIG_FILE}" ]
then
  echo "ERROR: config file '.env' is missing"
  false
fi

RESTIC=""
# shellcheck disable=SC1090
set -a && source "${RESTIC_CONFIG_FILE}" && set +a


function script_trap_err() {
  trap - ERR      # Prevent potential recursion

  # disable 'errexit' and 'pipefail'
  set +o errexit
  set +o pipefail

  script_failed=true
  exit
}

function script_trap_exit() {
  if [ $script_failed != true ]
  then
    if [ "${RESTIC_EMAIL_ON_SUCCESS:-}" = true ]
    then
      mail -s "Info: $(hostname) make_backup.sh" "${RESTIC_EMAIL_ADDRESS:-root}" < "${TMPFILE}"
    fi
  else
    if [ "${RESTIC_EMAIL_ON_FAILURE:-}" = true ]
    then
      mail -s "ERROR: $(hostname) make_backup.sh failed" "${RESTIC_EMAIL_ADDRESS:-root}" < "${TMPFILE}"
    fi
  fi
  rm -f "${TMPFILE}"
}

function make_backup() {
  if ! type "restic" > /dev/null 2>&1
  then
    echo "ERROR: command restic not found"
    false
  fi

  if ! type "jq" > /dev/null 2>&1
  then
    echo "ERROR: command jq not found"
    false
  fi

  if [ -z "${RESTIC}" ]
  then
    RESTIC="restic"
  fi

  echo "Restic Backup - ${RESTIC_REPOSITORY}"
  echo "using: $(${RESTIC} version)"

  # check if repository needs to be initialized
  if ! "${RESTIC}" snapshots > /dev/null 2>&1
  then
    "${RESTIC}" init
  fi

  # check if repository is ok
  "${RESTIC}" check -q

  BACKUP_EXCLUDE=""
  if [ -r "backup.exclude" ]
  then
    BACKUP_EXCLUDE="--exclude-file=backup.exclude"
  fi

  echo ""
  echo "Creating backup of ${RESTIC_BACKUP_PATHS:-~/dreknix/tools/restic-backup}"
  # shellcheck disable=SC2086
  "${RESTIC}" backup \
      --exclude ".git" --exclude ".cfg" --exclude ".svn" --exclude ".direnv" \
      --exclude ".cache" --exclude ".ansible" --exclude ".vscode-server" \
      --exclude "*.swp" --exclude "*~" --exclude "*.bak" \
      --exclude-caches \
      ${BACKUP_EXCLUDE} \
      --one-file-system \
      --host "${RESTIC_HOST}" \
      ${RESTIC_BACKUP_PATHS:-/home}

  echo ""
  echo "Show diff to last backup"
  # shellcheck disable=SC2046
  "${RESTIC}" diff --quiet $(restic snapshots --json | jq -r '.[-2:][].id')

  echo ""
  echo "Expire old snapshots"
  "${RESTIC}" forget \
      --quiet \
      --prune \
      --keep-daily   "${RESTIC_RETENTION_DAYS:-7}" \
      --keep-weekly  "${RESTIC_RETENTION_WEEKS:-8}" \
      --keep-monthly "${RESTIC_RETENTION_MONTHS:-12}" \
      --keep-yearly  "${RESTIC_RETENTION_YEARS:-2}"

  echo ""
  echo "Show snapshots"
  "${RESTIC}" snapshots --quiet --compact

  echo ""
  echo "Show stats"
  "${RESTIC}" stats --quiet --mode raw-data

  # store metrics in case node_exporter is running
  if [ -n "${RESTIC_PROM_DIRECTORY:-}" ] && [ -d "${RESTIC_PROM_DIRECTORY}" ]
  then
    TEMP_FILE="${RESTIC_PROM_DIRECTORY}/restic.prom.$$"
    PERM_FILE="${RESTIC_PROM_DIRECTORY}/restic.prom"

    echo "restic_last_run_ts $(date +%s)" > "${TEMP_FILE}"
    chmod go+r "${TEMP_FILE}"

    mv "${TEMP_FILE}" "${PERM_FILE}"
  fi
}

function main() {
  trap script_trap_err ERR
  trap script_trap_exit EXIT

  make_backup 2>&1 | tee "${TMPFILE}"
}


if ! (return 0 2> /dev/null); then
  main "$@"
else
  echo "It is not supported to source this script"
fi

#!/usr/bin/env bash

cmd="${RESTIC_PASSWORD_STORE_COMMAND:-gopass}"
store_path="${RESTIC_PASSWORD_STORE_PATH}"

if [ -z "${store_path}" ]
then
  exit 1
fi

if [ "${cmd}" == "gopass" ]
then
  RESTIC_PASSWORD_STORE_ARGS="show --password"
else
  RESTIC_PASSWORD_STORE_ARGS=""
fi

${cmd} ${RESTIC_PASSWORD_STORE_ARGS} "${store_path}"

#!/usr/bin/env make

ENV_FILE:=./.env$(if $(REPO),_$(REPO),)

ifneq (,$(wildcard ${ENV_FILE}))
  include ${ENV_FILE}
  VARS:=$(shell sed -ne 's/ *\#.*$$//; /./ s/=.*$$// p' .env )
  $(foreach v,$(VARS),$(eval $(shell echo export $(v)="$(shell echo $($(v)) | sed "s/^'//")")))
else
  $(error Environment file '${ENV_FILE}' not found)
endif

ifndef RESTIC
  RESTIC=restic
endif

.DEFAULT_GOAL:=help

.PHONY: .test_repo_exists foobar help

.test_repo_does_not_exist:
ifndef RESTIC_REPOSITORY
	$(error Variable "RESTIC_REPOSITORY" is not set)
endif
	@${RESTIC} cat config > /dev/null 2>&1 && { echo "Restic repository is already initialized"; exit 1; } || exit 0

.test_repo_exists:
ifndef RESTIC_REPOSITORY
	$(error Variable "RESTIC_REPOSITORY" is not set)
endif
	@${RESTIC} cat config > /dev/null 2>&1 || { echo "Restic repository does not exists"; exit 1; }

init: .test_repo_does_not_exist   ## Initialize restic repository
	${RESTIC} init

snapshots: .test_repo_exists      ## List all available snapshots
	${RESTIC} snapshots

list: .test_repo_exists           ## List files in latest snapshot
	${RESTIC} ls latest

restore: .test_repo_exists        ## Restore files from snapshot
	${RESTIC} restore latest --targe ./restore/

status: .test_repo_exists         ## Print statitics about the repository
	${RESTIC} stats

check: .test_repo_exists          ## Check the restic repository
	${RESTIC} stats

unlock: .test_repo_exists         ## Unlock the restic repository
	${RESTIC} unlock

cleanup: .test_repo_exists        ## Unlock the restic repository
	${RESTIC} cache --cleanup

help:                             ## Show this help
	@printf "\nUsage: make \033[36m<target>\033[0m\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\nVariable \033[36mREPO\033[0m can be used to switch between environments, e.g.: REPO=dev make \033[36m<target>\033[0m\n"

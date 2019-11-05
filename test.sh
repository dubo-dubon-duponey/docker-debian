#!/usr/bin/env bash

if ! hadolint --ignore DL4006 ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh*; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

if [ ! "$TEST_DOES_NOT_BUILD" ] && ! NO_CACHE=true NO_PUSH=true ./build.sh; then
  >&2 printf "Failed building image\n"
  exit 1
fi

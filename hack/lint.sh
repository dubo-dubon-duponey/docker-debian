#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../../"

command -v hadolint >/dev/null || {
  printf >&2 "You need to install hadolint"
  exit 1
}

command -v shellcheck >/dev/null || {
  printf >&2 "You need to install shellcheck"
  exit 1
}

if ! hadolint "$root"/*Dockerfile*; then
  printf >&2 "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck "$root"/**/*.sh; then
  printf >&2 "Failed shellchecking\n"
  exit 1
fi

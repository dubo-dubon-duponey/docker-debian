#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"
# shellcheck source=/dev/null
. "$root"/hack/setup.sh

# Requires a buildkit host and a cue binary
if ! "$root/hack/build.sh" \
    --inject from_image=debian:buster-20200130-slim \
    --inject from_tarball="nonexistent*" \
    --inject progress=plain \
	  --inject target_date=2021-06-01 \
	  --inject target_suite=buster \
    --inject platforms=linux/amd64,linux/arm/v7 \
  	debootstrap "$@"; then
  printf >&2 "Failed building tooling rootfs from online debian\n"
  exit 1
fi

result1="$(cat "$root"/context/cache/**/*.sha)"

if ! "$root/hack/build.sh" \
    --inject from_image=scratch \
    --inject from_tarball="buster-2021-06-01.tar" \
    --inject progress=plain \
	  --inject target_date=2020-01-01 \
	  --inject target_suite=buster \
    --inject platforms=linux/amd64,linux/arm/v7 \
  	debootstrap "$@"; then
  printf >&2 "Failed building tooling rootfs from existing rootfs\n"
  exit 1
fi

result2="$(cat "$root"/context/cache/**/*.sha)"

if [ "${result1%% *}" != "${result2%% *}" ]; then
  printf >&2 "ALERT - debootstrap is no longer producing consistent results: %s versus %s\n" "$result1" "$result2"
  exit 1
fi

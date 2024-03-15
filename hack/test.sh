#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null 1>&2 && pwd)/../"
readonly root

# Requires a buildkit host and a cue binary
if ! "$root/hack/build.sh" \
    --inject registry="docker.io/dubodubonduponey" \
    --inject progress=plain \
	  --inject date=2021-08-01 \
	  --inject suite=bookworm \
    --inject platforms=linux/amd64,linux/arm64 \
  	debootstrap "$@"; then
  printf >&2 "Failed building tooling rootfs from online debian\n"
  exit 1
fi

result1="$(cat "$root"/context/cache/**/*.sha)"

if ! "$root/hack/build.sh" \
    --inject registry="" \
    --inject progress=plain \
	  --inject date=2021-08-01 \
	  --inject suite=bookworm \
    --inject platforms=linux/amd64,linux/arm64 \
  	debootstrap "$@"; then
  printf >&2 "Failed building tooling rootfs from existing rootfs\n"
  exit 1
fi

result2="$(cat "$root"/context/cache/**/*.sha)"

if [ "${result1%% *}" != "${result2%% *}" ]; then
  printf >&2 "ALERT - debootstrap is no longer producing consistent results: %s versus %s\n" "$result1" "$result2"
  exit 1
fi

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

TEST_DOES_NOT_BUILD=${TEST_DOES_NOT_BUILD:-}

if ! hadolint ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

APT_OPTIONS="${APT_OPTIONS:-}"

http_proxy="$(printf "%s" "$APT_OPTIONS" | grep "Acquire::HTTP::proxy" | sed -E 's/^.*Acquire::HTTP::proxy=([^ ]+).*/\1/')" || true
export http_proxy

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then
  [ ! -e "./refresh.sh" ] || ./refresh.sh

  # That is ours, circa 2020-01-01
  export REBOOTSTRAP_IMAGE="docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"

  if ! ./hack/cue-bake rebootstrap --inject no_cache=true --inject progress=plain; then
    >&2 printf "Failed building rebootstrap\n"
    exit 1
  fi

  result="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"

  # That is official buster-slim, circa 2020-08-25
  export REBOOTSTRAP_IMAGE="debian@sha256:b2cade793f3558c90d018ed386cd61bf5e4ec06bf8ed6761bed3dd7e2c425ecc"

  if ! ./hack/cue-bake rebootstrap --inject no_cache=true --inject progress=plain; then
    >&2 printf "Failed building rebootstrap\n"
    exit 1
  fi

  result2="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"

  if [ "${result%% *}" != "${result2%% *}" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing consistent results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi

git checkout context/debootstrap/rootfs

export DEBOOTSTRAP_PLATFORMS=arm64
DEBOOTSTRAP_APT_OPTIONS="${DEBOOTSTRAP_APT_OPTIONS:-}"
[ "$DEBOOTSTRAP_APT_OPTIONS" ] || DEBOOTSTRAP_APT_OPTIONS="$APT_OPTIONS"
export DEBOOTSTRAP_APT_OPTIONS
export APT_OPTIONS="$APT_OPTIONS Acquire::Check-Valid-Until=no"

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then
  if ! ./hack/cue-bake debootstrap --inject no_cache=true --inject progress=plain; then
    >&2 printf "Failed building rebootstrap\n"
    exit 1
  fi

  result="$(sha512sum context/debian/cache/rootfs/linux/*/*.tar)"

  if ! ./hack/cue-bake debootstrap --inject no_cache=true --inject progress=plain; then
    >&2 printf "Failed building rebootstrap\n"
    exit 1
  fi

  result2="$(sha512sum context/debian/cache/rootfs/linux/*/*.tar)"

  if [ "${result%% *}" != "${result2%% *}" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing consistent results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

if ! hadolint ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

APT_OPTIONS="${APT_OPTIONS:-}"

http_proxy="$(printf "%s" "$APT_OPTIONS" | grep "Acquire::HTTP::proxy" || true | sed -E 's/^.*Acquire::HTTP::proxy=([^ ]+).*/\1/')"
export http_proxy

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then
  # That is ours, circa 2020-01-01
  export REBOOTSTRAP_IMAGE="docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
  ./build.sh --no-cache --progress plain rebootstrap
  result="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"

  # That is official buster-slim, circa 2020-08-25
  export REBOOTSTRAP_IMAGE="debian@sha256:b2cade793f3558c90d018ed386cd61bf5e4ec06bf8ed6761bed3dd7e2c425ecc"

  ./build.sh --no-cache --progress plain rebootstrap
  result2="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"

  if [ "${result%% *}" != "${result2%% *}" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing consistent results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi

export DEBOOTSTRAP_PLATFORMS=arm64
DEBOOTSTRAP_OPTIONS="${DEBOOTSTRAP_OPTIONS:-}"
[ "$DEBOOTSTRAP_OPTIONS" ] || DEBOOTSTRAP_OPTIONS="$APT_OPTIONS"
export DEBOOTSTRAP_OPTIONS
export APT_OPTIONS="$APT_OPTIONS Acquire::Check-Valid-Until=no"

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then
  ./build.sh --no-cache --progress plain debootstrap
  result="$(sha512sum context/debian/cache/rootfs/linux/*/*.tar)"

  ./build.sh --no-cache --progress plain debootstrap
  result2="$(sha512sum context/debian/cache/rootfs/linux/*/*.tar)"

  if [ "${result%% *}" != "${result2%% *}" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing consistent results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi



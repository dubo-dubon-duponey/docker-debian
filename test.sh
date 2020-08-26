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

export DEBOOTSTRAP_DATE=2020-08-01
export DEBOOTSTRAP_SUITE=buster
export DEBOOTSTRAP_REPOSITORY=""
export DEBOOTSTRAP_SOURCES_COMMIT=""
export DEBOOTSTRAP_TRUSTED=""
# With the latest base, we might need this to ignore expired signatures
export APT_OPTIONS=""
export APT_SOURCES=""
export APT_TRUSTED=""

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
    >&2 printf "ALERT - rebootstrap is no longer consistant results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi

export APT_OPTIONS="Acquire::Check-Valid-Until=no"
export DEBOOTSTRAP_OPTIONS=""
export DEBOOTSTRAP_SOURCES=""
export DEBOOTSTRAP_PLATFORMS=amd64

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then
  ./build.sh --no-cache --progress plain debootstrap
  result="$(grep amd64 context/debian/rootfs/buster-"$DEBOOTSTRAP_DATE".sha)"

  ./build.sh --no-cache --progress plain debootstrap
  result2="$(grep amd64 context/debian/rootfs/buster-"$DEBOOTSTRAP_DATE".sha)"

  if [ "${result%% *}" != "${result2%% *}" ]; then
    >&2 printf "ALERT - debootstrap is no longer consistant results: %s versus %s\n" "$result" "$result2"
    exit 1
  fi
fi



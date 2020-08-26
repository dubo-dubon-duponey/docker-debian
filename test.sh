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

  if [ "${result%% *}" != "c681d82882f0b08cac7f21eae9dcb82b9f9938c2185229b830bfa1f721fba0af45498dee7a00ccc98d355d60e44abaa664ebf75d571cb247d8e8248f5f072ca3" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing the expected value, but instead %s\n" "$result"
    exit 1
  fi

  # That is official buster-slim, circa 2020-08-25
  export REBOOTSTRAP_IMAGE="debian@sha256:b2cade793f3558c90d018ed386cd61bf5e4ec06bf8ed6761bed3dd7e2c425ecc"
  ./build.sh --no-cache --progress plain rebootstrap
  result="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"

  if [ "${result%% *}" != "c681d82882f0b08cac7f21eae9dcb82b9f9938c2185229b830bfa1f721fba0af45498dee7a00ccc98d355d60e44abaa664ebf75d571cb247d8e8248f5f072ca3" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing the expected value, but instead %s\n" "$result"
    exit 1
  fi
fi

if [ ! "${TEST_DOES_NOT_BUILD:-}" ]; then

  export APT_OPTIONS="Acquire::Check-Valid-Until=no"
  export DEBOOTSTRAP_OPTIONS=""
  export DEBOOTSTRAP_SOURCES=""
  export DEBOOTSTRAP_PLATFORMS=amd64

  ./build.sh --no-cache --progress plain debootstrap

  result="$(grep amd64 context/debian/rootfs/buster-"$DEBOOTSTRAP_DATE".sha)"

  if [ "${result%% *}" != "e365595a4c31f64c850615d2422d8d3d82d479fade75db80f64ebe48045fec035c98becc783aef4a5de152c27cdb8e99ee8a7942a00a3100100f7187b76456f8" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing the expected value, but instead %s\n" "$result"
    exit 1
  fi
fi



#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

TEST_DOES_NOT_BUILD=${TEST_DOES_NOT_BUILD:-}

if ! hadolint ./*Dockerfile*; then
  >&2 printf "Failed linting on Dockerfile\n"
  exit 1
fi

if ! shellcheck ./*.sh*; then
  >&2 printf "Failed shellchecking\n"
  exit 1
fi

if [ ! "$TEST_DOES_NOT_BUILD" ]; then
  # Rebootstrap and check that the result is the same
  ./build.sh --progress plain rebootstrap
  s="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"
  if [ "${s%% *}" != "9fec4b6c9b334ab7bc1553f8dc5a5766f3ce129e1619b7b67fa7fde27ca979a6a8ba83780d5ec6742e2d67f9aeaef3ad9972a0edff045796b74a98874096720c" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing 99ef315c3c0a8f9c713dc97ccc61cf820dfe4dcfe2d8958829c3d3033c91674d4e2008d891fa76a8f26c295339c7bd3a4e988ed34ee187e2aac0cae29a4bb3ba"
    exit 1
  fi

  # Debootstrap and check the same
  DEBIAN_DATE=2020-01-01 ./build.sh --progress plain debootstrap
  s="$(grep amd64 context/debian/rootfs/buster-2020-01-01.sha)"
  if [ "${s%% *}" != "9fec4b6c9b334ab7bc1553f8dc5a5766f3ce129e1619b7b67fa7fde27ca979a6a8ba83780d5ec6742e2d67f9aeaef3ad9972a0edff045796b74a98874096720c" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing 99ef315c3c0a8f9c713dc97ccc61cf820dfe4dcfe2d8958829c3d3033c91674d4e2008d891fa76a8f26c295339c7bd3a4e988ed34ee187e2aac0cae29a4bb3ba"
    exit 1
  fi
fi

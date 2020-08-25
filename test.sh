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

if [ ! "$TEST_DOES_NOT_BUILD" ]; then
  # Rebootstrap and check that the result is the same
  ./build.sh --no-cache --progress plain rebootstrap
  s="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"
  >&2 printf "rebootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "01b66f7b60e8dd551d990f1185aba5f20376f63bee2e9b527d7c63d6075961b20344dca84e38b3df737dcb021ffcae1d1739948ad0ef8f3aa2dbd0f02ec41382" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing 01b66f7b60e8dd551d990f1185aba5f20376f63bee2e9b527d7c63d6075961b20344dca84e38b3df737dcb021ffcae1d1739948ad0ef8f3aa2dbd0f02ec41382\n"
    exit 1
  else
    >&2 printf "rebootstrap ok\n"
  fi

  # Debootstrap and check the same
  DEBOOTSTRAP_DATE=2020-01-01 ./build.sh --no-cache --progress plain debootstrap
  s="$(grep amd64 context/debian/rootfs/buster-2020-01-01.sha)"
  >&2 printf "debootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "01b66f7b60e8dd551d990f1185aba5f20376f63bee2e9b527d7c63d6075961b20344dca84e38b3df737dcb021ffcae1d1739948ad0ef8f3aa2dbd0f02ec41382" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing 01b66f7b60e8dd551d990f1185aba5f20376f63bee2e9b527d7c63d6075961b20344dca84e38b3df737dcb021ffcae1d1739948ad0ef8f3aa2dbd0f02ec41382\n"
    exit 1
  else
    >&2 printf "debootstrap ok\n"
  fi
fi

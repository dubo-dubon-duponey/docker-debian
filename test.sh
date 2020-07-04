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
  >&2 printf "rebootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "91797bb9e689ecb5aa1fd2b0ed517fd9ebd3e73a66eefd631d7f82ce6dbde701069a1dc1f44dd41bf70cf1913cb8573c91aeedda762ef3e6ea2cef6dcb4b5505" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing 91797bb9e689ecb5aa1fd2b0ed517fd9ebd3e73a66eefd631d7f82ce6dbde701069a1dc1f44dd41bf70cf1913cb8573c91aeedda762ef3e6ea2cef6dcb4b5505\n"
    exit 1
  else
    >&2 printf "rebootstrap ok\n"
  fi

  # Debootstrap and check the same
  DEBIAN_DATE=2020-01-01 ./build.sh --progress plain debootstrap
  s="$(grep amd64 context/debian/rootfs/buster-2020-01-01.sha)"
  >&2 printf "debootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "91797bb9e689ecb5aa1fd2b0ed517fd9ebd3e73a66eefd631d7f82ce6dbde701069a1dc1f44dd41bf70cf1913cb8573c91aeedda762ef3e6ea2cef6dcb4b5505" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing 91797bb9e689ecb5aa1fd2b0ed517fd9ebd3e73a66eefd631d7f82ce6dbde701069a1dc1f44dd41bf70cf1913cb8573c91aeedda762ef3e6ea2cef6dcb4b5505\n"
    exit 1
  else
    >&2 printf "debootstrap ok\n"
  fi
fi

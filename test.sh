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
  ./build.sh --no-cache --progress plain rebootstrap
  s="$(cat context/debootstrap/rootfs/linux/amd64/debootstrap.sha)"
  >&2 printf "rebootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "02ff894af506ddbc2f22b7227822e6d052b24e7fbc8ce09a3ec1c5274b626a7147913bba3bcf13d6fb1330609a608ed724b98806f3d3f715164d9c70d461cec1" ]; then
    >&2 printf "ALERT - rebootstrap is no longer producing 02ff894af506ddbc2f22b7227822e6d052b24e7fbc8ce09a3ec1c5274b626a7147913bba3bcf13d6fb1330609a608ed724b98806f3d3f715164d9c70d461cec1\n"
    exit 1
  else
    >&2 printf "rebootstrap ok\n"
  fi

  # Debootstrap and check the same
  DEBIAN_DATE=2020-01-01 ./build.sh --progress plain debootstrap
  s="$(grep amd64 context/debian/rootfs/buster-2020-01-01.sha)"
  >&2 printf "debootstrap produced %s\n" "$s"
  if [ "${s%% *}" != "02ff894af506ddbc2f22b7227822e6d052b24e7fbc8ce09a3ec1c5274b626a7147913bba3bcf13d6fb1330609a608ed724b98806f3d3f715164d9c70d461cec1" ]; then
    >&2 printf "ALERT - debootstrap is no longer producing 02ff894af506ddbc2f22b7227822e6d052b24e7fbc8ce09a3ec1c5274b626a7147913bba3bcf13d6fb1330609a608ed724b98806f3d3f715164d9c70d461cec1\n"
    exit 1
  else
    >&2 printf "debootstrap ok\n"
  fi
fi

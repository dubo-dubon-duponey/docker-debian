// platf: [...string] @tag(platforms)

import (
  "tool/os"
  "strings"
  "tool/cli"
)

command: {
  rebootstrap: #Bake & {
    target: "rebootstrap"
    context: "context/debootstrap"

    platforms: [AMD64]

    directory: "context/debootstrap"

    args: os.Getenv & {
      DEBOOTSTRAP_DATE: string | * "2020-01-01"
      DEBOOTSTRAP_SUITE: string | * "buster"

      http_proxy: string | * ""
      https_proxy: string | * ""
      SYSTEM_TLS_CA: string | * ""
      SYSTEM_NETRC: string | * ""

      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=APT-DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_GPG_KEYRING: string | * ""
      APT_TLS_CA: string | * ""
      APT_NETRC: string | * ""
      APT_SOURCES: string | * ""

      DEBOOTSTRAP_GPG_KEYRING: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""

      // Specific to this
      REBOOTSTRAP_IMAGE: string | * "docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
    }
  }

  debootstrap: #Bake & {
    target: "debootstrap"
    context: "context/debootstrap"

    platforms: [AMD64]

    directory: "context/debian/cache"

    args: os.Getenv & {
      DEBOOTSTRAP_DATE: string | * "2020-01-01"
      DEBOOTSTRAP_SUITE: string | * "buster"

      http_proxy: string | * ""
      https_proxy: string | * ""
      SYSTEM_TLS_CA: string | * ""
      SYSTEM_NETRC: string | * ""

      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=APT-DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_GPG_KEYRING: string | * ""
      APT_TLS_CA: string | * ""
      APT_NETRC: string | * ""
      APT_SOURCES: string | * ""

      DEBOOTSTRAP_GPG_KEYRING: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""

      // Specific to this
      DEBOOTSTRAP_PLATFORMS: string | * "armel armhf arm64 amd64 i386 s390x ppc64el"
      DEBOOTSTRAP_APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DS-DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      DEBOOTSTRAP_APT_SOURCES: string | * ""
    }
  }

  debian: #Dubo & {
    target: "debian"
    context: "context/debian"

    platforms: [
      AMD64,
      ARM64,
      V6,
      V7,
      I386,
      S390X,
      PPC64LE,
    ]

    args: {
      BUILD_TITLE: "Debian \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
      BUILD_DESCRIPTION: "Dubo base, from scratch, Debian image"
    }
  }
}


// platf: [...string] @tag(platforms)

import (
  "tool/os"
  "strings"
  "tool/cli"
)

command: {
  rebootstrap: #Bake & {
    target: value: "rebootstrap"
    context: value: "context/debootstrap"

    platforms: value: [#Platforms.AMD64]

    directory: "context/debootstrap"

    args: value: os.Getenv & {
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

      // Specific to the debians stages
      DEBOOTSTRAP_GPG_KEYRING: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""

      // Specific to this stage
      REBOOTSTRAP_IMAGE: string | * "docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
    }
  }

  debootstrap: #Bake & {
    target: value: "debootstrap"
    context: value: "context/debootstrap"

    platforms: value: [#Platforms.AMD64]

    directory: "context/debian/cache"

    args: value: os.Getenv & {
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

      // Specific to the debians stages
      DEBOOTSTRAP_GPG_KEYRING: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""

      // Specific to this
      DEBOOTSTRAP_PLATFORMS: string | * "armel armhf arm64 amd64 i386 s390x ppc64el"
      DEBOOTSTRAP_APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DS-DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      DEBOOTSTRAP_APT_SOURCES: string | * ""
    }
  }

    platforms: value: [
      #Platforms.AMD64,
      #Platforms.ARM64,
      #Platforms.V6,
      #Platforms.V7,
      #Platforms.I386,
      #Platforms.S390X,
      #Platforms.PPC64LE,
    ]

  debian: #Dubo & {
    target: value: "debian"
    context: value: "context/debian"

    platforms: value: [
      #Platforms.S390X,
    ]

    args: value: {
      BUILD_TITLE: "Debian \(args.value.DEBOOTSTRAP_SUITE) (\(args.value.DEBOOTSTRAP_DATE))"
      BUILD_DESCRIPTION: "Dubo base, from scratch, Debian image"
    }
  }
}


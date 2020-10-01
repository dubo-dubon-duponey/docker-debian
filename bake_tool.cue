// platf: [...string] @tag(platforms)

import (
  "tool/os"
  "strings"
  "tool/cli"
)

command: {
  // tarball: "cache/export-oci.tar"
  // tarballtype: "oci"
  //  	no_cache: nocache | *false
  // XXX how do you do that with buildkit?
  // pull = true

  rebootstrap: #Bake & {
    target: "rebootstrap"
    context: "context/debootstrap"

    platforms: [AMD64]

    directory: "context/debootstrap"

    //  string | * "default as in cue" | string @tag(TESTIT,type=string)

    args: os.Getenv & {
      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_TRUSTED: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""
      DEBOOTSTRAP_DATE: string | * "2020-01-01"
      DEBOOTSTRAP_SUITE: string | * "buster"

      REBOOTSTRAP_IMAGE: string | * "docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
    }

  }

  debootstrap: #Bake & {
    target: "debootstrap"
    context: "context/debootstrap"

    platforms: [AMD64]

    directory: "context/debian/cache"
    args: os.Getenv & {
      http_proxy: string | * ""
      https_proxy: string | * ""
      APT_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      APT_SOURCES: string | * ""
      APT_TRUSTED: string | * ""
      DEBOOTSTRAP_SOURCES_COMMIT: string | * ""
      DEBOOTSTRAP_TRUSTED: string | * ""
      DEBOOTSTRAP_REPOSITORY: string | * ""
      DEBOOTSTRAP_DATE: string | * "2020-01-01"
      DEBOOTSTRAP_SUITE: string | * "buster"

      DEBOOTSTRAP_PLATFORMS: string | * "armel armhf arm64 amd64 i386 s390x ppc64el"
      DEBOOTSTRAP_OPTIONS: string | * "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1 Acquire::Check-Valid-Until=no"
      DEBOOTSTRAP_SOURCES: string | * ""
    }
  }

  debian: #Dubo & {
    args: {
      BUILD_TITLE: "Debian \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
      BUILD_DESCRIPTION: "Dubo base, from scratch, Debian image"
    }
    target: "debian"
    context: "context/debian"
    dockerfiledir: "."
    platforms: [
      AMD64,
      ARM64,
      V6,
      V7,
      I386,
      S390X,
      PPC64LE,
    ]
  }
}


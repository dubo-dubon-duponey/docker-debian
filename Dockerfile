ARG           REBOOTSTRAP_IMAGE=docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746
########################################################################################################################
# This first "rebootstrap" target is meant to prepare a *local* rootfs that we will use as a local builder base later on
# The purpose of this is to make sure our further builder images do not depend on ANY registry
# Note:
# REBOOTSTRAP_IMAGE is the *online* Debian base image you need to initialize and generate this local rootfs.
# You may use a Docker maintained Debian Buster image (library/debian:buster-slim for example).
# Or our image (this is the default, and was built using debootstrap against Buster 2020-01-01)
# You may of course (recommended), use your own debootstrapped Buster image instead.
# All three methods will produce the same resulting rootfs.
# Obviously, if you already have a working local rootfs for Debian, you do not need this stage at all, right?
########################################################################################################################

# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $REBOOTSTRAP_IMAGE                                                              AS rebootstrap-builder

# The platform we are on
ARG           BUILDPLATFORM

ARG           DEBIAN_FRONTEND="noninteractive"
ARG           TERM="xterm"
ARG           LANG="C.UTF-8"
ARG           LC_ALL="C.UTF-8"
ARG           TZ="America/Los_Angeles"

ARG           http_proxy
ARG           https_proxy

# For this builder image
# > optional options to pass to APT
ARG           APT_OPTIONS
# > optionnally, custom sources for apt to override temporarily whatever is already in /etc/apt/sources.list
ARG           APT_SOURCES
# > optionnally, an additional trusted db
ARG           APT_TRUSTED

# Copy over our deviation script
COPY          ./apt-get /usr/local/sbin/

# Get debootstrap in
RUN           set -eu; \
              apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                debootstrap=1.0.114

# Add debuerreotype
COPY          ./debuerreotype/scripts /usr/sbin/
# Copy over our deviation script
# See comments inline for reason to have this
# Note: other scripts insist in calling a script in the SAME dir, so /usr/sbin it is
COPY          ./debuerreotype-chroot  /usr/sbin/

# What and how you want to debootstrap
# > Optional options to feed to the in-debootstrap apt
#ARG           DEBOOTSTRAP_OPTIONS
# > Optionally the list of apt sources to use inside the debootstrap instead of whatever is already in root/etc/apt/sources.list
#ARG           DEBOOTSTRAP_SOURCES
# > Optionally the final content to commit for root/etc/apt/sources.list in the debootstrap
ARG           DEBOOTSTRAP_SOURCES_COMMIT
# > Possibly an optional trusteddb.gpg file to trust (typically, the result of importing repositories gpg key with apt-key)
ARG           DEBOOTSTRAP_TRUSTED
# > Which suite you want
ARG           DEBOOTSTRAP_SUITE=buster

# > Then, either a date to fetch from snapshot.debian.org (will also be used as a key for the stored rootfs)
ARG           DEBOOTSTRAP_DATE=2020-01-01
# > Or your own repository (http://user:pass@mydeb.domain.com:8080/foo/bar)
ARG           DEBOOTSTRAP_REPOSITORY

WORKDIR       /bootstrapper

# hadolint ignore=DL4006
RUN           set -eu; \
              targetarch="$(dpkg --print-architecture | awk -F- "{ print \$NF }")"; \
              if [ "${DEBOOTSTRAP_REPOSITORY:-}" ]; then \
                if [ "${DEBOOTSTRAP_TRUSTED:-}" ]; then \
                  printf "%s" "$DEBOOTSTRAP_TRUSTED" | base64 -d > /tmp/dbdbdp.gpg; \
                  debuerreotype-init --arch "$targetarch" --no-merged-usr --non-debian --keyring /tmp/dbdbdp.gpg rootfs "$DEBOOTSTRAP_SUITE" "$DEBOOTSTRAP_REPOSITORY"; \
                else \
                  debuerreotype-init --arch "$targetarch" --no-merged-usr --non-debian rootfs "$DEBOOTSTRAP_SUITE" "$DEBOOTSTRAP_REPOSITORY"; \
                fi; \
              else \
                debuerreotype-init --arch "$targetarch" --no-merged-usr --debian rootfs "$DEBOOTSTRAP_SUITE" "${DEBOOTSTRAP_DATE}T00:00:00Z"; \
              fi

RUN           set -eu; \
              if [ "${DEBOOTSTRAP_SOURCES_COMMIT:-}" ]; then \
                printf "%s\n" "$DEBOOTSTRAP_SOURCES_COMMIT" > rootfs/etc/apt/sources.list; \
              fi; \
              debuerreotype-minimizing-config rootfs; \
              debuerreotype-slimify rootfs

RUN           set -eu; \
              mkdir -p "/rootfs/$BUILDPLATFORM"; \
              debuerreotype-tar rootfs "/rootfs/$BUILDPLATFORM/debootstrap.tar"; \
              sha512sum "/rootfs/$BUILDPLATFORM/debootstrap.tar" > "/rootfs/$BUILDPLATFORM/debootstrap.sha"

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS rebootstrap
COPY          --from=rebootstrap-builder /rootfs /rootfs

########################################################################################################################
# This is a builder image from scratch leveraging our initial rootfs from above
# It provides a clean-room environment with no external image dependency
########################################################################################################################
FROM          --platform=$BUILDPLATFORM scratch                                                                         AS builder

# The platform we are on
ARG           BUILDPLATFORM

# Adding our rootfs
ADD           ./rootfs/$BUILDPLATFORM/debootstrap.tar /

ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"
ONBUILD ARG   TERM="xterm"
ONBUILD ARG   LANG="C.UTF-8"
ONBUILD ARG   LC_ALL="C.UTF-8"
ONBUILD ARG   TZ="America/Los_Angeles"

ONBUILD ARG   http_proxy
ONBUILD ARG   https_proxy

ONBUILD ARG   APT_OPTIONS="Acquire::Check-Valid-Until=no"
ONBUILD ARG   APT_SOURCES
ONBUILD ARG   APT_TRUSTED

# Copy over our deviation script
COPY          ./apt-get /usr/local/sbin/

ONBUILD ARG   DEBOOTSTRAP_OPTIONS
ONBUILD ARG   DEBOOTSTRAP_SOURCES
ONBUILD ARG   DEBOOTSTRAP_SOURCES_COMMIT
ONBUILD ARG   DEBOOTSTRAP_TRUSTED
ONBUILD ARG   DEBOOTSTRAP_SUITE=buster
ONBUILD ARG   DEBOOTSTRAP_DATE=2020-01-01
ONBUILD ARG   DEBOOTSTRAP_REPOSITORY
ONBUILD ARG   DEBOOTSTRAP_PLATFORMS="armel armhf arm64 amd64"
# i386 s390x ppc64el

########################################################################################################################
# This is a builder image that will produce our final rootfs for all architectures
########################################################################################################################
FROM          builder                                                                                                   AS debootstrap-builder

# Installing qemu and debue/deboot
RUN           set -eu; \
              apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                debootstrap=1.0.114 \
                qemu-user-static=1:3.1+dfsg-8+deb10u7

WORKDIR       /bootstrapper

COPY          ./debuerreotype/scripts /usr/sbin/
COPY          ./debuerreotype-chroot  /usr/sbin/

# hadolint ignore=DL4006
RUN           set -eu; \
              for targetarch in $DEBOOTSTRAP_PLATFORMS; do \
                if [ "${DEBOOTSTRAP_REPOSITORY:-}" ]; then \
                  if [ "${DEBOOTSTRAP_TRUSTED:-}" ]; then \
                    printf "%s" "$DEBOOTSTRAP_TRUSTED" | base64 -d > /tmp/dbdbdp.gpg; \
                    debuerreotype-init --arch "$targetarch" --no-merged-usr --debootstrap="qemu-debootstrap" --non-debian --keyring /tmp/dbdbdp.gpg rootfs-"$targetarch" "$DEBOOTSTRAP_SUITE" "$DEBOOTSTRAP_REPOSITORY"; \
                  else \
                    debuerreotype-init --arch "$targetarch" --no-merged-usr --debootstrap="qemu-debootstrap" --non-debian rootfs-"$targetarch" "$DEBOOTSTRAP_SUITE" "$DEBOOTSTRAP_REPOSITORY"; \
                  fi; \
                else \
                  debuerreotype-init --arch "$targetarch" --no-merged-usr --debootstrap="qemu-debootstrap" --debian rootfs-"$targetarch" "$DEBOOTSTRAP_SUITE" "${DEBOOTSTRAP_DATE}T00:00:00Z"; \
                fi; \
                if [ "${DEBOOTSTRAP_SOURCES_COMMIT:-}" ]; then \
                  printf "%s\n" "$DEBOOTSTRAP_SOURCES_COMMIT" > rootfs-"$targetarch"/etc/apt/sources.list; \
                fi; \
              done

RUN           set -eu; \
              for targetarch in $DEBOOTSTRAP_PLATFORMS; do \
                debuerreotype-apt-get rootfs-"$targetarch" update -qq; \
              done

RUN           set -eu; \
              for targetarch in $DEBOOTSTRAP_PLATFORMS; do \
                debuerreotype-apt-get rootfs-"$targetarch" dist-upgrade -yqq; \
              done

RUN           set -eu; \
              for targetarch in $DEBOOTSTRAP_PLATFORMS; do \
                debuerreotype-minimizing-config rootfs-"$targetarch"; \
                debuerreotype-slimify rootfs-"$targetarch"; \
              done

# Generate tarballs, sha, exit
RUN           set -eu; \
              mkdir -p "/rootfs/linux/arm/v6"; \
              mkdir -p "/rootfs/linux/arm/v7"; \
              mkdir -p "/rootfs/linux/arm64"; \
              mkdir -p "/rootfs/linux/amd64"; \
              mkdir -p "/rootfs/linux/386"; \
              mkdir -p "/rootfs/linux/s390x"; \
              mkdir -p "/rootfs/linux/ppc64el"; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armel "/rootfs/linux/arm/v6/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armhf "/rootfs/linux/arm/v7/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-arm64 "/rootfs/linux/arm64/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-amd64 "/rootfs/linux/amd64/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-i386 "/rootfs/linux/386/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-s390x "/rootfs/linux/s390x/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-ppc64el "/rootfs/linux/ppc64el/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar 2>/dev/null || true; \
              rm -f /rootfs/"${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".sha; \
              sha512sum /rootfs/linux/*/*/*.tar >> /rootfs/"${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".sha 2>/dev/null || true; \
              sha512sum /rootfs/linux/*/*.tar >> /rootfs/"${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".sha 2>/dev/null || true

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS debootstrap
COPY          --from=debootstrap-builder /rootfs /rootfs

########################################################################################################################
# Our final, multi-arch, Debian Buster image, using the rootfs generated in the step above
########################################################################################################################
FROM          scratch                                                                                                   AS debian

ARG           DEBOOTSTRAP_SUITE=buster
ARG           DEBOOTSTRAP_DATE=2020-01-01
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar /

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"
ARG           BUILD_URL="https://github.com/dubo-dubon-duponey/docker-debian"
ARG           BUILD_DOCUMENTATION="https://github.com/dubo-dubon-duponey/docker-debian"
ARG           BUILD_SOURCE="https://github.com/dubo-dubon-duponey/docker-debian"
ARG           BUILD_VERSION="unknown"
ARG           BUILD_REVISION="unknown"
ARG           BUILD_VENDOR="dubodubonduponey"
ARG           BUILD_LICENSES="MIT"
ARG           BUILD_REF_NAME="latest"
ARG           BUILD_TITLE="A DBDBDP image"
ARG           BUILD_DESCRIPTION="So image. Much DBDBDP. Such description."

LABEL         org.opencontainers.image.created="$BUILD_CREATED"
LABEL         org.opencontainers.image.authors="Dubo Dubon Duponey <dubo-dubon-duponey@farcloser.world>"
LABEL         org.opencontainers.image.url="$BUILD_URL"
LABEL         org.opencontainers.image.documentation="$BUILD_DOCUMENTATION"
LABEL         org.opencontainers.image.source="$BUILD_SOURCE"
LABEL         org.opencontainers.image.version="$BUILD_VERSION"
LABEL         org.opencontainers.image.revision="$BUILD_REVISION"
LABEL         org.opencontainers.image.vendor="$BUILD_VENDOR"
LABEL         org.opencontainers.image.licenses="$BUILD_LICENSES"
LABEL         org.opencontainers.image.ref.name="$BUILD_REF_NAME"
LABEL         org.opencontainers.image.title="$BUILD_TITLE"
LABEL         org.opencontainers.image.description="$BUILD_DESCRIPTION"

ONBUILD ARG   APT_OPTIONS
ONBUILD ARG   APT_SOURCES
ONBUILD ARG   APT_TRUSTED

ONBUILD ARG   http_proxy
ONBUILD ARG   https_proxy

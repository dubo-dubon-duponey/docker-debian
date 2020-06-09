# syntax = docker/dockerfile@sha256:888f21826273409b5ef5ff9ceb90c64a8f8ec7760da30d1ffbe6c3e2d323a7bd
ARG           DEBIAN_REBOOTSTRAP=docker.io/dubodubonduponey/debian@sha256:68e9b2b386453c99bc3aeca7bdc448243dfe819aaa0a14dd65a0d5fdd0a66276
# ATTENTION: we do use the advanced buildx dockerfile syntax on the first line here ^^^
########################################################################################################################
# This first "rebootstrap" target is meant to prepare a *local* rootfs that we will use as a builder base later on
# The purpose of this is to make sure we have a local debian artifact so that we do not depend on anything online
# after this stage has been run at least ONCE
# Notes of importance:
# 1. the use of the experimental frontend is required for --insecure to work (which is required by the use of unshare in debuerreotype)
# 2. DEBIAN_REBOOTSTRAP is the *online* Debian base image you need to initialize and generate your local *builder* rootfs.
# You may use a Docker maintained Debian Buster image (library/debian:buster-slim for example).
# Or our image (this is the default, and was built using debootstrap against Buster 2020-01-01)
# You may of course (recommended), use your own debootstrapped Buster image instead.
# All three methods will produce the same resulting rootfs.
########################################################################################################################

# hadolint ignore=DL3006
FROM          $DEBIAN_REBOOTSTRAP                                                                                       AS rebootstrap

# Targetting:
ARG           DEBIAN_DATE=2020-01-01T00:00:00Z
ARG           DEBIAN_SUITE=buster

# Honor proxy
ARG           APTPROXY=""
RUN           printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf
RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

# Get debuerreotype and debootstrap in
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                debuerreotype=0.9-1 \
                debootstrap=1.0.114

WORKDIR       /bootstrapper

# debuerreotype makes --security mandatory since they use chroot
# XXX also note that debuerreotype does not honor apt proxy config from above, hence the exception in using http_proxy directly...
# hadolint ignore=SC2215,DL4006
RUN           --security=insecure set -eu; \
              targetarch="$(dpkg --print-architecture | awk -F- "{ print \$NF }")"; \
              case "$targetarch" in \
                amd64) \
                  targetarchpath=/rootfs/linux/amd64; \
                ;; \
                arm64) \
                  targetarchpath=/rootfs/linux/arm64; \
                ;; \
                armhf) \
                  targetarchpath=/rootfs/linux/arm/v7; \
                ;; \
                armel) \
                  targetarchpath=/rootfs/linux/arm/v6; \
                ;; \
                *) \
                  >&2 printf "Unsupported architecture %s" "$targetarch" \
                  exit 1 \
                ;; \
              esac; \
              mkdir -p "$targetarchpath"; \
              http_proxy="$APTPROXY" debuerreotype-init --arch "$targetarch" --debian --no-merged-usr rootfs-"$targetarch" "$DEBIAN_SUITE" "$DEBIAN_DATE"; \
              debuerreotype-minimizing-config rootfs-"$targetarch"; \
              debuerreotype-slimify rootfs-"$targetarch"; \
              debuerreotype-tar rootfs-"$targetarch" "${targetarchpath}"/debootstrap.tar; \
              sha512sum "${targetarchpath}"/debootstrap.tar > "${targetarchpath}"/debootstrap.sha

########################################################################################################################
# This is the image that will produce our final rootfs - booting off the initial rootfs obtained from above
########################################################################################################################
FROM          --platform=$BUILDPLATFORM scratch                                                                         AS debootstrap

# What we target
ARG           DEBIAN_DATE=2020-01-01T00:00:00Z
ARG           DEBIAN_SUITE=buster

# The platform we are on
ARG           BUILDPLATFORM

# Adding our rootfs
ADD           ./rootfs/$BUILDPLATFORM/debootstrap.tar /

# Honor proxy
ARG           APTPROXY=""
RUN           printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf
RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

# Installing qemu and debue/deboot
# hadolint ignore=DL3009
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                debuerreotype=0.9-1 \
                debootstrap=1.0.114 \
                qemu-user-static=1:3.1+dfsg-8+deb10u2

# Building our rootfs on all platforms we support (armel, armhf, arm64, amd64)
WORKDIR       /bootstrapper

# XXX see note above about http_proxy and debu
# hadolint ignore=SC2215
RUN           --security=insecure set -eu; \
              for targetarch in armel armhf arm64 amd64; do \
                http_proxy="$APTPROXY" debuerreotype-init --arch "$targetarch" --debian --no-merged-usr --debootstrap="qemu-debootstrap" rootfs-"$targetarch" "$DEBIAN_SUITE" "$DEBIAN_DATE"; \
                debuerreotype-apt-get rootfs-"$targetarch" update -qq; \
                debuerreotype-apt-get rootfs-"$targetarch" dist-upgrade -yqq; \
                debuerreotype-minimizing-config rootfs-"$targetarch"; \
                debuerreotype-slimify rootfs-"$targetarch"; \
              done

# Generate tarballs, sha, exit
RUN           mkdir -p "/rootfs/linux/arm/v6"; \
              mkdir -p "/rootfs/linux/arm/v7"; \
              mkdir -p "/rootfs/linux/arm64"; \
              mkdir -p "/rootfs/linux/amd64"

# hadolint ignore=SC2215
RUN           --security=insecure set -eu; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armel "/rootfs/linux/arm/v6/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armhf "/rootfs/linux/arm/v7/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-arm64 "/rootfs/linux/arm64/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-amd64 "/rootfs/linux/amd64/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar

RUN           sha512sum /rootfs/linux/*/*.tar /rootfs/linux/*/*/*.tar > /rootfs/"${DEBIAN_SUITE}-${DEBIAN_DATE}".sha

########################################################################################################################
# Our final, multi-arch, Debian Buster image, using the rootfs generated in the step above
########################################################################################################################
FROM          scratch                                                                                                   AS debian

ARG           DEBIAN_DATE=2020-01-01T00:00:00Z
ARG           DEBIAN_SUITE=buster
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /

RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

# Ensure that subsequent calls to apt will honor on build proxy argument
ONBUILD ARG   APTPROXY=""
ONBUILD RUN   printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf

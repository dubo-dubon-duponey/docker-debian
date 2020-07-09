ARG           DEBIAN_REBOOTSTRAP=docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746
########################################################################################################################
# This first "rebootstrap" target is meant to prepare a *local* rootfs that we will use as a builder base later on
# The purpose of this is to make sure we have a local debian artifact so that we do not depend on anything online
# after this stage has been run at least ONCE
# Note:
# DEBIAN_REBOOTSTRAP is the *online* Debian base image you need to initialize and generate your local *builder* rootfs.
# You may use a Docker maintained Debian Buster image (library/debian:buster-slim for example).
# Or our image (this is the default, and was built using debootstrap against Buster 2020-01-01)
# You may of course (recommended), use your own debootstrapped Buster image instead.
# All three methods will produce the same resulting rootfs.
# Obviously, if you already have a working rootfs for Debian - what you are you doing here exactly?
########################################################################################################################

# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $DEBIAN_REBOOTSTRAP                                                             AS rebootstrap-build

# The platform we are on
ARG           BUILDPLATFORM

# Targetting:
ARG           DEBIAN_DATE=2020-01-01
ARG           DEBIAN_SUITE=buster

# Honor proxy - but only if it's not https
ARG           APTPROXY=""
RUN           printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf
# Using snapshot, packages sig are outdated by nature
RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

# Get debuerreotype and debootstrap in
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                git=1:2.20.1-2+deb10u1 \
                debootstrap=1.0.114

WORKDIR       /bootstrapper

# 0.10
ARG           GIT_REPO=github.com/debuerreotype/debuerreotype
ARG           GIT_VERSION=20b4f32e93b9f0b039e2fd9fefd8527a5cb21b3e
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
RUN           cp scripts/* /usr/sbin/
RUN           cp scripts/.* /usr/sbin/ || true
COPY          ./debuerreotype-chroot /usr/sbin

# XXX note that debuerreotype does not honor apt proxy config from above, hence the exception in using http_proxy directly...
# hadolint ignore=DL4006
RUN           set -eu; \
              targetarch="$(dpkg --print-architecture | awk -F- "{ print \$NF }")"; \
              mkdir -p "/rootfs/$BUILDPLATFORM"; \
              http_proxy="$APTPROXY" debuerreotype-init --arch "$targetarch" --debian --no-merged-usr rootfs-"$targetarch" "$DEBIAN_SUITE" "${DEBIAN_DATE}T00:00:00Z"; \
              debuerreotype-minimizing-config rootfs-"$targetarch"; \
              debuerreotype-slimify rootfs-"$targetarch"; \
              debuerreotype-tar rootfs-"$targetarch" "/rootfs/$BUILDPLATFORM/debootstrap.tar"; \
              sha512sum "/rootfs/$BUILDPLATFORM/debootstrap.tar" > "/rootfs/$BUILDPLATFORM/debootstrap.sha"

FROM          scratch                                                                                                   AS rebootstrap
COPY          --from=rebootstrap-build /rootfs /rootfs

########################################################################################################################
# This is the image that will produce our final rootfs - booting off the initial rootfs obtained from above
########################################################################################################################
FROM          --platform=$BUILDPLATFORM scratch                                                                         AS debootstrap-build

# The platform we are on
ARG           BUILDPLATFORM

# What we target
ARG           DEBIAN_DATE=2020-01-01
ARG           DEBIAN_SUITE=buster

# Adding our rootfs
ADD           ./rootfs/$BUILDPLATFORM/debootstrap.tar /

# Honor proxy
ARG           APTPROXY=""
RUN           printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf
# Using snapshot, packages sig are outdated by nature
RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

# Installing qemu and debue/deboot
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                git=1:2.20.1-2+deb10u1 \
                debootstrap=1.0.114 \
                qemu-user-static=1:3.1+dfsg-8+deb10u2

# Building our rootfs on all platforms we support (armel, armhf, arm64, amd64)
WORKDIR       /bootstrapper

# 0.10
ARG           GIT_REPO=github.com/debuerreotype/debuerreotype
ARG           GIT_VERSION=20b4f32e93b9f0b039e2fd9fefd8527a5cb21b3e
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
RUN           cp scripts/* /usr/sbin/
RUN           cp scripts/.* /usr/sbin/ || true
COPY          ./debuerreotype-chroot /usr/sbin

# XXX see note above about http_proxy and debu
RUN           set -eu; \
              for targetarch in armel armhf arm64 amd64 i386 s390x ppc64el; do \
                http_proxy="$APTPROXY" debuerreotype-init --arch "$targetarch" --debian --no-merged-usr --debootstrap="qemu-debootstrap" rootfs-"$targetarch" "$DEBIAN_SUITE" "${DEBIAN_DATE}T00:00:00Z"; \
              done

RUN           set -eu; \
              for targetarch in armel armhf arm64 amd64 i386 s390x ppc64el; do \
                http_proxy="$APTPROXY" debuerreotype-apt-get rootfs-"$targetarch" update -qq; \
                http_proxy="$APTPROXY" debuerreotype-apt-get rootfs-"$targetarch" dist-upgrade -yqq; \
                debuerreotype-minimizing-config rootfs-"$targetarch"; \
                debuerreotype-slimify rootfs-"$targetarch"; \
              done

# Generate tarballs, sha, exit
RUN           mkdir -p "/rootfs/linux/arm/v6"
RUN           mkdir -p "/rootfs/linux/arm/v7"
RUN           mkdir -p "/rootfs/linux/arm64"
RUN           mkdir -p "/rootfs/linux/amd64"
RUN           mkdir -p "/rootfs/linux/386"
RUN           mkdir -p "/rootfs/linux/s390x"
RUN           mkdir -p "/rootfs/linux/ppc64el"

RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armel "/rootfs/linux/arm/v6/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-armhf "/rootfs/linux/arm/v7/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-arm64 "/rootfs/linux/arm64/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-amd64 "/rootfs/linux/amd64/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-i386 "/rootfs/linux/386/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-s390x "/rootfs/linux/s390x/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar
RUN           debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs-ppc64el "/rootfs/linux/ppc64el/${DEBIAN_SUITE}-${DEBIAN_DATE}".tar

RUN           sha512sum /rootfs/linux/*/*.tar /rootfs/linux/*/*/*.tar > /rootfs/"${DEBIAN_SUITE}-${DEBIAN_DATE}".sha

FROM          scratch                                                                                                   AS debootstrap
COPY          --from=debootstrap-build /rootfs /rootfs

########################################################################################################################
# Our final, multi-arch, Debian Buster image, using the rootfs generated in the step above
########################################################################################################################
FROM          scratch                                                                                                   AS debian

ARG           DEBIAN_DATE=2020-01-01
ARG           DEBIAN_SUITE=buster
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /

RUN           printf 'Acquire::Check-Valid-Until no;\n' > /etc/apt/apt.conf.d/99-dbdbdp-no-check-valid-until.conf

ARG           BUILD_CREATED="1976-04-14T17:00:00-07:00"
ARG           BUILD_URL="https://github.com/dubodubonduponey/nonexistent"
ARG           BUILD_DOCUMENTATION="https://github.com/dubodubonduponey/nonexistent"
ARG           BUILD_SOURCE="https://github.com/dubodubonduponey/nonexistent"
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

# Ensure that subsequent calls to apt will honor on build proxy argument
ONBUILD ARG   APTPROXY=""
ONBUILD RUN   printf 'Acquire::HTTP::proxy "%s";\n' "$APTPROXY" > /etc/apt/apt.conf.d/99-dbdbdp-proxy.conf

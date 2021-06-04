ARG           FROM_IMAGE=docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746
########################################################################################################################
# This first "debootstrap" target is meant to prepare a rootfs.
# Its starting point may be either an online Debian image, or an already existing local debian rootfs.
########################################################################################################################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $FROM_IMAGE                                                                     AS debootstrap-builder

ARG           BUILDPLATFORM
ARG           TARGETPLATFORM
ARG           TARGETARCH

# If our from is `scratch`, pass here an actual tarball (like: buster-2020-01-01.tar), that exists under context/rootfs/$BUILDPLATFORM/
ARG           FROM_TARBALL=nonexistent*

# > Boilerplate Debian options. You very likely do not need to pass these along
ARG           DEBIAN_FRONTEND="noninteractive"
ARG           TERM="xterm"
ARG           LANG="C.UTF-8"
ARG           LC_ALL="C.UTF-8"
ARG           TZ="America/Los_Angeles"

# > If the image is built from snapshot.debian.org (eg: the DEBOOTSTRAP_REPOSITORY secret has NOT been set), this will fetch from that date
ARG           DEBOOTSTRAP_DATE="2020-01-01"
# > Which Debian suite to fetch
ARG           DEBOOTSTRAP_SUITE="buster"
# > Optionally, the final content to commit to etc/apt/sources.list in the debootstrap. This is likely useful in all cases.
ARG           DEBOOTSTRAP_SOURCES_COMMIT=""

# > Optionally, packages to pre-install in the debootstrap (will honor the SOURCES_COMMIT list)
ARG           PRELOAD_PACKAGES=""
# > These packages are / not depending on whether https scheme in DEBOOTSTRAP_SOURCES_COMMIT or DEBOOTSTRAP_REPOSITORY
ARG           UNLOAD_PACKAGES="apt-transport-https openssl ca-certificates libssl1.1"

# Adding our rootfs if any
# XXX unfortunately, this might fail if the corresponding parent directory (rootfs/$BUILDPLATFORM) does not exist
# hadolint ignore=DL3020
ADD           ./rootfs/$BUILDPLATFORM/$FROM_TARBALL /

# > STEP 1: install debootstrap
# Note that apt is downgrading privs somehow somewhere and need the CA and gpg trust to have permissions for user _apt
# Also, unfortunately, when using an https proxy for http, the CA has to be system-wide (unlike when accessing directly a TLS repository)
RUN           --mount=type=secret,mode=0444,id=CA,dst=/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              set -eu; \
              apt-get update -qq && apt-get install -qq --no-install-recommends \
                debootstrap=1.0.114 \
                qemu-user-static=1:3.1+dfsg-8+deb10u2 \
                curl=7.64.0-4 \
                xz-utils=5.2.4-1

# > STEP 2: add debuerreotype
COPY          ./debuerreotype/scripts /usr/sbin/
# Copy over our deviation script
# See comments inline for reason to have this
# Note: other scripts insist in calling a script in the SAME dir, so /usr/sbin it is
COPY          ./debuerreotype-chroot  /usr/sbin/

# This is our simplified chroot for uses we control
COPY          ./dubo-chroot  /usr/sbin/

# This deviation is necessary to bypass debootstrap reliance on wget and replace with curl calls
# One of the reason to do that is that wget is unable to use a TLS proxy for http requests
COPY          ./wget  /usr/sbin/

WORKDIR       /bootstrapper

# > STEP 3: init
# XXX the repo was probably a secret for it used to embed credentials - it possibly no longer, so...
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,id=GPG \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=DEBOOTSTRAP_REPOSITORY \
              --mount=type=secret,id=CURL_OPTIONS,dst=/root/.curlrc \
              set -eu; \
              targetarch="$TARGETARCH"; \
              case "$TARGETPLATFORM" in \
                "linux/arm/v6") targetarch="armel"; ;; \
                "linux/arm/v7") targetarch="armhf"; ;; \
                "linux/ppc64le") targetarch="ppc64el"; ;; \
                "linux/386") targetarch="i386"; ;; \
              esac; \
              if [ -e /run/secrets/DEBOOTSTRAP_REPOSITORY ]; then \
                if [ -e /run/secrets/GPG_KEYRING ]; then \
                  debuerreotype-init --arch "$targetarch" --debootstrap="qemu-debootstrap" --no-merged-usr --non-debian --keyring /run/secrets/GPG_KEYRING rootfs "$DEBOOTSTRAP_SUITE" "$(cat /run/secrets/DEBOOTSTRAP_REPOSITORY)"; \
                else \
                  debuerreotype-init --arch "$targetarch" --debootstrap="qemu-debootstrap" --no-merged-usr --non-debian rootfs "$DEBOOTSTRAP_SUITE" "$(cat /run/secrets/DEBOOTSTRAP_REPOSITORY)"; \
                fi; \
              else \
                debuerreotype-init --arch "$targetarch" --debootstrap="qemu-debootstrap" --no-merged-usr --debian rootfs "$DEBOOTSTRAP_SUITE" "${DEBOOTSTRAP_DATE}T00:00:00Z"; \
              fi

# XXX cannot ditch init yet - there is still some stuff happening besides calling debootstrap
# qemu-debootstrap --arch "$targetarch" --force-check-gpg --variant=minbase --no-merged-usr "$DEBOOTSTRAP_SUITE" rootfs http://snapshot.debian.org/archive/debian/"$(printf "%s" "${DEBOOTSTRAP_DATE}T000000Z" | tr -d "-")"; \

# Adopt overlay (configuration and other fixes specifically targeted at Debian in docker)
# DANGER permissions not being right means there WILL be train wreck
COPY          ./overlay rootfs

# If we want to spoof in sources.list, do it
RUN           set -eu; \
              [ ! "${DEBOOTSTRAP_SOURCES_COMMIT:-}" ] || printf "%s\n" "$DEBOOTSTRAP_SOURCES_COMMIT" > rootfs/etc/apt/sources.list

# Certain packages may be removed. By default, we remove TLS related packages for apt, which will cause issues evidently if one expect to stick with https mirrors.
RUN           set -eu; \
              [ ! "$UNLOAD_PACKAGES" ] || dubo-chroot rootfs apt-get -qq purge --auto-remove $UNLOAD_PACKAGES || true

# Mark all packages as automatically installed
RUN           set -eu; \
              dubo-chroot rootfs apt-mark auto ".*" >/dev/null

# WATCHOUT
# Using APT_SOURCES here is not possible unfortunately, as this is also used above to retrieve qemu & debootstrap (pinned) in the initial stage
#   --mount=type=secret,id=APT_SOURCES,dst=/bootstrapper/rootfs/run/secrets/APT_SOURCES \
# The one scenario where this would be annoying is:
# - repo points to X
# - sources commit changes that to Y
# - one wants PRELOAD_PACKAGES from X, or at least from a different party than what was committed
# This overall is very unlikely, and also can be done by the implementer in a later stage / different image
# PRELOAD_PACKAGES is a mere convenience that assumes you want to pull from the final DEBOOTSTRAP_SOURCES_COMMIT or the original REPO (or snapshot)
# Furthermore, if APT_SOURCES was passed along, APT_OPTIONS reflects it... so, we have to mute it out on the command-line here.
# XXX Another one: mounting ca-certificates in the destination (which is required because of us using a proxy, means we cannot install ca-certificates (or curl)
# Ideally, it should be possible to instruct whatever http proxy subsystem apt is using to point to a different keystore
RUN           --mount=type=secret,mode=0444,id=CA,dst=/bootstrapper/rootfs/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE,dst=/bootstrapper/rootfs/run/secrets/CERTIFICATE \
              --mount=type=secret,id=KEY,dst=/bootstrapper/rootfs/run/secrets/KEY \
              --mount=type=secret,mode=0444,id=GPG,dst=/bootstrapper/rootfs/run/secrets/GPG \
              --mount=type=secret,id=NETRC,dst=/bootstrapper/rootfs/run/secrets/NETRC \
              --mount=type=secret,id=APT_OPTIONS,dst=/bootstrapper/rootfs/etc/apt/apt.conf.d/dbdbdp.conf \
              set -eu; \
              dubo-chroot rootfs apt-get -qq -o Dir::Etc::SourceList=/etc/apt/sources.list update; \
              dubo-chroot rootfs apt-get -qq -o Dir::Etc::SourceList=/etc/apt/sources.list dist-upgrade; \
              [ ! "$PRELOAD_PACKAGES" ] || { \
                dubo-chroot rootfs apt-get -qq -o Dir::Etc::SourceList=/etc/apt/sources.list install $PRELOAD_PACKAGES; \
                dubo-chroot rootfs apt-mark manual $PRELOAD_PACKAGES; \
              }; \
              dubo-chroot rootfs apt-get -qq autoremove; \
              dubo-chroot rootfs apt-get -qq clean; \
              rm -rf rootfs/var/lib/apt/lists/*; \
              rm -rf rootfs/tmp/*; \
              rm -rf rootfs/var/tmp/*

# Then slimify it
RUN           set -eu; \
              debuerreotype-slimify rootfs

# Pack it
RUN           set -eu; \
              mkdir -p "/rootfs/$TARGETPLATFORM"; \
              debuerreotype-tar --exclude="./usr/bin/qemu-*-static" rootfs "/rootfs/$TARGETPLATFORM/${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar

# Hash it
# Tricky! Every arch will do that, and the last one will have the proper shas...
# Double tricky! actually, no, because buildkit shard output directory under a plartform subdir... :/
RUN           set -eu; \
              rm -f /rootfs/debian.sha; \
              sha512sum /rootfs/*/*/*/*.tar >> /rootfs/debian.sha 2>/dev/null || true; \
              sha512sum /rootfs/*/*/*.tar >> /rootfs/debian.sha 2>/dev/null || true

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS debootstrap

COPY          --from=debootstrap-builder /rootfs /rootfs

########################################################################################################################
# Our final, multi-arch, Debian Buster image, using the rootfs generated in the step above
########################################################################################################################
FROM          scratch                                                                                                   AS debian

ARG           DEBOOTSTRAP_SUITE="buster"
ARG           DEBOOTSTRAP_DATE="2020-01-01"
ARG           TARGETPLATFORM

# Trix! Without hands!
ADD           ./cache/*/rootfs/$TARGETPLATFORM/"${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}".tar /

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

ONBUILD ARG   DEBIAN_FRONTEND="noninteractive"
ONBUILD ARG   TERM="xterm"
ONBUILD ARG   LANG="C.UTF-8"
ONBUILD ARG   LC_ALL="C.UTF-8"
ONBUILD ARG   TZ="America/Los_Angeles"

ONBUILD ARG   PRELOAD_PACKAGES=""
ONBUILD ARG   UNLOAD_PACKAGES=""

ONBUILD ARG   L3=""

# hadolint ignore=DL3008
ONBUILD RUN   --mount=type=secret,mode=0444,id=CA,dst=/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              set -eu; \
              if [ "$PRELOAD_PACKAGES" ]; then \
                apt-get update -qq; \
                apt-cache show $PRELOAD_PACKAGES; \
                apt-get install -qq --no-install-recommends $PRELOAD_PACKAGES; \
                rm -rf /var/lib/apt/lists/*; \
                rm -rf /tmp/*; \
                rm -rf /var/tmp/*; \
              fi; \
              [ ! "$UNLOAD_PACKAGES" ] || { \
                for i in $UNLOAD_PACKAGES; do \
                  apt-get -qq purge --auto-remove $i || true; \
                done; \
              }; \
              [ ! "$L3" ] || $L3

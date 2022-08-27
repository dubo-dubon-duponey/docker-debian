# FROM_REGISTRY controls the base location for the starting image for the debootstrap stage
# If set to "", the starting image will be scratch instead, and an already built local tarball will be used
#ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey
ARG           FROM_REGISTRY=docker.io
# FROM_IMAGE_BUILDER further allow changing the image name, tag and digest for the debootstrap stage
#ARG           FROM_IMAGE_BUILDER=debian@sha256:d17b322f1920dd310d30913dd492cbbd6b800b62598f5b6a12d12684aad82296
ARG           FROM_IMAGE_BUILDER=debian:bullseye-20210721-slim
# FROM_IMAGE_RUNTIME allows specifying a starting image for the final debian image (defaults to scratch)
ARG           FROM_IMAGE_RUNTIME=scratch

# Private helper
ARG           _private_df="${FROM_REGISTRY:+$FROM_REGISTRY/$FROM_IMAGE_BUILDER}"

########################################################################################################################
# The debootstrap stage is meant to prepare a Debian rootfs in the form of a tarball.
# The starting point may be either an online Debian image (as defined by FROM_REGISTRY/FROM_IMAGE_BUILDER),
# or an already existing local debian rootfs (in case FROM_REGISTRY == "")
# By default, snapshot.debian.org is being used as a source to debootstrap, for TARGET_SUITE and TARGET_DATE
# Alternatively, you can build from a private / specific Debian repository by specifying the TARGET_REPOSITORY secret
# In that case, TARGET_SUITE and TARGET_DATE are no-ops
########################################################################################################################
FROM          ${_private_df:-scratch}                                                                                   AS debootstrap-builder

# > Set a reasonable shell that fails on ALL errors
SHELL         ["/bin/bash", "-o", "errexit", "-o", "errtrace", "-o", "functrace", "-o", "nounset", "-o", "pipefail", "-c"]

# > If the image is built from snapshot.debian.org (eg: if the TARGET_REPOSITORY secret has NOT been set), this will fetch from that date
ARG           TARGET_DATE="2021-07-01"
# > Which Debian suite to fetch (same as above)
ARG           TARGET_SUITE="bullseye"

# > This is tricky: repeat ARG, so that we can access the value of FROM_IMAGE_BUILDER below
ARG           _private_df
# If _DEBOOTSTRAP_FROM is set, then set the tarball to nonexistent* (glob is here to prevent a hard error with Docker)
# Now, if there is no _DEBOOTSTRAP_FROM (which happens if FROM_REGISTRY is neutered), then use a bullseye tarball from 2021-07-01
# (that is expected to have been built)
ENV           FROM_TARBALL="${_private_df:+nonexistent*}"
ENV           FROM_TARBALL="${FROM_TARBALL:-bullseye-2021-07-01.tar}"

# > Optionally, the final content to commit to etc/apt/sources.list in the debootstrap
# If this is not set, /etc/apt/sources.list will point to either snapshot.debian.org or YOURREPO if you were using TARGET_REPOSITORY=TARGET_REPOSITORY/foo
ARG           TARGET_SOURCES_COMMIT=""
# > Optionally, packages to pre-install in the debootstrap (will be resolve using the end content of sources.list)
ARG           PRELOAD_PACKAGES=""
# > These packages are / not depending on whether https scheme in TARGET_SOURCES_COMMIT or TARGET_REPOSITORY
ARG           UNLOAD_PACKAGES="apt-transport-https openssl ca-certificates libssl1.1"
# > Boilerplate Debian options. You very likely do not need to change these
ARG           DEBIAN_FRONTEND="noninteractive"
ARG           TERM="xterm"
ARG           LANG="C.UTF-8"
ARG           LC_ALL="C.UTF-8"
ARG           TZ="America/Los_Angeles"

# > We use this to export our rootfs to the right filesystem location
ARG           TARGETPLATFORM

# Adding our rootfs if any
# hadolint ignore=DL3020
ADD           ./cache/*/$TARGETPLATFORM/$FROM_TARBALL /

# Specifying these two allows to not mind about the secret paths
ENV           CURL_HOME=/run/secrets
# NOTE: for calls where we do NOT need our overrides (purge, etc), hence where we do not mount the corresponding secrets,
# apt will issue a warning about not finding the file
ENV           APT_CONFIG=/run/secrets/APT_CONFIG
RUN           mkdir -p "$(dirname "$APT_CONFIG")"
RUN           touch "$APT_CONFIG"

# > STEP 1: install debootstrap
# Apt downgrades to _apt (uid 100) when doing the actual request
# NOTE: Using the extension .gpg is required for apt to consider it :s
# Note: debootstrapping from online non-us image means... we float on the package versions - geeeeeeeezzz
# hadolint ignore=DL3008
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && apt-get install -qq --no-install-recommends \
                debootstrap \
                curl \
                xz-utils
#                debootstrap=1.0.123 \
#                curl=7.74.0-1.2 \
#                xz-utils=5.2.5-2

# > STEP 2: add debuerreotype
COPY          ./debuerreotype/scripts /usr/sbin/

# Copy over our deviation script
# See comments inline for reason to have this
# NOTE: other scripts insist in calling a script in the SAME dir, so /usr/sbin it is
COPY          ./debuerreotype-chroot  /usr/sbin/

# This is our simplified chroot for use-cases we do control
COPY          ./dubo-chroot  /usr/sbin/

# This deviation is necessary to bypass debootstrap reliance on wget and replace with curl calls
# One of the reason to do that is that wget is unable to use a TLS proxy for http requests
COPY          ./wget  /usr/sbin/

WORKDIR       /bootstrapper

# > STEP 3: init
# FIXME this is horrific to debug, as the curl deviation may fail silently in a number of cases
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=TARGET_REPOSITORY \
              --mount=type=secret,id=.curlrc \
              ulimit -c unlimited; \
              if [ -e /run/secrets/TARGET_REPOSITORY ] && [ "$(cat /run/secrets/TARGET_REPOSITORY)" ]; then \
                if [ -e /run/secrets/GPG.gpg ]; then \
                  debuerreotype-init --no-merged-usr --non-debian --keyring /run/secrets/GPG.gpg rootfs "$TARGET_SUITE" "$(cat /run/secrets/TARGET_REPOSITORY)"; \
                else \
                  debuerreotype-init --no-merged-usr --non-debian rootfs "$TARGET_SUITE" "$(cat /run/secrets/TARGET_REPOSITORY)"; \
                fi; \
              else \
                debuerreotype-init --no-merged-usr --debian rootfs "$TARGET_SUITE" "${TARGET_DATE}T00:00:00Z"; \
              fi

# Adopt overlay (configuration and other fixes specifically targeted at Debian in docker)
# DANGER if permissions are not right in the source context, there WILL be train wreck
COPY          ./overlay rootfs

# If we want to spoof in sources.list, do it
RUN           [ ! "${TARGET_SOURCES_COMMIT:-}" ] || printf "%s\n" "$TARGET_SOURCES_COMMIT" > rootfs/etc/apt/sources.list

# Certain packages may be removed. By default, we remove TLS related packages for apt, which will cause issues evidently if one expect to stick with https mirrors.
RUN           [ ! "$UNLOAD_PACKAGES" ] || dubo-chroot rootfs apt-get -qq purge --auto-remove $UNLOAD_PACKAGES || true

# Mark all packages as automatically installed
RUN           dubo-chroot rootfs apt-mark auto ".*" >/dev/null

# NOTE
# Early on, APT_SOURCES is forcefully set by the recipe to something we can rely on for our pinned dependencies (debootstrap, curl, xz-utils), regardless of the base image being used.
# This may be old, or clearly not the right distro for the rootfs itself.
# Furthermore, since this is pointed at by apt options, we MUST override it here on the command (-o) to make sure it points to whatever was used as SOURCES_COMMIT
# The one scenario where this would be annoying is:
# - sources_commit points to Y
# - one wants PRELOAD_PACKAGES from X, different from Y (possibly the target_repository for example)
# This overall is very unlikely, and also can be done by the implementer in a later stage / different image
# PRELOAD_PACKAGES is a mere convenience that assumes you want to pull from the final TARGET_SOURCES_COMMIT or the original REPO (or snapshot)
# Also, we cannot use our normal /run/secrets/APT_CONFIG location, as the env var APT_CONFIG is NOT passed into the chroot
# Finally, we tolerate faults on apt-get update here as the commited source may not be available / working
# hadolint ignore=SC2015
RUN           --mount=type=secret,uid=100,id=CA,dst=/bootstrapper/rootfs/run/secrets/CA \
              --mount=type=secret,uid=100,id=CERTIFICATE,dst=/bootstrapper/rootfs/run/secrets/CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY,dst=/bootstrapper/rootfs/run/secrets/KEY \
              --mount=type=secret,uid=100,id=GPG.gpg,dst=/bootstrapper/rootfs/run/secrets/GPG.gpg \
              --mount=type=secret,id=NETRC,dst=/bootstrapper/rootfs/run/secrets/NETRC \
              --mount=type=secret,id=APT_CONFIG,dst=/bootstrapper/rootfs/etc/apt/apt.conf.d/dbdbdp.conf \
              dubo-chroot rootfs apt-get -qq -o Dir::Etc::SourceList=/etc/apt/sources.list update && \
              dubo-chroot rootfs apt-get -qq -o Dir::Etc::SourceList=/etc/apt/sources.list dist-upgrade || true; \
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
RUN           debuerreotype-slimify rootfs

# Pack it
RUN           mkdir -p "/rootfs/$TARGETPLATFORM"; \
              debuerreotype-tar rootfs "/rootfs/$TARGETPLATFORM/${TARGET_SUITE}-${TARGET_DATE}".tar

# Hash it
RUN           rm -f /rootfs/debian.sha; \
              sha512sum /rootfs/*/*/*/*.tar >> /rootfs/debian.sha 2>/dev/null || true; \
              sha512sum /rootfs/*/*/*.tar >> /rootfs/debian.sha 2>/dev/null || true

########################################################################################################################
# Export of the above
########################################################################################################################
FROM          scratch                                                                                                   AS debootstrap

COPY          --from=debootstrap-builder /rootfs /

########################################################################################################################
# Our final, multi-arch, Debian Buster image, using the rootfs generated in the step above
########################################################################################################################
FROM          $FROM_IMAGE_RUNTIME                                                                                       AS debian

# Our decent shell
SHELL         ["/bin/bash", "-o", "errexit", "-o", "errtrace", "-o", "functrace", "-o", "nounset", "-o", "pipefail", "-c"]

# What we want
ARG           TARGET_SUITE="buster"
ARG           TARGET_DATE="2020-07-01"
ARG           TARGETPLATFORM

# Load it!
ADD           ./cache/*/$TARGETPLATFORM/"${TARGET_SUITE}-${TARGET_DATE}".tar /

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

ENV           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm"
ENV           LANG="C.UTF-8"
ENV           LC_ALL="C.UTF-8"
ENV           TZ="America/Los_Angeles"

# Disable weak cryptography in GNUTLS
ENV           GNUTLS_FORCE_FIPS_MODE=1

# Little helper for our secrets
ENV           APT_CONFIG=/run/secrets/APT_CONFIG
RUN           touch "$APT_CONFIG"

# NOTE: this does not quite work as expected unfortunately - this cannot be overloaded in a dockerfile, but can be --build-arg-ed at build time
ONBUILD ARG   PRELOAD_PACKAGES=""
ONBUILD ARG   UNLOAD_PACKAGES=""
ONBUILD ARG   L3=""

# hadolint ignore=DL3008
ONBUILD RUN   --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              if [ "$PRELOAD_PACKAGES" ]; then \
                apt-get update -qq; \
                apt-cache show $PRELOAD_PACKAGES; \
                apt-get install -qq --no-install-recommends $PRELOAD_PACKAGES; \
              fi; \
              [ ! "$UNLOAD_PACKAGES" ] || { \
                for i in $UNLOAD_PACKAGES; do \
                  apt-get -qq purge --auto-remove $i || true; \
                done; \
              }; \
              apt-get -qq autoremove; \
              apt-get -qq clean; \
              rm -rf /var/lib/apt/lists/*; \
              rm -rf /tmp/*; \
              rm -rf /var/tmp/*; \
              [ ! "$L3" ] || $L3

CMD           ["bash"]

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# The suite and snapshot "date" from which you want to build your Debian buster image.
DEBIAN_SUITE=${DEBIAN_SUITE:-buster}
DEBIAN_DATE=${DEBIAN_DATE:-2019-11-01T00:00:00Z}

# The destination/name to use when pushing your Debian image, and the platforms you target
IMAGE_NAME="${IMAGE_NAME:-docker.io/dubodubonduponey/debian}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6}"

# In case we are starting from scratch (eg: no rootfs tarball for your platform), the docker image to start from
# - this one is the official Docker Hub Debian image
# export DEBIAN_REBOOTSTRAP="docker.io/library/debian@sha256:11253793361a12861562d1d7b15b8b7e25ac30dd631e3d206ed1ca969bf97b7d"
# - this one is our debootstrapped Debian image 2019-10-14
export DEBIAN_REBOOTSTRAP=${DEBIAN_REBOOTSTRAP:-"docker.io/dubodubonduponey/debian@sha256:68e9b2b386453c99bc3aeca7bdc448243dfe819aaa0a14dd65a0d5fdd0a66276"}

# The machine host platform on which you are building (docker syntax)
HOST_PLATFORM=linux/amd64
if command -v dpkg; then
  HOST_PLATFORM="$(dpkg --print-architecture | awk -F- "{ print \$NF }" 1>/dev/null)"
  case "$HOST_PLATFORM" in
    armhf)
      HOST_PLATFORM=linux/arm/v7
    ;;
    armel)
      HOST_PLATFORM=linux/arm/v6
    ;;
    arm64)
      HOST_PLATFORM=linux/arm64
    ;;
    *)
      >&2 printf "Unsupported architecture %s" "$HOST_PLATFORM"
    ;;
  esac
fi

# Enable docker buildx
export DOCKER_CLI_EXPERIMENTAL=enabled
# Enforce image verification if there
export DOCKER_CONTENT_TRUST=1

docker::version_check(){
  dv="$(docker version | grep "^ Version")"
  dv="${dv#*:}"
  dv="${dv##* }"
  if [ "${dv%%.*}" -lt "19" ]; then
    >&2 printf "Docker is too old and doesn't support buildx. Failing!\n"
    return 1
  fi
}

build::bootstrap::setup(){
  docker buildx create --node "dubo-dubon-duponey-debootstrap-0" --name "dubo-dubon-duponey-debootstrap" --buildkitd-flags "--allow-insecure-entitlement=security.insecure"
  docker buildx use "dubo-dubon-duponey-debootstrap"
}

build::bootstrap::rebootstrap(){
  local suite="$1"
  docker buildx build -f Dockerfile --target rebootstrap \
    --allow security.insecure \
    --build-arg "DEBIAN_REBOOTSTRAP=$DEBIAN_REBOOTSTRAP" \
    --build-arg "DEBIAN_SUITE=$suite" \
    --tag local/dubodubonduponey/rebootstrap \
    --output type=docker \
    .
  docker rm -f bootstrap 2>/dev/null || true
  export DOCKER_CONTENT_TRUST=0
  docker run --name bootstrap local/dubodubonduponey/rebootstrap true
  export DOCKER_CONTENT_TRUST=1
  docker cp bootstrap:/rootfs .
  docker rm bootstrap
}

build::bootstrap::debootstrap(){
  local suite="$1"
  local requested_date="$2"
  docker buildx build -f Dockerfile --target debootstrap \
    --allow security.insecure \
    --build-arg "DEBIAN_DATE=$requested_date" \
    --tag local/dubodubonduponey/debootstrap/"${requested_date%%T*}" \
    --output type=docker \
    .
  docker rm -f bootstrap 2>/dev/null || true
  export DOCKER_CONTENT_TRUST=0
  docker run --name bootstrap local/dubodubonduponey/debootstrap/"${requested_date%%T*}" true
  export DOCKER_CONTENT_TRUST=1
  docker cp bootstrap:/rootfs .
  docker rm bootstrap
}

build::debian::setup(){
  docker buildx create --node "dubo-dubon-duponey-debian-0" --name "dubo-dubon-duponey-debian"
  docker buildx use "dubo-dubon-duponey-debian"
}

build::debian(){
  local requested_date="$1"
  local platforms="$2"

  docker buildx build -f Dockerfile --target debian \
    --build-arg "DEBIAN_DATE=$requested_date" \
    --tag docker.io/dubodubonduponey/debian:"${requested_date%%T*}" \
    --platform "$platforms" \
    --output type=registry \
    .
}

docker::version_check

build::bootstrap::setup

if [ ! -f rootfs/"$HOST_PLATFORM"/debootstrap.sha ]; then
  >&2 printf "No basic rootfs detected. We need to bootstrap from an existing debian image from the Hub."
  build::bootstrap::rebootstrap "$DEBIAN_SUITE" "$HOST_PLATFORM"
fi

if [ ! -f rootfs/"${DEBIAN_SUITE}-${DEBIAN_DATE}".sha ]; then
  >&2 printf "Building %s rootfs for the requested target (%s)." "$DEBIAN_SUITE" "$DEBIAN_DATE"
  build::bootstrap::debootstrap "$DEBIAN_SUITE" "$DEBIAN_DATE"
fi

build::debian::setup
build::debian "$DEBIAN_DATE" "$PLATFORMS"

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Behavioral
APTPROXY="${APTPROXY:-}"
PUSH=--push
CACHE=
NO_PUSH="${NO_PUSH:-}"
NO_CACHE="${NO_CACHE:-}"
[ "$NO_PUSH" ]  && PUSH="--output type=docker"
[ ! "$NO_CACHE" ] || CACHE=--no-cache

# The suite and snapshot "date" from which you want to build your Debian buster image.
DEBIAN_SUITE="${DEBIAN_SUITE:-buster}"
DEBIAN_DATE="${DEBIAN_DATE:-2020-06-01}T00:00:00Z"

# The destination/name to use when pushing your Debian image, and the platforms you target
IMAGE_NAME="${IMAGE_NAME:-docker.io/dubodubonduponey/debian}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6}"

# In case we are starting from scratch (eg: no rootfs tarball for your platform), the docker image to start from
# - this one is the official Docker Hub Debian image
# export DEBIAN_REBOOTSTRAP="docker.io/library/debian@sha256:11253793361a12861562d1d7b15b8b7e25ac30dd631e3d206ed1ca969bf97b7d"
# - this one is our debootstrapped Debian image 2020-01-01
export DEBIAN_REBOOTSTRAP="${DEBIAN_REBOOTSTRAP:-docker.io/dubodubonduponey/debian@sha256:d78720282615fd0edbe6628058c084752e3690a7e1b0ef00b2290b74e0fff378}"

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

# The machine host platform on which you are building (docker syntax)
HOST_PLATFORM="${HOST_PLATFORM:-linux/amd64}"
if command -v dpkg; then
  HOST_PLATFORM="$(dpkg --print-architecture | awk -F- "{ print \$NF }" 2>/dev/null)"
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
    amd64)
      HOST_PLATFORM=linux/amd64
    ;;
    *)
      >&2 printf "Unsupported architecture %s\n" "$HOST_PLATFORM"
      exit
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
  docker buildx create --node "dubo-dubon-duponey-debootstrap-0" --name "dubo-dubon-duponey-debootstrap" --buildkitd-flags "--allow-insecure-entitlement=security.insecure" > /dev/null
  docker buildx use "dubo-dubon-duponey-debootstrap"
}

build::bootstrap::rebootstrap(){
  local rebootstrap_from="$1"
  local suite="$2"

  docker buildx build -f "$root"/Dockerfile --target rebootstrap \
    --allow security.insecure \
    --build-arg "DEBIAN_REBOOTSTRAP=$rebootstrap_from" \
    --build-arg "DEBIAN_SUITE=$suite" \
    --build-arg="APTPROXY=$APTPROXY" \
    --tag local/dubodubonduponey/rebootstrap \
    --output type=docker \
    ${CACHE} \
    "$root"

  docker rm -f bootstrap 2>/dev/null || true
  export DOCKER_CONTENT_TRUST=0
  docker run --name bootstrap local/dubodubonduponey/rebootstrap true
  export DOCKER_CONTENT_TRUST=1
  docker cp bootstrap:/rootfs "$root"
  docker rm bootstrap
}

build::bootstrap::debootstrap(){
  local requested_date="$1"
  local suite="$2"

  docker buildx build -f "$root"/Dockerfile --target debootstrap \
    --allow security.insecure \
    --build-arg "DEBIAN_DATE=$requested_date" \
    --build-arg "DEBIAN_SUITE=$suite" \
    --build-arg="APTPROXY=$APTPROXY" \
    --tag local/dubodubonduponey/debootstrap/"${requested_date%%T*}" \
    --output type=docker \
    ${CACHE} \
    "$root"

  docker rm -f bootstrap 2>/dev/null || true
  export DOCKER_CONTENT_TRUST=0
  docker run --name bootstrap local/dubodubonduponey/debootstrap/"${requested_date%%T*}" true
  export DOCKER_CONTENT_TRUST=1
  docker cp bootstrap:/rootfs "$root"
  docker rm bootstrap
}

build::debian::setup(){
  docker buildx create --node "dubo-dubon-duponey-debian-0" --name "dubo-dubon-duponey-debian" > /dev/null
  docker buildx use "dubo-dubon-duponey-debian"
}

build::debian(){
  local requested_date="$1"
  local platforms="$2"

  # shellcheck disable=SC2086
  docker buildx build -f "$root"/Dockerfile --target debian \
    --build-arg "DEBIAN_DATE=$requested_date" \
    --build-arg="APTPROXY=$APTPROXY" \
    --tag "$IMAGE_NAME:${requested_date%%T*}" \
    --platform "$platforms" \
    ${CACHE} ${PUSH} \
    "$root"
}

build::getsha(){
  local image_name="$1"
  local short_name=${image_name##*/}
  local owner=${image_name%/*}
  local token
  local digest

  owner=${owner##*/}
  token=$(curl https://auth.docker.io/token?service=registry.docker.io\&scope=repository%3A"${owner}"%2F"${short_name}"%3Apull  -v -L -s -H 'Authorization: ' 2>/dev/null | grep '^{' | jq -rc .token)
  digest=$(curl https://registry-1.docker.io/v2/"${owner}"/"${short_name}"/manifests/"${DEBIAN_DATE%%T*}" -L -s -I -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.docker.distribution.manifest.v2+json"  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" | grep Docker-Content-Digest)
  printf "%s\n" "${digest#*: }"
}

docker::version_check

build::bootstrap::setup

if [ ! -f "$root/rootfs/$HOST_PLATFORM/debootstrap.sha" ]; then
  >&2 printf "No local rootfs detected. We need to bootstrap from an existing debian image (currently selected: %s).\n" "$DEBIAN_REBOOTSTRAP"
  build::bootstrap::rebootstrap "$DEBIAN_REBOOTSTRAP" "$DEBIAN_SUITE"
fi

if [ ! -f "$root/rootfs/${DEBIAN_SUITE}-${DEBIAN_DATE}.sha" ]; then
  >&2 printf "Building %s rootfs for the requested target (%s).\n" "$DEBIAN_SUITE" "$DEBIAN_DATE"
  build::bootstrap::debootstrap "$DEBIAN_DATE" "$DEBIAN_SUITE"
fi

build::debian::setup
build::debian "$DEBIAN_DATE" "$PLATFORMS"

build::getsha "$IMAGE_NAME"

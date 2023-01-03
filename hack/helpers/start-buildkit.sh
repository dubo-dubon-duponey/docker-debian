#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

readonly SUITE=bullseye
readonly DATE=2023-01-01
readonly IMAGE_BLDKT="${IMAGE_BLDKT:-docker.io/dubodubonduponey/buildkit:$SUITE-$DATE}"

setup::buildkit() {
  [ "$(docker container inspect -f '{{.State.Running}}' dbdbdp-buildkit 2>/dev/null)" == "true" ]  || {
    docker run --pull always --rm -d \
      -p 4242:4242 \
      --network host \
      --name dbdbdp-buildkit \
      --env MDNS_ENABLED=true \
      --env MDNS_HOST=buildkit-machina \
      --env MDNS_NAME="Dubo Buildkit on la machina" \
      --entrypoint buildkitd \
      --user root \
      --privileged \
      "$IMAGE_BLDKT"
    docker exec --env QEMU_BINARY_PATH=/boot/bin/ dbdbdp-buildkit binfmt --install all
  }
}

setup::buildkit 1>&2 || {
  printf >&2 "Something wrong with starting buildkit\n"
  exit 1
}

printf "docker-container://dbdbdp-buildkit\n"

#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Where to put buildctl if it's not in the path
BIN_LOCATION="$HOME/Projects/Command/bin"
BUILDKIT_IMAGE="ghcr.io/dubo-dubon-duponey/buildkit"
BUILDCTL_IMAGE="dubodubonduponey/buildkit"

# shellcheck source=/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"

setup::cue(){
  if ! command -v cue > /dev/null; then
    case $(uname) in
      "Darwin")
        if command -v brew; then
          printf >&2 "You miss the cue binary. We can install that for you using brew. Press enter if you want that, CTRL+C otherwise.\n"
          read -r
          brew install cuelang/tap/cue
          return
        fi
      ;;
    esac
    echo "You need to install cue on your system: https://cuelang.org/docs/install/"
    return 1
  fi
}

setup::docker(){
  if ! command -v docker > /dev/null; then
    printf >&2 "You need to install docker on your system\n"
    return 1
  fi
}

setup::buildctl(){
  local destination="$1"
  if ! command -v "$destination/buildctl" > /dev/null; then
    setup::docker
    mkdir -p "$destination"
    docker rm -f installbuildctl || true
    # docker run --name installbuildctl --entrypoint buildctl "$BUILDCTL_IMAGE" --version
    case $(uname) in
      "Darwin")
        docker cp installbuildctl:/boot/bin/buildctl_mac "$destination/buildctl"
      ;;
      "Linux")
        docker cp installbuildctl:/boot/bin/buildctl "$destination/buildctl"
      ;;
      *)
        printf >&2 "You need to install buildctl on your system: https://github.com/moby/buildkit#quick-start and copy it in %s\n" "$destination"
        return 1
      ;;
    esac
    docker rm -f installbuildctl
  fi
}

setup::buildkit(){
  docker inspect dbdbdp-buildkit 1>/dev/null 2>&1 || \
    docker run --rm -d \
      -p 4242:4242 \
      --network host \
      --name dbdbdp-buildkit \
      --env MDNS_HOST=buildkit-mac \
      --env MDNS_NAME="Dubo Buildkit on local machine" \
      --user root \
      --privileged \
      "$BUILDKIT_IMAGE"
}

case "${1:-}" in
  "--version")
    exit
  ;;
  *)
    setup::cue
    setup::buildctl "$BIN_LOCATION"

    export BUILDKIT_HOST="${BUILDKIT_HOST:-tcp://buildkit-mac.local:4242}"

    # Setup buildkitd container optionally
    [ "${BUILDKIT_HOST:-}" != "tcp://buildkit-mac.local:4242" ] || setup::buildkit

    target="${1:-image}"
    shift || true

    cd "$root"
    com=(cue "$@" "$target" "$root/recipe.cue" "$root/cue_tool.cue")
    [ ! "${CAKE_ICING:-}" ] || com+=("$CAKE_ICING")
    echo "------------------------------------------------------------------"
    echo "Buildkit: $BUILDKIT_HOST"
    for i in "${com[@]}"; do
      if [ "${i:0:2}" == -- ]; then
        >&2 printf " %s" "$i"
      else
        >&2 printf " %s\n" "$i"
      fi
    done
    "${com[@]}" || {
      cd - > /dev/null
      echo "Execution failure"
      exit 1
    }
    cd - > /dev/null
  ;;
esac

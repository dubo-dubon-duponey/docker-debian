variable "REGISTRY" {
  default = "docker.io"
}

variable "VENDOR" {
  default = "dubodubonduponey"
}

# Date to debootstrap
variable "DEBIAN_DATE" {
  default = "2020-01-01"
}

# Suite to debootstrap
variable "DEBIAN_SUITE" {
  default = "buster"
}

# Root image to start from in case we do not even have a local rootfs
variable DEBIAN_REBOOTSTRAP {
  default = "docker.io/dubodubonduponey/debian@sha256:cb25298b653310dd8b7e52b743053415452708912fe0e8d3d0d4ccf6c4003746"
}

variable "APTPROXY" {
  default = ""
}

variable "PWD" {
  default = ""
}

group "default" {
  targets = ["debian"]
}

target "rebootstrap" {
  dockerfile = "${PWD}/Dockerfile"
  context = "${PWD}/context/rebootstrap"
  target = "rebootstrap"
  args = {
    APTPROXY = "${APTPROXY}"
    DEBIAN_REBOOTSTRAP = "${DEBIAN_REBOOTSTRAP}"
  }
  tags = []
  pull = true
  no-cache = false
  platforms = ["local"]
  output = [
    "${PWD}/context/debootstrap",
  ]
  cache-to = [
    "type=local,dest=${PWD}/cache/buildkit"
  ]
  cache-from = [
    "type=local,src=${PWD}/cache/buildkit"
  ]
}

target "debootstrap" {
  dockerfile = "${PWD}/Dockerfile"
  context = "${PWD}/context/debootstrap"
  target = "debootstrap"
  args = {
    APTPROXY = "${APTPROXY}"
    DEBIAN_SUITE = "${DEBIAN_SUITE}"
    DEBIAN_DATE = "${DEBIAN_DATE}"
  }
  tags = []
  pull = true
  no-cache = false
  platforms = ["local"]
  output = [
    "${PWD}/context/debian",
  ]
  cache-to = [
    "type=local,dest=${PWD}/cache/buildkit"
  ]
  cache-from = [
    "type=local,src=${PWD}/cache/buildkit"
  ]
}

target "debian" {
  inherits = ["shared"]
  context = "${PWD}/context/debian"
  target = "debian"
  args = {
    BUILD_TITLE = "Debian ${DEBIAN_SUITE} (${DEBIAN_DATE})"
    BUILD_DESCRIPTION = "Dubo base, from scratch, Debian image"
    DEBIAN_SUITE = "${DEBIAN_SUITE}"
    DEBIAN_DATE = "${DEBIAN_DATE}"
  }
  tags = [
    "${REGISTRY}/${VENDOR}/debian:${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
}

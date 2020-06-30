variable "REGISTRY" {
  default = "docker.io"
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

variable "PWD" {
  default = ""
}

group "default" {
  targets = ["debian"]
}

target "rebootstrap" {
  inherits = ["shared"]
  context = "${PWD}/context/rebootstrap"
  target = "rebootstrap"
  args = {
    DEBIAN_REBOOTSTRAP = "${DEBIAN_REBOOTSTRAP}"
  }
  tags = []
  platforms = ["local"]
  output = [
    "${PWD}/context/debootstrap",
  ]
}

target "debootstrap" {
  inherits = ["shared"]
  context = "${PWD}/context/debootstrap"
  target = "debootstrap"
  args = {
    DEBIAN_SUITE = "${DEBIAN_SUITE}"
    DEBIAN_DATE = "${DEBIAN_DATE}"
  }
  tags = []
  platforms = ["local"]
  output = [
    "${PWD}/context/debian",
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
    "${REGISTRY}/dubodubonduponey/debian:${DEBIAN_SUITE}-${DEBIAN_DATE}",
  ]
}

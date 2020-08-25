# Where the resulting images are going to be pushed
variable "REGISTRY" {
  default = "docker.io"
}

# Vendor name for the images to be pushed
variable "VENDOR" {
  default = "dubodubonduponey"
}

# Root image to start from in case we do not even have a local rootfs
variable "REBOOTSTRAP_IMAGE" {
  default = "docker.io/dubodubonduponey/debian@sha256:128b6ec052ca29dada299c7848b36ea7ce8413b18ee2bc1799e001e98cc117f6"
}

# What to debootstrap
variable "DEBOOTSTRAP_DATE" {
  default = "2020-01-01"
}

variable "DEBOOTSTRAP_SUITE" {
default = "buster"
}

variable "DEBOOTSTRAP_REPOSITORY" {
  default = ""
}

# Debootstrap additional options
variable "DEBOOTSTRAP_OPTIONS" {
  default = "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1"
}

variable "DEBOOTSTRAP_SOURCES" {
  default = ""
}

variable "DEBOOTSTRAP_SOURCES_COMMIT" {
  default = ""
}

variable "DEBOOTSTRAP_TRUSTED" {
  default = ""
}

variable "APT_OPTIONS" {
  default = "Acquire::HTTP::User-Agent=DuboDubonDuponey/0.1"
}

variable "APT_SOURCES" {
  default = ""
}

variable "APT_TRUSTED" {
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
  context = "${PWD}/context/debootstrap"
  target = "rebootstrap"
  args = {
    APT_OPTIONS = "${APT_OPTIONS}"
    APT_SOURCES = "${APT_SOURCES}"
    APT_TRUSTED = "${APT_TRUSTED}"
    DEBOOTSTRAP_SOURCES_COMMIT = "${DEBOOTSTRAP_SOURCES_COMMIT}"
    DEBOOTSTRAP_TRUSTED = "${DEBOOTSTRAP_TRUSTED}"
    DEBOOTSTRAP_REPOSITORY = "${DEBOOTSTRAP_REPOSITORY}"
    DEBOOTSTRAP_DATE = "${DEBOOTSTRAP_DATE}"
    DEBOOTSTRAP_SUITE = "${DEBOOTSTRAP_SUITE}"
    # For this stage, these are unused since apt is never called
    #    DEBOOTSTRAP_OPTIONS = "${DEBOOTSTRAP_OPTIONS}"
    #    DEBOOTSTRAP_SOURCES = "${DEBOOTSTRAP_SOURCES}"
    REBOOTSTRAP_IMAGE = "${REBOOTSTRAP_IMAGE}"
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
    APT_OPTIONS = "${APT_OPTIONS}"
    APT_SOURCES = "${APT_SOURCES}"
    APT_TRUSTED = "${APT_TRUSTED}"
    DEBOOTSTRAP_SOURCES_COMMIT = "${DEBOOTSTRAP_SOURCES_COMMIT}"
    DEBOOTSTRAP_TRUSTED = "${DEBOOTSTRAP_TRUSTED}"
    DEBOOTSTRAP_REPOSITORY = "${DEBOOTSTRAP_REPOSITORY}"
    DEBOOTSTRAP_DATE = "${DEBOOTSTRAP_DATE}"
    DEBOOTSTRAP_SUITE = "${DEBOOTSTRAP_SUITE}"

    DEBOOTSTRAP_OPTIONS = "${DEBOOTSTRAP_OPTIONS}"
    DEBOOTSTRAP_SOURCES = "${DEBOOTSTRAP_SOURCES}"
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
    BUILD_TITLE = "Debian ${DEBOOTSTRAP_SUITE} (${DEBOOTSTRAP_DATE})"
    BUILD_DESCRIPTION = "Dubo base, from scratch, Debian image"
    DEBOOTSTRAP_DATE = "${DEBOOTSTRAP_DATE}"
    DEBOOTSTRAP_SUITE = "${DEBOOTSTRAP_SUITE}"
  }
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
    "linux/arm/v6",
  ]
  #"linux/386",
  #"linux/s390x",
  #"linux/ppc64el",
  tags = [
    "${REGISTRY}/${VENDOR}/debian:${DEBOOTSTRAP_SUITE}-${DEBOOTSTRAP_DATE}",
  ]
}

# Roll your own Debian

Build your own Debian image from scratch.

This project heavily relies on [debuerreotype](https://github.com/debuerreotype/debuerreotype), debootstrap and qemu.

Features:
 * reproducible builds
     * a given date and Debian version always gives you the exact same resulting rootfs
 * no third-party image dependency
     * the provided builder rootfs is all you need to get started (*), and you do not need ANY Docker image from anywhere
 * proxy support for fully air-gaped build
 * depends only on the availability of `snapshot.debian.org` (*)
 * slim
     * resulting images are in the range of 25MB
 * multi-architecture
     * amd64
     * arm64
     * arm/v7
     * arm/v6
     * 386
     * s390x
     * ppc64el

(*) if your build host is linux/amd64, otherwise, you first have to build your own initial rootfs

(**) or alternatively a proxy for it

## TL;DR

If your build host is linux/amd64, you can skip this first step. Otherwise, run this once:

```bash
./build.sh rebootstrap
```

Generate rootfs from Debian Buster at a specific date, for a list of platforms:

```bash
# What you want
export DEBIAN_DATE=2020-06-01
# Your name
export VENDOR="YOU"

# Build the rootfs for all requested architectures and store them locally
./build.sh debootstrap
```

Build and push a multi-architecture docker image from these rootfs:

```bash
# What you want
export DEBIAN_DATE=2020-06-01
# Your name
export VENDOR="YOU"
# On what platforms you want it (default to all supported platforms if left unspecified):
export PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/386,linux/s390x,linux/ppc64el"

# Assemble and push Docker images from the locally stored rootfs
./build.sh debian --push
```

## Additional flags and advanced configuration

You may want to further customize the build by using any of the following:

```bash
# if you want to use a caching proxy for apt requests (http only)
APTPROXY=http://somewhere:80

# Debian version you want (provisional - only buster is tested right now)
DEBIAN_SUITE=buster
# Registry to push your final Debian image to - defaults to Docker Hub if left unspecified
REGISTRY="docker.io"
# destination image name - defaults to "debian" if left unspecified
IMAGE_NAME="debian"

# Additionally, any additional argument passed to build.sh is fed to docker buildx bake.
# Specifically you may want to use any of
#  --no-cache           Do not use cache when building the image
#  --print              Print the options without building
#  --progress string    Set type of progress output (auto, plain, tty). Use plain to show container output (default "auto")
#  --set stringArray    Override a specific target value (eg: targetpattern.key=value)
```

An advanced example:
```
DEBIAN_DATE=2020-06-01 APTPROXY=http://apt.dev.REDACTED ./build.sh --no-cache --set "debian.tags=dubodubonduponey/debian:buster-2020-06-01" --set "debian.tags=registry.dev.REDACTED/dubodubonduponey/debian:buster-2020-06-01" --push --progress plain
```

You may also (of course) entirely bypass the provided build script and use the bake files directly for further control.

## About the committed "rootfs" and the rebootstrap target

If you are on another host that linux/amd64, or just because you are (rightfully) paranoid, you may rebuild the provided rootfs by calling:

```
./build.sh rebootstrap
```

Be sure to understand what `DEBIAN_REBOOTSTRAP=XXXX` is and does (see [advanced](ADVANCED.md) documentation).

Note that running this *must* give you exactly the same result (eg: rootfs is reproducible, and the sha should always be the same).

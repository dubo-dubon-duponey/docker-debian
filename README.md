# Roll your own Debian

Build your own Debian image from scratch.

This project heavily relies on [debuerreotype](https://github.com/debuerreotype/debuerreotype), debootstrap and qemu.

Features:
 * reproducible builds
     * a given date and Debian version always gives you the exact same resulting rootfs
 * no third-party image dependency
     * the provided builder rootfs is all you need to get started (*), and you do not need ANY Docker image from anywhere
 * support for fully air-gaped build
 * depends only on the availability of `snapshot.debian.org` (**)
 * slim
     * resulting images are in the range of 25MB
 * multi-architecture
     * amd64
     * arm64
     * arm/v7
     * arm/v6
     * 386
     * s390x
     * ppc64le

(*) if your build host is linux/amd64, otherwise, you first have to build your own initial rootfs from an existing Debian image

(**) or alternatively your own Debian packages repository mirror (like aptly) / proxy (like aptutil)

## TL;DR

If your build host is linux/amd64, you can skip this first step. Otherwise (or if paranoid), run this once:

```bash
./build.sh rebootstrap
```

Generate rootfs from Debian Buster at a specific date, for all platforms:

```bash
# What you want
export DEBOOTSTRAP_DATE=2020-06-01

# Build the rootfs for all requested architectures and store them locally
./build.sh debootstrap
```

Build and push a multi-architecture docker image from these rootfs:

```bash
# What you want
export DEBOOTSTRAP_DATE=2020-06-01
# Your name
export VENDOR="YOU"
# On what platforms you want it (default to all supported platforms if left unspecified):
export PLATFORMS="linux/amd64,linux/arm64"

# Assemble and push Docker images from the locally stored rootfs
./build.sh debian --push
```

## Advanced flags

You may want to further customize the build by using any of the following:

```bash
# Registry to push your final Debian image to - defaults to Docker Hub if left unspecified
REGISTRY="docker.io"

# Additionally, any argument passed to build.sh is fed to docker buildx bake.
# Specifically you may want to use:
#  --no-cache           Do not use cache when building the image
#  --print              Print the options without building
#  --progress string    Set type of progress output (auto, plain, tty). Use plain to show container output (default "auto")
#  --set stringArray    Override a specific target value (eg: targetpattern.key=value)
```

An advanced example:
```
DEBOOTSTRAP_DATE=2020-06-01 ./build.sh --no-cache --set "debian.tags=dubodubonduponey/debian:buster-2020-06-01" --set "debian.tags=registry.dev.REDACTED/dubodubonduponey/debian:buster-2020-06-01" --push --progress plain
```

You may also (of course) entirely bypass the provided build script and use the bake files directly for further control.

For more details and advanced options, see [advanced](ADVANCED.md).

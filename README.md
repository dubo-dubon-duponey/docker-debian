# Roll your own Debian

Build your own Debian image from scratch.

Features:
 * reproducible builds
     * a given date and Debian version always gives you the exact same resulting rootfs
 * no "base" image dependency
     * the provided builder rootfs is all you need to get started, and you do not need ANY Docker image from anywhere
 * not tied to any specific registry
 * proxy support for fully air-gaped build
 * depends only on the availability of `snapshot.debian.org` (*)
 * slim
     * resulting images are in the range of 25MB
 * multi-architecture
     * amd64
     * arm64
     * arm/v7
     * arm/v6

(*) or alternatively a proxy for it

This project heavily relies on [debuerreotype](https://github.com/debuerreotype/debuerreotype), debootstrap and qemu.

## TL;DR

Assuming you are on linux/amd64 (yes, Docker for Mac).

```bash
# What you want
DEBIAN_DATE=2020-06-01
# Your name
VENDOR="YOU"

# Build all the requested rootfs and store them locally
./build.sh debootstrap

# Assemble and push Docker images from the locally stored rootfs
./build.sh debian
```

## Additional flags

You may want to use any of the following:

```
# if you want to use a caching proxy for apt requests (http only)
APTPROXY=http://somewhere

# Debian version you want
DEBIAN_SUITE=buster
# destination for your final Debian image - defaults to Docker Hub if left unspecified
REGISTRY="docker.io"
# destination image name - defaults to "debian" if left unspecified
IMAGE_NAME="debian"
# platforms you are interested in (default as listed)
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

# Additionally, any additional argument passed to build.sh is fed to docker buildx bake.
# Specifically you may want to use any of
#  --no-cache           Do not use cache when building the image
#  --print              Print the options without building
#  --progress string    Set type of progress output (auto, plain, tty). Use plain to show container output (default "auto")
#  --set stringArray    Override target value (eg: targetpattern.key=value)

```

## About the committed "rootfs"

If you are on another host that linux/amd64, or just because you are (rightfully) paranoid, you may rebuild the provided rootfs by calling:

```
./build.sh rebootstrap
```

Be sure to understand what `DEBIAN_REBOOTSTRAP=XXXX` is and does.

Note that running this *must* give you exactly the same result (eg: sha of the rootfs never changes).

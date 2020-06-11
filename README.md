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

This project makes use of [debuerreotype](https://github.com/debuerreotype/debuerreotype), debootstrap and qemu.

## TL;DR

```bash
# What you want
DEBIAN_DATE=2020-01-01
# Your name
VENDOR="YOU"

# Optional - defaults to Docker Hub otherwise
# REGISTRY="myregistry.foo"
# Optional - defaults to "debian"
# IMAGE_NAME="foofoo"

# Platforms you are interested in
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

# Build
./build.sh
```

## Additional flags

You may want to tweak the following:

```
# if you want to use a caching proxy for apt requests (http only)
APTPROXY=http://somewhere

# if you just want to build locally and not push the resulting image to a registry at all
# note that in that case you need to restrict PLATFORMS to your host architecture 
NO_PUSH=true

# if you want to bust the Docker cache while building
# note that this does not bypass locally cached artifacts
# if you want a true from scratch rebuild, delete the rootfs folder
NO_CACHE=true
```

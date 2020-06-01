# Roll your own Debian

Build your own Debian Buster images from scratch.

Features:
 * [x] reproducible builds
 * [x] no "base" image dependency
 * [x] not tied to any specific registry
 * [x] depends only on the availability of `snapshot.debian.org`
 * [x] slim: ~25MB
 * [x] multi-architecture
     * [x] amd64
     * [x] arm64
     * [x] arm/v7
     * [x] arm/v6

## TL;DR

```bash
# What you want
DEBIAN_DATE=2020-01-01
# "Where" to push it
IMAGE_NAME=yourregistry/you/debian
# Platforms you are interested in
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"

./build.sh
```

## How does this work in detail?

### rootfs

The purpose of the first stage is solely to generate a viable, local Debian rootfs for your host platform - it only runs if there is locally available rootfs.

If you checked out this repository without modification, and assuming you are on amd64, this will not run, since a rootfs is provided already (under `rootfs/linux/platform/debootstrap.tar`).

Though, even in that case, we encourage you to delete it and rebuild it, then verify the sha is still the same:
`37b44e53477829775dbe19f5cc752229697996923a6e02cf51443360f63eb409ec9cf2767b66afed28e1191fa291b2b2d408e8cc8e66d40c653fc105a4bc2d07`

In order to generate this first rootfs, you do need an existing Debian Buster image.
You may use Docker official image, our own Debian image (default), or any other base Debian image.

To specify which image you want to use, set `DEBIAN_REBOOTSTRAP` (for example: `DEBIAN_REBOOTSTRAP=debian:buster-slim`) before calling `./build.sh`.

Whatever this "bootstrapping" image is, the resulting sha should always be the same.

### Stage-1

Once you have the first rootfs from above for your host platform (debootstrap.tar), you can now generate the final rootfs for all desired platforms, without any dependency on an external registry or image.

They will be stored under the rootfs folder.

Their sha should NEVER vary (unless you change the requested date).

### Stage-2 Debian multi-arch image

The final stage is as simple as:

```bash
FROM          scratch                                                                                                   AS debian

ARG           DEBIAN_DATE=2020-01-01T00:00:00Z
ARG           DEBIAN_SUITE=buster
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /
```

And will produce Debian images with a consistent sha.

Please note that apt sources list is left pointing at `snapshot.debian.org` for the requested date.

What this means is that your image will NOT receive updates of any kind from apt in the future.
It is pinned at a specific point in the past that you decide on at build time.
If you want updates, it is expected that you rebuild the image later on with a more recent date.

Of course you may change this by editing the `sources.list` file to point to the live Debian archive.

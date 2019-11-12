# Roll your own Debian

Build your own, reproducible Debian Buster base images from scratch, depending only on `snapshot.debian.org`.

## TL;DR

```bash
DEBIAN_DATE=2019-11-01T00:00:00Z
IMAGE_NAME=yourregistry/you/debian
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"
./build.sh 
```

## How does this work in detail?

### Stage-1 rootfs

The purpose of the first stage image is solely to generate a viable Debian rootfs for your host platform.

We do provide one already for amd64 (`rootfs/linux/platform/debootstrap.tar`), but encourage you to delete it and rebuild it, then verify the sha did not change:
`37b44e53477829775dbe19f5cc752229697996923a6e02cf51443360f63eb409ec9cf2767b66afed28e1191fa291b2b2d408e8cc8e66d40c653fc105a4bc2d07`

In order to generate this first rootfs, you do need an existing Debian Buster image.
You may use Docker official image, our own Debian image (default), or any other base Debian image.

To specify which image you want to use, set `DEBIAN_REBOOTSTRAP` before calling `./build.sh`.

Whatever this image is, the resulting sha should always be the same.

### Stage-2

Once you have the first rootfs from above for your host platform (debootstrap.tar), you can now generate the final rootfs for all desired platforms.

They will be stored under the rootfs folder.

Their sha should NEVER vary (unless you change the requested date).

### Stage-3 Debian multi-arch image

The final stage is as simple as:

```bash
FROM          scratch                                                                                                   AS debian

ARG           DEBIAN_DATE=2019-11-01T00:00:00Z
ARG           DEBIAN_SUITE=buster
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /
```

And will produce Debian images with a consistent sha.

Please note that apt sources list is left pointing at snapshot.debian.org for the requested date.

What this means is that your image will NOT receive updates of any kind from apt in the future.
It is pinned at a specific point in the past that you decide on at build time.
If you want updates, it is expected that you rebuild the image later on with a more recent date.

Of course you may change this by editing the sources.list file to point to the live Debian archive.

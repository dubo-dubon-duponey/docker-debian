# Roll your own Debian

Build your own, reproducible Debian Buster base images from scratch, depending only on `snapshot.debian.org`.

## TL;DR

```
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

They will be stored undeer 
What about the debootstrap.tar file?


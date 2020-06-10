# Moar

## How does this work in detail?

### rootfs

The purpose of the first stage is solely to generate a viable, local Debian rootfs for your host platform. It only runs if there is no locally available rootfs.
 
If you checked out this repository without modification, and assuming you are on amd64, this will not run, since a rootfs is provided already (under `rootfs/linux/amd64/debootstrap.tar`).

Though, even in that case, we encourage you to delete it and rebuild it, then verify the sha is unchanged:
`37b44e53477829775dbe19f5cc752229697996923a6e02cf51443360f63eb409ec9cf2767b66afed28e1191fa291b2b2d408e8cc8e66d40c653fc105a4bc2d07`

In order to generate this first rootfs, you do need an existing Debian Buster image.
You may use Docker official image, our own Debian image (default), or any other base Debian image.

To specify which image you want to use in that stage, set `DEBIAN_REBOOTSTRAP` (for example: `DEBIAN_REBOOTSTRAP=debian:buster-slim`) before calling `./build.sh`.

Whatever this "bootstrapping" base image is, the resulting sha should always be the same.

### Stage-1

Once you have the base rootfs from above for your host platform (debootstrap.tar), you can now generate the final rootfs for all desired platforms, without any dependency on an external registry or image.

They will be stored under the `rootfs` folder.

Their sha should NEVER vary (unless you change the requested date), and they are cached locally.

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

What this means is that your image will NOT receive updates from apt in the future.
It is pinned at a specific point in the past that you decide on at build time.
If you want updates, it is expected that you rebuild the image later on with a more recent date.

Of course you may change this by editing the `sources.list` file to point to the live Debian archives.

## Caveats

### Host platform

Host platform detection only works on Debian based distros.

On all other platforms, including macos, it will default to `linux/amd64`.

If you want to build on a host that is not amd64, and you are not on a Debian derivative, set the env variable HOST_PLATFORM to the desired architecture.

### Support

This is used regularly on macos (on amd64).

Support for other OSes and architectures is largely untested, but bring it on if you have issues.

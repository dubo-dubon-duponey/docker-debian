# Moar

## How does this work in detail?

### Stage-0 (target "rebootstrap")

The purpose of this first step is solely to generate a viable, local Debian rootfs for your host platform.
This typically should only be ran once.

If you checked out this repository without modification, and assuming you are on amd64, a working rootfs is provided already (under `context/debootstrap/rootfs/linux/amd64/debootstrap.tar`).

Though, even in that case, we encourage you to delete it and rebuild it, then verify the sha is unchanged:
`02ff894af506ddbc2f22b7227822e6d052b24e7fbc8ce09a3ec1c5274b626a7147913bba3bcf13d6fb1330609a608ed724b98806f3d3f715164d9c70d461cec1`

In order to generate this first rootfs, you do need an existing Debian Buster image.
You may use Docker official image, our own Debian image (this is the default), or any other base Debian image.

To specify which image you want to use, set `DEBIAN_REBOOTSTRAP` (for example: `DEBIAN_REBOOTSTRAP=debian:buster-slim`) before calling `./build.sh`.

Whatever this "bootstrapping" base image is, the resulting sha should always be the same.

### Stage-1 (target "debootstrap")

Once you have the base rootfs from above for your host platform (`debootstrap.tar`), you can now generate the final rootfs for all desired platforms, without any dependency on an external registry or image.

They will be stored under the `context/debian/rootfs` folder.

Their sha should NEVER vary (unless you change the requested date).

### Stage-2 (target "debian" and default)

The final stage is as simple as:

```bash
FROM          scratch                                                                                                   AS debian

ARG           DEBIAN_DATE=2020-01-01T00:00:00Z
ARG           DEBIAN_SUITE=buster
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /
```

And will produce Debian images from the stage-1 rootfs.

Please note that apt sources list is left pointing at `snapshot.debian.org` for the requested date.

What this means is that your image will NOT receive updates from apt in the future.
It is pinned at a specific point in the past that you decide on at build time.
If you want updates, it is expected that you rebuild the image later on with a more recent date.

Of course you may change this by editing the `sources.list` file to point to the live Debian archives.

## Caveats

### About cache and build context

The `context/debian/rootfs` folder is part of Docker build context for the final stage.

As such, if it grows really big (with many different versions), the last stage will become slower.

It is recommended to clean-up this folder from older / useless versions from time to time to avoid such adverse side-effects.

### Support

This is used regularly on macOS (intel).

Support for other OSes and architectures is largely untested, but bring it on if you have issues.

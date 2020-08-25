# Moar

## How does this work in detail?

### Stage-0 (target "rebootstrap")

```bash
./build.sh rebootstrap
```

The purpose of this first step is solely to generate a viable, local Debian rootfs for your host platform.
This typically should only be ran once.

If you checked out this repository without modification, and assuming you are on amd64, a working rootfs is provided already (under `context/debootstrap/rootfs/linux/amd64/debootstrap.tar`).

If you are happy with that, you can skip that stage entirely.

Though, we encourage you to delete it and rebuild it if you are reasonably paranoid.

In order to do so, you **do need** an existing Debian Buster image to build on.
By default, we point to our own Debian image.
You may also use Docker official image, or any other base Debian image.

To override the default for this image, set `REBOOTSTRAP_IMAGE` (for example: `REBOOTSTRAP_IMAGE=debian:buster-slim`) before calling `./build.sh`.

Whatever this "bootstrapping" base image is, the resulting sha should always be the same for the generated rootfs.

Please note though that packages versions are pinned in the Dockerfile (specifically `debootstrap` and `qemu`).
Depending on the base Debian image you select to rebuild, you may have to change these versions.

#### Fully air-gap scenario

To build the stage-0 rootfs fully offline, you need to have, inside the airgap, a suitable Debian image hosted on a local registry, and a Debian packages mirror.

```bash
# Set `REBOOTSTRAP_IMAGE` to your base debian image stored on a local registry
export REBOOTSTRAP_IMAGE="registry.local/you/debian:something"

# set `APT_SOURCES` to point to a local debian mirror (this is solely for the purpose of pulling in the debootstrap package in the builder image)
export APT_SOURCES="deb http://u:p@apt.local:8080/archive/buster/20200811T000000Z/ buster main"`

# set `DEBOOTSTRAP_REPOSITORY` to point to the local debian mirror from which you want to debootstrap
# this of course can be the same as above, or a different mirror
export DEBOOTSTRAP_REPOSITORY=http://u:p@apt.local:8080/archive/buster/20200811T000000Z/`

# build...
./build.sh rebootstrap
```

You may optionnally specify any of the following:

```bash

# APT_OPTIONS controls the behavior of apt in the builder image through space separated options, for further custom setups (ignoring expiracy, using a proxy, etc)
# Example, set the user-agent string:
export APT_OPTIONS="Acquire::HTTP::User-Agent=DuboDubonDuponey-APT/0.1"

# DEBOOTSTRAP_SOURCES_COMMIT will permanently overwrite /etc/apt/sources.list inside the rootfs
# if left unspecified, it will default instead to your DEBOOTSTRAP_REPOSITORY from above, which may be a problem for consumers of your image if they do not have access to your local mirror
# Example, force-pointing to debian snapshot
export DEBOOTSTRAP_SOURCES_COMMIT="deb http://snapshot.debian.org/archive/debian/2020-01-01T000000Z buster main"

# If you have signed your local Debian repository, you should specify your key for apt and debootstrap to trust it
APT_TRUSTED="$(base64 trusted.gpg)"
DEBOOTSTRAP_TRUSTED="$(base64 trusted.gpg)"

# trusted.gpg can be generated out of band using apt-key, typically with something like
# apt-key add public-key-used-to-sign-your-repo.gpg
# ... will generate a trusted.gpg file in /etc/apt that you can use
```

### Stage-1 (target "debootstrap")

```bash
./build.sh debootstrap
```

Once you have the base rootfs from above for your host platform (under `context/debootstrap/rootfs/linux/ARCH/debootstrap.tar`),
you can now start generating final rootfs for all desired platforms, without any dependency on an external registry or image.

The final rootfs will be stored under the `context/debian/rootfs` folder.

Their sha should NEVER vary (unless you change the requested date).

#### Fully air-gap scenario

Similarly to above, you need, inside the airgap, a Debian packages mirror.

```bash
# set `APT_SOURCES` to point to a local debian mirror (this is solely for the purpose of pulling in the debootstrap and qemu packages in the builder image)
export APT_SOURCES="deb http://u:p@apt.local:8080/archive/buster/20200811T000000Z/ buster main"`

# set `DEBOOTSTRAP_REPOSITORY` to point to the local debian mirror from which you want to debootstrap
# this of course can be the same as above, or a different mirror
export DEBOOTSTRAP_REPOSITORY=http://u:p@apt.local:8080/archive/buster/20200811T000000Z/`

# also set `DEBOOTSTRAP_SOURCES` to be used by the debootstrapped apt (for update and upgrade)
export DEBOOTSTRAP_SOURCES="deb http://u:p@apt.local:8080/archive/buster/20200811T000000Z/ buster main"`

# build...
./build.sh
```

You may optionnally specify any of the following:

```bash

# APT_OPTIONS controls the behavior of apt in the builder image through space separated options, for further custom setups (ignoring expiracy, using a proxy, etc)
# Example, set the user-agent string:
export APT_OPTIONS="Acquire::HTTP::User-Agent=DuboDubonDuponey-APT/0.1"

# Similarly DEBOOTSTRAP_OPTIONS will control apt behavior inside the chroots
export DEBOOTSTRAP_OPTIONS="Acquire::HTTP::User-Agent=DuboDubonDuponey-DEBOOT/0.1"

# DEBOOTSTRAP_SOURCES_COMMIT will permanently overwrite /etc/apt/sources.list inside the final rootfs
# if left unspecified, it will default instead to your DEBOOTSTRAP_REPOSITORY from above, which may be a problem for consumers of your image if they do not have access to your local mirror
# Example, force-pointing to debian snapshot
export DEBOOTSTRAP_SOURCES_COMMIT="deb http://snapshot.debian.org/archive/debian/2020-01-01T000000Z buster main
deb http://snapshot.debian.org/archive/debian-security/2020-01-01T000000Z buster/updates main
deb http://snapshot.debian.org/archive/debian/2020-01-01T000000Z buster-updates main"

# If you have signed your local Debian repository, you should specify your key for apt and debootstrap to trust it
APT_TRUSTED="$(base64 trusted.gpg)"
DEBOOTSTRAP_TRUSTED="$(base64 trusted.gpg)"

# trusted.gpg can be generated out of band using apt-key, typically with something like
# apt-key add public-key-used-to-sign-your-repo.gpg
# ... will generate a trusted.gpg file in /etc/apt that you can use
```


### Stage-2 (target "debian" and default)

The final stage is as simple as:

```bash
FROM          scratch                                                                                                   AS debian

ARG           DEBOOTSTRAP_SUITE=buster
ARG           DEBOOTSTRAP_DATE=2020-01-01
ARG           TARGETPLATFORM

ADD           ./rootfs/$TARGETPLATFORM/"${DEBIAN_SUITE}-${DEBIAN_DATE}".tar /
```

And will produce Debian images from the stage-1 rootfs.

Please note that (for the default behavior), apt sources list is left pointing at `snapshot.debian.org` for the requested date.

What this means is that your image will NOT receive updates from apt in the future.
It is pinned at a specific point in time that you decide on at build time.
If you want updates, it is expected that you rebuild the image later on with a more recent date.

Of course you may change this by editing the `sources.list` file to point to the live Debian archives.
Alternatively, use `DEBOOTSTRAP_SOURCES_COMMIT` above during stage 1.

## Caveats

### About cache and build context

The `context/debian/rootfs` folder is part of Docker build context for the final stage.

As such, if it grows really big (with many different versions), the last stage will become slower.

It is recommended to clean-up this folder from older / useless versions from time to time to avoid such adverse side-effects.

### Support

This is used regularly on macOS (intel).

Support for other OSes and architectures is not tested daily, but bring it on if you have issues.

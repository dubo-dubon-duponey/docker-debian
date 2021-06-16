# Roll your own Debian

Build your own Debian image from scratch.

Features:
 * reproducible builds
     * a given date and Debian suite always gives you the exact same resulting rootfs
 * no third-party image dependency
     * once you have a local rootfs tarball, you do not need ANY Docker image from anywhere to debootstrap any supported Debian (buster, bullseye, sid)
 * support for fully air-gaped build (granted you have a local debian repository mirror)
 * depends only on the availability of `snapshot.debian.org` (or that of your proxy / mirror)
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

## Important

Be nice to the Debian infrastructure: run your own Debian packages repository mirror (like aptly), or a proxy (like aptutil)

## TL;DR

Build

```
./hack/build.sh debootstrap --inject target_date=2021-06-01 --inject target_suite=bullseye
```

Assemble and push

```
./hack/build.sh debian --inject tags=registry.com/name/image:tag
```

## Configuration

You can control additional aspects of the build injecting more parameters

```
# Online, from a bullseye image, with caching into a registry, building only armv6
./hack/build.sh debootstrap \
  --inject target_date="2021-06-01" \
  --inject target_suite="bullseye" \
  --inject from_image="ghcr.io/dubo-dubon-duponey/debian:bullseye-2021-06-01" \
  --inject from_tarball="nonexistent*" \
  --inject platforms="linux/arm/v6" \
  --inject directory=./context/rootfs \
  --inject cache_base=type=registry,ref=somewhere.com/cache/debian:debian

# Offline, from a previously built rootfs, building only armv6
./hack/build.sh debootstrap \
  --inject target_date="2021-06-01" \
  --inject target_suite="bullseye" \
  --inject from_image="scratch" \
  --inject from_tarball="bullseye-2021-06-01.tar" \
  --inject platforms="linux/arm/v6" \
  --inject directory=./context/rootfs

```

### Dependencies

The hack scripts should take care of installing what you need.

That said, or in case that would fail, you do need:

 * a working buildkit daemon
 * cue
 * buildctl

If you need to manually start a buildkit daemon:

```bash
docker run --rm -d \
      --name bldkt \
      --user root \
      --privileged \
      --entrypoint buildkitd \
      ghcr.io/dubo-dubon-duponey/buildkit

export BUILDKIT_HOST=docker-container://bldkt
```

If you need to install `cue`, or `buildctl` (on mac):

```bash
brew install cuelang/tap/cue
brew install buildkit
```

## Advanced stuff

This project relies largely on [debuerreotype](https://github.com/debuerreotype/debuerreotype),
[debootstrap](https://wiki.debian.org/Debootstrap), [qemu](https://www.qemu.org/),
[cue](https://cuelang.org/), and [buildkit](https://github.com/moby/buildkit).

See [advanced](ADVANCED.md).

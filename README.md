# Roll your own Debian

Build your own Debian image from scratch.

This project relies on [debuerreotype](https://github.com/debuerreotype/debuerreotype), [debootstrap](https://wiki.debian.org/Debootstrap), [qemu](https://www.qemu.org/), [cue](https://cuelang.org/), and [buildkit](https://github.com/moby/buildkit).

Features:
 * reproducible builds
     * a given date and Debian suite always gives you the exact same resulting rootfs
 * no third-party image dependency
     * the provided tarball is all you need to get started, and you do not need ANY Docker image from anywhere
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

Notes:

 * if your build host is not `linux/amd64` and is not multi-arch enabled, you will first have to build your own initial rootfs from an existing Debian image.
 * be nice to the Debian people infrastructure: have yourself a Debian packages repository mirror (like aptly), or a proxy (like aptutil), and use that

## TL;DR

You need:

 * a working buildkit daemon, and `BUILDKIT_HOST` pointing to it
 * `cue`
 * `buildctl`

Check the dependencies section if unsure.

### Building your own local tooling rootfs

If your build host is `linux/amd64`, and you are not paranoid, skip this step.

Otherwise, run this once to rebuild your own local, base rootfs, starting from an official Debian image:

```bash
# Be sure to point this to your buildkit daemon
# 
make retool
```

### Building a debootstrapped Debian image

```bash
TARGET_DATE=2020-06-01 TARGET_SUITE=buster make build
```

If everything went fine, it will build, but then fail to push. Just tell it "where" you want it:

```
EXTRAS="--inject tags=you/debian" TARGET_DATE=2020-06-01 TARGET_SUITE=buster make build
```

### Dependencies

Run this to check your system:

```bash
command -v cue > /dev/null || {
  echo >&2 "You need to install cue"
  exit 1
}

command -v buildctl > /dev/null || {
  echo >&2 "You need to install buildctl"
  exit 1
}

command -v buildctl > /dev/null || {
  echo >&2 "You need to install buildctl"
  exit 1
}

buildctl debug workers || {
  echo >&2 "Cannot contact the buildkit daemon. Is it running? If so, did you point BUILDKIT_HOST to it?"
  exit 1
}
```

If you need to start a buildkit daemon, you can:

```bash
docker run --rm -d \
      -p 4242:4242 \
      --network host \
      --name dbdbdp-buildkit \
      --user root \
      --privileged \
      ghcr.io/dubo-dubon-duponey/buildkit

export BUILDKIT_HOST=tcp://127.0.0.1:4242
```

If you need to install `cue` and `buildctl` (on mac):

```bash
brew install cuelang/tap/cue
brew install buildkit
```

## Advanced stuff

See [advanced](ADVANCED.md).


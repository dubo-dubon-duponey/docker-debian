# Roll your own Debian

Build your own Debian image from scratch.

Features:
 * reproducible builds
   * a given date and Debian suite always gives you the exact same resulting rootfs
 * no third-party image dependency
   * once you have a local rootfs tarball, you do not need ANY Docker image from anywhere to debootstrap
 * support for fully air-gaped build (granted you have a local debian repository mirror)
 * depends only on the availability of `snapshot.debian.org` (or that of your proxy / mirror)
 * slim
   * resulting images are in the range of 25MB
 * multi-architecture
   * amd64
   * 386
   * arm64
   * arm/v7
   * arm/v6
   * s390x
   * ppc64le

## Important

Be nice to the Debian infrastructure: run your own Debian packages repository mirror (like aptly), or a proxy (like aptutil)

## TL;DR

Point to your buildkit host or use the helper to start one

```bash
export BUILDKIT_HOST=$(./hack/helpers/start-buildkit.sh 2>/dev/null)
```

Build

```bash
./hack/build.sh debootstrap \
  --inject date="2021-08-01" \
  --inject suite="bullseye"
```

Assemble and push

```bash
./hack/build.sh debian \
  --inject date="2021-08-01" \
  --inject suite="bullseye" \
```

Note that the above will by default try to push to `ghcr.io/dubo-dubon-duponey/debian`.
Edit `recipe.cue`, or better, use an `env.cue` file (see [advanced](ADVANCED.md) for that) to control
the push destination.

## Configuration

You can control additional aspects of the build passing arguments:

Building a subset of architectures:
```bash
./hack/build.sh debootstrap \
  --inject date="2021-08-01" \
  --inject suite="bullseye" \
  --inject platforms="linux/arm/v6"
```

Building from a private debian repository instead:
```bash
./hack/build.sh debootstrap \
  --inject date="2021-08-01" \
  --inject suite="bullseye" \
  --inject repository="https://private.deb.repo/debian/foo/bar"
```

Building offline:

```bash
# If you want to build "offline", you first need to build the required local rootfs (once, online):
./hack/build.sh debootstrap

# Now, you can build without access to a registry
./hack/build.sh debootstrap \
  --inject date="2021-08-01" \
  --inject suite="bullseye" \
  --inject registry=""

# You can further control networking and other build aspect through a cue environment (see ADVANCED)
```

### Dependencies

The hack scripts should take care of installing what you need.

That said, or in case that would fail, you do need:

* a working buildkit daemon, that you can point to by specifying `BUILDKIT_HOST`
* cue
* buildctl
* hadolint
* shellcheck

## Advanced stuff

See [advanced](ADVANCED.md) for more.

# TODO

P0:
* client TLS authentication
* streamline end-user experience and overrides
* [WIP] update CI (busted right now)
* [WIP] qemu has a weird bug when debootstrapping bullseye/sid with base online images (but not when using a rootfs)

P1:
 * Cache:
    * support ability to have no cache
    * support for multi-cache
 * `TARGET_REPOSITORY` support
 * use the --addr flag of buildctl (buildctl --addr tcp://10.0.4.218:4242 debug workers)
 * enable curl using tlsv1.3 = true and proto '=https' in curl config
 * debuerreotype-fixup bust because of touch failing on /dev/* - is this due to aggressive set -eu calls before tar?
 * [UNCLEAR] entertain emstrap / debootstrap alternatives (google debootstrap qemu / multi arch) (or is it a qemu problem?)
 * investigate replacing debootstrap with https://wiki.debian.org/Multistrap

P2:
 * add linux/riscv64?

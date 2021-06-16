# TODO

P0:
* client TLS authentication
* streamline end-user experience and overrides
* update CI (busted right now)
* debian 9 is not working anymore with recent (bullseye) qemu

P1:
 * Cache:
    * support ability to have no cache
    * support for multi-cache
 * `TARGET_REPOSITORY` support
 * use the --addr flag of buildctl (buildctl --addr tcp://10.0.4.218:4242 debug workers)
 * enable curl using tlsv1.3 = true and proto '=https' in curl config
 * debuerreotype-fixup bust because of touch failing on /dev/* - is this due to aggressive set -eu calls before tar?
 * entertain emstrap / debootstrap alternatives (google debootstrap qemu / multi arch)
 * https://wiki.debian.org/Multistrap

P2:
 * add linux/riscv64?

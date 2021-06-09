# TODO

 * support for multi-cache
 * `TARGET_REPOSITORY` support
 * client TLS authentication
 * streamline end-user experience and overrides
 * update CI (busted right now)
 * use the --addr flag of buildctl (buildctl --addr tcp://10.0.4.218:4242 debug workers)
 * debian 9 is not working anymore with recent (bullseye) qemu
 * enable curl using tlsv1.3 = true and proto '=https'
 * currently, one cannot have no cache at all
 * add linux/riscv64
 * debuerreotype-fixup bust because of touch failing on /dev/* - probably due to a set -eu call before tar

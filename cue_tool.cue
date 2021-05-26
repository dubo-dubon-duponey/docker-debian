package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
)

// This defines our targets for this specific repository:
// A. "retool_from": rebuild our tooling rootfs from an online image
// This is useful solely if:
//   	- your building architecture is NOT amd64 AND you cannot your buildkit is not multi-arch enabled
//		- you do not trust the provided rootfs (you should not)
// b. "retool_local": this is the same thing as above, except it uses the provided rootfs
// This is useful:
//		- probably never
// c. "debootstrap": build a set of final rootfs for a target suite and date, from a local tooling rootfs
// This is what you want to do
// d. "debian": generate and push a final, usable, debian image from the debootstrapped rootfs
// This is what you want to do just after the above

command: {
	debootstrap: scullery.#Oven & {
		cake: cakes.debootstrap
		no_cache: *false | bool @tag(no_cache,type=bool)
   	progress: *types.#Progress.#AUTO | string @tag(progress,type=string)
	}
	debian: scullery.#Oven & {
		cake: cakes.debian
		no_cache: *false | bool @tag(no_cache,type=bool)
   	progress: *types.#Progress.#AUTO | string @tag(progress,type=string)
	}
}


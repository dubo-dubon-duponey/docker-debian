package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

// XXX WIP: clearly the injector is defective at this point and has to be rethought
// It's probably a better approach to hook it into the recipe, or the env to avoid massive re-use problems

// Entry point if there are environmental definitions
UserDefined: scullery.#Icing

// XXX unfortunately, you cannot have tags in imported packages, so this has to be hard-copied here

defaults: {
	tags: [
		types.#Image & {
			registry: "push-registry.local"
 			image: "dubo-dubon-duponey/debian"
			tag: cakes.debian.recipe.process.args.DEBOOTSTRAP_SUITE + "-" + cakes.debian.recipe.process.args.DEBOOTSTRAP_DATE
		},
		types.#Image & {
			registry: "push-registry.local"
			image: "dubo-dubon-duponey/debian"
			tag: "latest"
		},
		types.#Image & {
   		registry: "ghcr.io"
   		image: "dubo-dubon-duponey/debian"
   		tag: cakes.debian.recipe.process.args.DEBOOTSTRAP_SUITE + "-" + cakes.debian.recipe.process.args.DEBOOTSTRAP_DATE
   	},
		types.#Image & {
			registry: "ghcr.io"
			image: "dubo-dubon-duponey/debian"
			tag: "latest"
		}
	],
	cacheTo: types.#CacheTo & {
		type: types.#CacheType.#LOCAL
		location: "./cache/buildkit"
	}
	cacheFrom: types.#CacheFrom & {
		type: types.#CacheType.#LOCAL
		location: "./cache/buildkit"
	}
	platforms: [
		types.#Platforms.#AMD64,
		types.#Platforms.#ARM64,
		types.#Platforms.#V7,
		types.#Platforms.#V6,
		types.#Platforms.#PPC64LE,
		types.#Platforms.#S390X,
		types.#Platforms.#I386,
	]
	suite: "buster"
	date: "2020-01-01"
	tarball: "buster-2020-01-01.tar"
}

injector: {
	_i_tags: * strings.Join([for _v in defaults.tags {_v.toString}], ",") | string @tag(tags, type=string)

	_tags: [for _k, _v in strings.Split(_i_tags, ",") {
		types.#Image & {#fromString: _v}
	}]

	_cache_from: types.#CacheFrom & {#fromString: * defaults.cacheFrom.toString | string @tag(cache_from, type=string)}
	_cache_to: types.#CacheTo & {#fromString: * defaults.cacheTo.toString | string @tag(cache_to, type=string)}

	_i_platforms: * strings.Join(defaults.platforms, ",") | string @tag(platforms, type=string)

	_platforms: [...string]

	if _i_platforms == "" {
		_platforms: []
	}
	if _i_platforms != "" {
		_platforms: [for _k, _v in strings.Split(_i_platforms, ",") {_v}]
	}

	_debootstrap_suite: * defaults.suite | =~ "^(?:buster|bullseye)$" @tag(debootstrap_suite, type=string)
	_debootstrap_date: * defaults.date | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(debootstrap_date, type=string)

	_directory: * "context/debian/cache" | string @tag(directory, type=string)

	_from_image: types.#Image & {#fromString: *"scratch" | string @tag(from_image, type=string)}
	_from_tarball: *defaults.tarball | string @tag(from_tarball, type=string)
}

			// XXX this is really environment instead righty?
			// This to specify if a offband repo is available
			//DEBOOTSTRAP_REPOSITORY: #Secret & {
			//	content: "https://apt-cache.local/archive/debian/" + strings.Replace(args.DEBOOTSTRAP_DATE, "-", "", -1)
			//}

cakes: {
	debootstrap: scullery.#Cake & {
		recipe: {
			input: {
				context: "context/debootstrap"
				cache: injector._cache_from
				root: "./"
				from: injector._from_image
			}

			process: target: "debootstrap"

			process: platforms: injector._platforms

      process: args: {
	      DEBOOTSTRAP_DATE: injector._debootstrap_date
  	    DEBOOTSTRAP_SUITE: injector._debootstrap_suite

      	FROM_TARBALL: injector._from_tarball
      	// Extra packages we want in
      	// XXX make that injectable
      	PRELOAD_PACKAGES: string | *"" // ncat dnsutils curl lsb-base
      	// Packages we want removed
      	// XXX make that injectable?
      	UNLOAD_PACKAGES: string | *""// apt-transport-https openssl ca-certificates libssl1.1
				// Regardless of where we sourced from, we need a full-blown version with security and updates
      	// XXX make that injectable?
				DEBOOTSTRAP_SOURCES_COMMIT: #"""
					deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.DEBOOTSTRAP_DATE, "-", "", -1) + "T000000Z") \#(args.DEBOOTSTRAP_SUITE) main
					deb http://snapshot.debian.org/archive/debian-security/\#(strings.Replace(args.DEBOOTSTRAP_DATE, "-", "", -1) + "T000000Z") \#(args.DEBOOTSTRAP_SUITE)/updates main
					deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.DEBOOTSTRAP_DATE, "-", "", -1) + "T000000Z") \#(args.DEBOOTSTRAP_SUITE)-updates main

					"""#
      }

			output: {
				cache: injector._cache_to
				directory: injector._directory
			}
		}

		// Icing are decided by the operator
		// Here, this image also is a special kind where we want to force the repo to a specific point in time so that our pinned dependencies are available
		icing: UserDefined & {
			subsystems: apt: sources: #"""
			deb http://snapshot.debian.org/archive/debian/20200101T000000Z \#(recipe.process.args.DEBOOTSTRAP_SUITE) main
			deb http://snapshot.debian.org/archive/debian-security/20200101T000000Z \#(recipe.process.args.DEBOOTSTRAP_SUITE)/updates main
			deb http://snapshot.debian.org/archive/debian/20200101T000000Z \#(recipe.process.args.DEBOOTSTRAP_SUITE)-updates main

			"""#
			// XXX interesting ripple effects...
			subsystems: apt: check_valid: false
		}
	}

	debian: scullery.#Cake & {
		recipe: scullery.#Recipe & {
			input: {
				context: "context/debian"
				cache: injector._cache_from
				root: "./"
				from: injector._from_image
			}

			process: target: "debian"

			process: platforms: injector._platforms

			process: args: {
	      DEBOOTSTRAP_DATE: injector._debootstrap_date
  	    DEBOOTSTRAP_SUITE: injector._debootstrap_suite
			}

			output: {
				cache: injector._cache_to
				tags: injector._tags
			}

			// Standard metadata for the image
			metadata: {
				// XXX plug in the ref_name here
				ref_name: process.args.DEBOOTSTRAP_SUITE + "-" + process.args.DEBOOTSTRAP_DATE,
				title: "Dubo Debian \(process.args.DEBOOTSTRAP_SUITE)",
				description: "Lovingly debootstrapped from \(process.args.DEBOOTSTRAP_SUITE) (at \(process.args.DEBOOTSTRAP_DATE))",
			}
		}

		icing: UserDefined
	}
}

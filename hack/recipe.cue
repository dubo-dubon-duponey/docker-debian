package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

// XXX WIP: clearly the injector is defective at this point and has to be rethought
// It's probably a better approach to hook it into the recipe, or the env to avoid massive re-use problems

// Entry point if there are environmental definitions
UserDefined: scullery.#Icing & {
	// XXX add injectors here?
//				cache: injector._cache_to
//				cache: injector._cache_from
}

// XXX unfortunately, you cannot have tags in imported packages, so this has to be hard-copied here

defaults: {
	tags: [
		types.#Image & {
			registry: "push-registry.local"
 			image: "dubo-dubon-duponey/debian"
			tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
		},
		types.#Image & {
			registry: "push-registry.local"
			image: "dubo-dubon-duponey/debian"
			tag: "latest"
		},
		types.#Image & {
   		registry: "ghcr.io"
   		image: "dubo-dubon-duponey/debian"
   		tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
   	},
		types.#Image & {
			registry: "ghcr.io"
			image: "dubo-dubon-duponey/debian"
			tag: "latest"
		}
	],
	platforms: [
		types.#Platforms.#AMD64,
		types.#Platforms.#I386,
		types.#Platforms.#V7,
		types.#Platforms.#V6,
		types.#Platforms.#S390X,
		types.#Platforms.#ARM64,
		// qemue / bullseye busted
		// types.#Platforms.#PPC64LE,
	]

	suite: "bullseye"
	date: "2021-06-01"
	tarball: "\(suite)-\(date).tar"
}

injector: {
	_i_tags: * strings.Join([for _v in defaults.tags {_v.toString}], ",") | string @tag(tags, type=string)

	_tags: [for _k, _v in strings.Split(_i_tags, ",") {
		types.#Image & {#fromString: _v}
	}]
	// _tags: [...types.#Image]
	//if _i_tags != "" {
	//}
	//_tags: [for _k, _v in strings.Split(_i_tags, ",") {
	//	types.#Image & {#fromString: _v}
	//}]

	_i_platforms: * strings.Join(defaults.platforms, ",") | string @tag(platforms, type=string)

	_platforms: [...string]

	if _i_platforms == "" {
		_platforms: []
	}
	if _i_platforms != "" {
		_platforms: [for _k, _v in strings.Split(_i_platforms, ",") {_v}]
	}

	_target_suite: * defaults.suite | =~ "^(?:buster|bullseye|sid)$" @tag(target_suite, type=string)
	_target_date: * defaults.date | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(target_date, type=string)
	_target_repository: * "" | string @tag(target_repository, type=string)

	_directory: * "./context/cache" | string @tag(directory, type=string)

	_from_image: types.#Image & {#fromString: *"scratch" | string @tag(from_image, type=string)}
	_from_tarball: *defaults.tarball | string @tag(from_tarball, type=string)
}

			// XXX this is really environment instead righty?
			// This to specify if a offband repo is available
			//TARGET_REPOSITORY: #Secret & {
			//	content: "https://apt-cache.local/archive/debian/" + strings.Replace(args.TARGET_DATE, "-", "", -1)
			//}

cakes: {
	debootstrap: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				context: "./context"
				root: "./"
				from: injector._from_image
			}

  		process: secrets: TARGET_REPOSITORY: content: injector._target_repository

			process: target: "debootstrap"

			process: platforms: injector._platforms

      process: args: {
	      TARGET_DATE: injector._target_date
  	    TARGET_SUITE: injector._target_suite

      	FROM_TARBALL: injector._from_tarball
      	// Extra packages we want in
      	// XXX make that injectable
      	PRELOAD_PACKAGES: string | *"" // ncat dnsutils curl lsb-base
      	// Packages we want removed
      	// XXX make that injectable?
      	UNLOAD_PACKAGES: string | *""// apt-transport-https openssl ca-certificates libssl1.1
				// Regardless of where we sourced from, we need a full-blown version with security and updates
      	// XXX make that injectable?
      	TARGET_SOURCES_COMMIT: string
      	if TARGET_SUITE == "buster" {
					TARGET_SOURCES_COMMIT: #"""
						deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE) main
						deb http://snapshot.debian.org/archive/debian-security/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)/updates main
						deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-updates main
						deb-src http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE) main
						deb-src http://snapshot.debian.org/archive/debian-security/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)/updates main
						deb-src http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-updates main

						"""#
      	}
      	// Bullseye made security repo urls more sensical
      	if TARGET_SUITE == "bullseye" {
					TARGET_SOURCES_COMMIT: #"""
						deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE) main
						deb http://snapshot.debian.org/archive/debian-security/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-security main
						deb http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-updates main
						deb-src http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE) main
						deb-src http://snapshot.debian.org/archive/debian-security/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-security main
						deb-src http://snapshot.debian.org/archive/debian/\#(strings.Replace(args.TARGET_DATE, "-", "", -1) + "T000000Z") \#(args.TARGET_SUITE)-updates main

						"""#

      	}
      }

			output: {
				directory: injector._directory
			}
		}

		// This image is a special kind where we want to force the repo to a specific point in time so that our pinned dependencies are available.
		// This setting unfortunately has to be infered from the name of the base image (in case we fully retool)
		// XXX this should just go - we can't kill it right now because of snapshot blacklisting
		icing: UserDefined & {

						//	"https://apt.local/archive/bullseye"
      			// deb http://apt.local/archive/bullseye-updates/20210701T000000Z/ bullseye-updates main
      			// deb http://apt.local/archive/bullseye-security/20210701T000000Z/ bullseye-security main
      			// deb http://apt.local/archive/bullseye/20210701T000000Z/ bullseye main
			// if recipe.process.args.TARGET_REPOSITORY == "" {
					subsystems: apt: sources: #"""
					# Bullseye circa June 1st 2021
					#deb http://snapshot.debian.org/archive/debian/20210601T000000Z bullseye main
					#deb http://snapshot.debian.org/archive/debian-security/20210601T000000Z bullseye-security main
					#deb http://snapshot.debian.org/archive/debian/20210601T000000Z bullseye-updates main

					deb https://apt-mirror.local/archive/bullseye/20210701T000000Z bullseye main
					deb https://apt-mirror.local/archive/bullseye-updates/20210701T000000Z bullseye-updates main
					deb https://apt-mirror.local/archive/bullseye-security/20210701T000000Z bullseye-security main
					"""#
					// XXX interesting ripple effects...
					subsystems: apt: check_valid: false
			// }
		}
		if icing.subsystems.apt.proxy != _|_ {
			icing: subsystems: curl: proxy: icing.subsystems.apt.proxy
		}
	}

	debian: scullery.#Cake & {
		recipe: scullery.#Recipe & {
			input: {
				context: "./context"
				root: "./"
				from: injector._from_image
			}

			process: target: "debian"

			process: platforms: injector._platforms

			process: args: {
	      TARGET_DATE: injector._target_date
  	    TARGET_SUITE: injector._target_suite
			}

			output: {
				tags: injector._tags
			}

			// Standard metadata for the image
			metadata: {
				ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Debian \(process.args.TARGET_SUITE)",
				description: "Lovingly debootstrapped from \(process.args.TARGET_SUITE) (at \(process.args.TARGET_DATE))",
			}
		}

		icing: UserDefined
	}
}

package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

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
		// XXX is this still qemu busted?
		types.#Platforms.#PPC64LE,
	]

	suite: "bullseye"
	date: "2021-07-01"
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

	_from_image_builder: types.#Image & {#fromString: *"scratch" | string @tag(from_image_builder, type=string)}
	_from_tarball: *defaults.tarball | string @tag(from_tarball, type=string)
}

cakes: {
	debootstrap: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				context: "./context"
				root: "./"
				from: builder: injector._from_image_builder
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

		icing: UserDefined & {
			// XXX this is required unless using a different origin repo than snapshot, and overriden sources.list so...
			subsystems: apt: check_valid: false
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

UserDefined: scullery.#Icing & {
}


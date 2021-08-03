package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

cakes: {
	debootstrap: scullery.#Cake & {
		recipe: {
			process: {
				target: "debootstrap"

				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#I386,
					types.#Platforms.#V7,
					types.#Platforms.#V6,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

      process: args: {
	      TARGET_DATE: string
  	    TARGET_SUITE: string

      	// Extra packages we want in
      	PRELOAD_PACKAGES: string | *"" // ncat dnsutils curl lsb-base
      	// Packages we want removed
      	UNLOAD_PACKAGES: string | *""// apt-transport-https openssl ca-certificates libssl1.1

				// Regardless of where we sourced from, we need a full-blown version with security and updates
      	TARGET_SOURCES_COMMIT: string
      	if TARGET_SUITE != _|_ if TARGET_SUITE != "bullseye" {
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
      	if TARGET_SUITE != _|_ if TARGET_SUITE == "bullseye" {
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
				directory: "./context/cache"
			}
		}

		// XXX this is required unless using a different origin repo than snapshot, and overriden sources.list so...
		icing: subsystems: apt: check_valid: false

		if icing.subsystems.apt.proxy != _|_ {
			icing: subsystems: curl: proxy: icing.subsystems.apt.proxy
		}
	}

	debian: scullery.#Cake & {
		recipe: scullery.#Recipe & {

			process: {
				target: "debian"

				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#I386,
					types.#Platforms.#V7,
					types.#Platforms.#V6,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

			process: args: {
	      TARGET_DATE: string
  	    TARGET_SUITE: string
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["debian"],
					tags: [...string] | * ["latest"]
				}
			}

			// Standard metadata for the image
			metadata: {
				title: "Dubo Debian \(process.args.TARGET_SUITE)",
				description: "Lovingly debootstrapped from \(process.args.TARGET_SUITE) (at \(process.args.TARGET_DATE))",
			}
		}
	}
}

// Allow hooking-in a UserDefined environment as icing
UserDefined: scullery.#Icing

cakes: debootstrap: icing: UserDefined
cakes: debian: icing: UserDefined

// Injectors

injectors: {
	suite: =~ "^(?:jessie|stretch|buster|bullseye|sid)$" @tag(suite, type=string)
	date: =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(date, type=string)
	platforms: string @tag(platforms, type=string)
	registry: string @tag(registry, type=string)

	repository: string @tag(repository, type=string)
}

cakes: debootstrap: recipe: {
	input: from: registry: injectors.registry

	if injectors.platforms != _|_ {
		process: platforms: strings.Split(injectors.platforms, ",")
	}

	process: args: TARGET_DATE: injectors.date
	process: args: TARGET_SUITE: injectors.suite

	if injectors.repository != _|_ {
		process: secrets: TARGET_REPOSITORY: content: injectors.repository
	}
}

//			process: secrets: TARGET_REPOSITORY: types.#Secret

cakes: debian: recipe: {
	if injectors.platforms != _|_ {
		process: platforms: strings.Split(injectors.platforms, ",")
	}

	process: args: TARGET_DATE: injectors.date
	process: args: TARGET_SUITE: injectors.suite

	output: images: registries: {
		"push-registry.local": "dubo-dubon-duponey",
		"ghcr.io": "dubo-dubon-duponey",
		"docker.io": "dubodubonduponey"
	}
	output: images: tags: [injectors.suite + "-" + injectors.date, injectors.suite + "-latest", "latest"]

	metadata: ref_name: injectors.suite + "-" + injectors.date
}

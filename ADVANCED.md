# Moar

## Extra flags

Using the makefile and the `EXTRAS` environment variable, you can control a number of aspects of the build:

```bash
# force a build without any cache
export EXTRAS="--inject no_cache=true"
# push the resulting Debian image to multiple locations
export EXTRAS="--inject tags=registry1.com/foo,registry2.com/bar:tag"
# build only select architectures
export EXTRAS="--inject platforms=linux/arm64,linux/s390x"
# change the display to "plain" progress (see other buildkit progress options: plain, tty, auto)
export EXTRAS="--inject progress=plain"

make build
```

## Cue environment

The build supports advanced environment control, allowing you to use apt mirrors (or proxy cache), complete with TLS,
authentication and gpg signing.

To access these features, create a cue file, for example `env.cue`, as follow:

```cue
package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
)

UserDefined: scullery.#Icing & {
	hosts: {
		"this-is-an-internal-apt-proxy.local": {
			ip: "10.0.4.102"
			https: {
				login: "my_username"
				password: "my_password"
			}
		}
		"another-internal-host": {
			ip: "10.0.4.97"
		}
	}
	subsystems: {
		apt: {
			proxy: "https://this-is-an-internal-apt-proxy.local"
			user_agent: "DuboDubonDuponey/1.0 (apt)"
			check_valid: false
		}
		curl: {
			proxy: "https://this-is-an-internal-apt-proxy.local"
			user_agent: "DuboDubonDuponey/1.0 (curl)"
		}
	}
	trust: {
		// The CA to trust
		authority: #"""
			-----BEGIN CERTIFICATE-----
			MIIBozCCAUmgAwIBAgIQBd+mZ7Uj+1lnuzBd1klrvzAKBggqhkjOPQQDAjAwMS4w
			LAYDVQQDEyVDYWRkeSBMb2NhbCBBdXRob3JpdHkgLSAyMDIwIEVDQyBSb290MB4X
			DTIwMTEzMDIzMTA0NVoXDTMwMTAwOTIzMTA0NVowMDEuMCwGA1UEAxMlQ2FkZHkg
			TG9jYWwgQXV0aG9yaXR5IC0gMjAyMCBFQ0MgUm9vdDBZMBMGByqGSM49AgEGCCqG
			SM49AwEHA0IABOzpNQ/wkHMGFibVR5Gk14PspP+kQ5LpR3XWwvD+rpJjhylvQLW3
			/ZvOzKHKHfilkOHI3FCHct8IImF5qhpbJF6jRTBDMA4GA1UdDwEB/wQEAwIBBjAS
			BgNVHRMBAf8ECDAGAQH/AgEBMB0GA1UdDgQWBBTGwiMW3cMgyEeZY09nyHbUWMCt
			5TAKBggqhkjOPQQDAgNIADBFAiBKZePDr6aXHiMwESluwVM1/y/WVMr4dPNcf2+4
			JX0jYwIhALi9+u+eHd2DGP93NXXMgcZMV+YwhSuaFu04pY6Mdwul
			-----END CERTIFICATE-----

			"""#
		// Trusted GPG keys
		gpg: "trusted.gpg"
	}
  // Advanced caching options
	cache: {
		to: types.#CacheTo & {
			type: types.#CacheType.#REGISTRY
			image: {
				registry: "myregistry.com"
				image: "somecache"
			}
    }
		from: types.#CacheFrom & {
			type: types.#CacheType.#REGISTRY
			image: {
				registry: "myregistry.com"
				image: "somecache"
			}
		}
	}
}
```

Now, add it when building:

```bash
ICING=env.cue TARGET_DATE=2020-06-01 TARGET_SUITE=buster make build
```

The above `env` will instruct `apt` and `curl` to use an internal apt-proxy, with authentication and TLS (provided by CA),
and also to use registry caching.

### Super-advanced cue configuration

The makefile merely calls cue. A typical `build` thus is just:

```
# Generate the actual rootfs
cue --inject target_date=2021-06-01 --inject target_suite=buster \
		debootstrap ./hack/recipe.cue ./hack/cue_tool.cue ./your_environment.cue

# Assemble the final image and push it
cue --inject target_date=2021-06-01 --inject target_suite=buster \
    --inject tags=somewhere/to_push \
		debian ./hack/recipe.cue ./hack/cue_tool.cue ./your_environment.cue
```

... which you can tweak directly to fit your advanced needs ^^

And have a look at `hack/recipe.cue`, and hack away.

## Stuff you never knew you wanted to ask

 * local environment (internal hosts, authentication, certificates) are passed as build secrets and as such never ship to the final image
 * final sources.list is pointing at `snapshot.debian.org`, for the specific date you asked for
   * this is fine: containers should not be updated in place
   * if you want a different behavior, look into the `recipe.cue` file and hack away

## Caveats

### About cache and build context

The `context/debian/cache/rootfs` folder is part of Docker build context for the debian stage.

As such, if it grows really big (with many different versions), the last stage will become slooooooow.

It is recommended to clean-up this folder from older / useless versions from time to time to avoid such adverse side-effects.

### Support

This is tested regularly on macOS (amd64) and Ubuntu 20.04 (amd64).

Support on other OSes and architectures is not tested daily, but bring it on if you have issues.

package scullery

import (
	"duponey.cloud/buildkit/buildctl"
	"duponey.cloud/buildkit/types"
)

// XXX you cannot have @tag in modules it seems...
//#Injector: {
//	...
//}

#Cake: {
	// Takes image definition and user defined inputs
	recipe: #Recipe
	icing: #Icing
	hosts: types.#Hosts // [string]: string

	// XXXWIP
	// injector: #Injector
	//for _k, _v in injector {
	//	_buildkit: "\(_k)": _v
	//}
	// XXX

	// Populate secrets

	// Instanciate subsystems and populate them
	_buildkit: buildctl.#Commander

	// Connect the image definitions into buildkit (XXX and inject overrides?)
	_buildkit: {
    context: recipe.input.context
    if recipe.output.directory != _|_ {
    	directory: recipe.output.directory
    }
    if recipe.process.platforms != _|_ {
	    platforms: recipe.process.platforms
    }
    target: recipe.process.target
    if recipe.output.tags != _|_ {
	    tags: recipe.output.tags
    }
		cache_from: icing.cache.from
		cache_to: icing.cache.to
		args: recipe.process.args

		// Making these standard for now
    args: {
    	// This is sui generis
    	FROM_IMAGE: recipe.input.from.toString,

			BUILD_TITLE: recipe.metadata.title
			BUILD_DESCRIPTION: recipe.metadata.description
			BUILD_CREATED: recipe.metadata.created
			BUILD_URL: recipe.metadata.url
			BUILD_LICENSES: recipe.metadata.licenses
			BUILD_VERSION: recipe.metadata.version
			BUILD_REVISION: recipe.metadata.revision

			BUILD_DOCUMENTATION: recipe.metadata.documentation
			BUILD_SOURCE: recipe.metadata.source
			BUILD_VENDOR: recipe.metadata.vendor
			BUILD_REF_NAME: recipe.metadata.ref_name
    }

		for _k, _v in icing.hosts {
			if _v.ip != _|_ {
				hosts: "\(_k)": _v.ip
			}
		}

		secrets: icing.secrets
		secrets: recipe.process.secrets
	}

	// buildkit: _buildkit
	// apt: _apt
	// curl: _curl
}

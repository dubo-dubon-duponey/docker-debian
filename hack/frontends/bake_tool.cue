package bake

import (
	"tool/exec"
	"strings"
	"tool/os"
)

#Frontend: {
  value: _type | *_default
  com: ["--frontend", _tag]

  _type: =~ "^.{1,}$"
  _default: "dockerfile.v0"
  _tag: *value | _type @tag(frontend,type=string)
}

#Progress: {
  value: _type | *_default
  com: ["--progress", _tag]

  AUTO: "auto"
  PLAIN: "plain"
  TTY: "tty"

  _type: AUTO | PLAIN | TTY
  _default: AUTO
  _tag: *value | _type @tag(progress,type=string)
}

#NoCache: {
  value: _type | *_default
  com: [if _tag == true {"--no-cache"}]

  _type: bool
  _default: false
  _tag: *value | _type @tag(no_cache,type=bool)
}

#Trace: {
  value: _type | *_default
  com: [if _tag != "" {"--trace"}] + [if _tag != "" {_tag}]

  _default: ""
  _type: =~ "^.{1,}$"
  _tag: *value | _type @tag(trace,type=string)
}

#Args: {
  value: [string]: string

  com:
    [
      for key, item in value {
        "--opt=build-arg:\(key)=\(item)"
      }
    ]
}

#LocalContext: {
  value: _type | *_default
  com: ["--local", "context=\(_tag)"]

  _default: "./context"
  _type: =~ "^.{1,}$"
  _tag: *value | _type @tag(context,type=string)
}

#LocalDockerfileDir: {
  value: _type | *_default
  com: ["--local", "dockerfile=\(_tag)"]

  _default: "."
  _type: =~ "^.{1,}$"
  _tag: *value | _type @tag(dockerfile,type=string)
}

#OptDockerfileName: {
  value: _type | *_default
  com: ["--opt", "filename=\(_tag)"]

  _default: "Dockerfile"
  _type: =~ "^.{1,}$"
  _tag: *value | _type @tag(filename,type=string)
}

#OptTarget: {
  value: _type | *_default

  com:
    [if _tag != "" {"--opt"}] +
    [if _tag != "" {"target=\(_tag)"}]

  _default: ""
  _type: =~ "^.{1,}$"
  _tag: *value | _type @tag(target,type=string)
}

#OptHosts: {
  value: [..._type] | *_default
  com:
    [if _tag != "" {"--opt"}] +
    [if _tag != "" {"add-hosts=\(_tag)"}]

  _default: []
  _type: =~ "^([^=]+=[^,=]+)(,[^=]+=[^,=]+)*$"
  _tag: *strings.Join(value, ",") | _type @tag(hosts,type=string)
}

#Platforms: {
  AMD64: "linux/amd64"
  ARM64: "linux/arm64"
  V7: "linux/arm/v7"
  V6: "linux/arm/v6"
  PPC64LE: "linux/ppc64le"
  S390X: "linux/s390x"
  I386: "linux/386"

  value: [..._type] | *_default
  com: ["--opt", "platform=\(_tag)"]

  _default: [AMD64, ARM64, V7, PPC64LE, S390X]
  _type: =~ "^(?:\(AMD64)|\(ARM64)|\(V7)|\(V6)|\(PPC64LE)|\(S390X)|\(I386))(,(?:\(AMD64)|\(ARM64)|\(V7)|\(V6)|\(PPC64LE)|\(S390X)|\(I386)))*$"
  _tag: *strings.Join(value, ",") | _type @tag(platforms,type=string)
}


#CacheTo: {
  LOCAL: "local"
  REGISTRY: "registry"
  NO_CACHE: ""
  MIN: "min"
  MAX: "max"

  value: _type | *_default
  mode: _type_mode | *_default_mode
  #destination: =~ ".+" | =~ ".+" @tag(cache_location,type=string)
  com:
    [if _tag == LOCAL {"--export-cache"}] +
    [if _tag == REGISTRY {"--export-cache"}] +
    [if _tag == LOCAL {"type=\(_tag),dest=\(#destination),mode=\(_tag_mode),oci-mediatypes=true"}] +
    [if _tag == REGISTRY {"type=\(_tag),ref=\(#destination),mode=\(_tag_mode),oci-mediatypes=true"}]

  _default: NO_CACHE
  _default_mode: MAX
  _type: =~ "^(?:\(LOCAL)|\(REGISTRY))$"
  _type_mode: =~ "^(?:\(MIN)|\(MAX))$"

  _tag: *value | _type @tag(cache_type,type=string)
  _tag_mode: *mode | _type_mode @tag(cache_mode,type=string)
}

#CacheFrom: {
  LOCAL: "local"
  REGISTRY: "registry"
  NO_CACHE: ""

  value: _type | *_default
  #destination: =~ ".+" | =~ ".+" @tag(cache_location,type=string)
  com:
    [if _tag == LOCAL {"--import-cache"}] +
    [if _tag == REGISTRY {"--import-cache"}] +
    [if _tag == LOCAL {"type=\(_tag),src=\(#destination)"}] +
    [if _tag == REGISTRY {"type=\(_tag),ref=\(#destination)"}]

  _default: NO_CACHE
  _type: =~ "^(?:\(LOCAL)|\(REGISTRY))$"

  _tag: *value | _type @tag(cache_type,type=string)
}

#OutputDirectory: {
  value: _type | *_default
  com:
    [if _tag != "" {"--output"}] +
    [if _tag != "" {"type=local,dest=\(_tag)"}]

  _default: ""
  _type: =~ "^.{1,}$"

  _tag: *value | _type @tag(directory,type=string)
}

#OutputTarball: {
  DOCKER: "docker"
  TAR: "tar"
  OCI: "oci"
	// tarballtype: "docker" | "tar" | "oci" | * "tar"

  value: _type | *_default
  specie: _type_ball | *_default_ball
  com:
    [if _tag != "" {"--output"}] +
    [if _tag != "" {"type=\(_tag_type),dest=\(_tag)"}]

  _default: ""
  _type: =~ "^.{1,}$"
  _default_ball: TAR
  _type_ball: =~ "^(?:\(OCI)|\(DOCKER)|\(TAR)$"

  _tag: *value | _type @tag(tarball,type=string)
  _tag_type: *specie | _type_ball @tag(tarball_type,type=string)
}

#OutputTags: {
  value: [..._type] | *_default
  com:
    [if _tag != "" {"--output"}] +
    [if _tag != "" {"type=image," + "\"" + "name=" + _tag + "\"" + ",push=true,oci-mediatypes=true"}]

  _default: []
  // TODO: tag grammar here
  _type: =~ "^.{1,}$"
  _tag: *strings.Join(value, ",") | _type @tag(tags,type=string)
}

//	tags: [...string]
//	tags: strings.Split(_tag_tags, ",")

//        "--output=type=image," + "\"" + "name=" + strings.Join(tags, ",") + "\"" + ",push=true,oci-mediatypes=true"



//	keyImageResolveMode        = "image-resolve-mode"
//	keyForceNetwork            = "force-network-mode"
// _tag_hosts: string | * "" | string @tag(hosts,type=string)
// This is likely not necessary with a OCI worker
_tag_force_pull: bool | * true | bool @tag(pull,type=bool)
// _tag_tags: string | * "" | string @tag(tags,type=string)
//_tag_cache_type: string | * "local" | string @tag(cache_type,type=string)
//_tag_cache_location: string | * "./cache/buildkit" | string @tag(cache_location,type=string)

env: os.Getenv & {}

#Bake: {
  // Flags
  frontend: #Frontend
  progress: #Progress
  no_cache: #NoCache
  trace: #Trace
  cache_to: #CacheTo
  cache_from: #CacheFrom

  // Args
	args: #Args

  // Local
	context: #LocalContext
	dockerfile: #LocalDockerfileDir

  // Opts
  filename: #OptDockerfileName
  hosts: #OptHosts
  target: #OptTarget
	platforms: #Platforms

  // Output
  tarball: #OutputTarball
  directory: #OutputDirectory
  tags: #OutputTags





//	target: string | * ""
	force_pull: _tag_force_pull
//  hosts: [...string] | * strings.Split(_tag_hosts, ",")
	// tags: [...string]
	// tags: strings.Split(_tag_tags, ",")

	// directory: string | * ""
	// tarball: string | * ""
	// tarballtype: "docker" | "tar" | "oci" | * "tar"

	// progress: _tag_progress

  // reargs: [ for key, item in args {"--opt=build-arg:\(key)=\(item)"} ]
  // ["--opt=build-arg:\(key)=\(item)" for key, item in args]

  xxx: exec.Run & {
    cmd: ["echo", "workarounding cue broken env behavior"]
    $after: [env]
  }

  debug: exec.Run & {
    cmd: [
      "echo",
      "buildctl", "build",
    ] + [
//      if len(tags) != 0 {
//        "--output=type=image," + "\"" + "name=" + strings.Join(tags, ",") + "\"" + ",push=true,oci-mediatypes=true"
//      }
    ] + [
//      if directory != "" {
//        "--output=type=local,dest=\(directory)"
//      }
    ] + [
//      if tarball != "" {
//        "--output=type=\(tarballtype),dest=\(tarball)"
//      }
    ] +
      frontend.com +
      progress.com +
      no_cache.com +
      trace.com +
      cache_to.com +
      cache_from.com +
      args.com +
      context.com +
      dockerfile.com +
      filename.com +
      platforms.com +
      hosts.com +
      target.com +
      tarball.com +
      directory.com +
      tags.com

    $after: [xxx]
    // stdout: string // capture stdout
  }

	run: exec.Run & {
    cmd: [
      "buildctl", "build",
    ] +
      frontend.com +
      progress.com +
      no_cache.com +
      trace.com +
      cache_to.com +
      cache_from.com +
      args.com +
      context.com +
      dockerfile.com +
      filename.com +
      platforms.com +
      hosts.com +
      target.com +
      tarball.com +
      directory.com +
      tags.com

    $after: [debug]
  }
}
    // XXX what does buildkit do in that case? is it a dockerfile.v0 opt?
    //] + [
    //  if pull == true { "--pull" } // --opt image-resolve-mode=pull

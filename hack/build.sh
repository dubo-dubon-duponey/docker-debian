#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PATH="$(pwd)/cache/bin:$PATH"
export PATH

"./hack/helpers/install-tools.sh" "./cache/bin"

rm -f "./buildctl.trace.json"

com=(cue)
files=("./hack/recipe.cue" "./hack/helpers/cue_tool.cue")
isflagvalue=
for i in "$@"; do
  if [ "${i:0:2}" == "--" ]; then
    com+=("$i")
    isflagvalue=true
  elif [ "$isflagvalue" == true ]; then
    com+=("$i")
    isflagvalue=
  elif [ "${i##*.}" == "cue" ]; then
    files+=("$i")
  else
    target="$i"
  fi
done
com+=("${target:-image}")
com+=("${files[@]}")

echo "------------------------------------------------------------------"
for i in "${com[@]}"; do
  if [ "${i:0:2}" == -- ]; then
    >&2 printf " %s" "$i"
  else
    >&2 printf " %s\n" "$i"
  fi
done
echo "------------------------------------------------------------------"
"${com[@]}" || {
  cd - > /dev/null
  >&2 printf "Execution failure"
  exit 1
}
cd - > /dev/null

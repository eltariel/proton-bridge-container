#!/bin/bash
set -euo pipefail

# defaults
VERSION=""
BUILDER="docker"
IMAGE_NAME="ghcr.io/eltariel/proton-bridge-container"

USAGE="$(cat <<EOF
Usage: ./build_container.sh [-i|--image "image/name/here"] [-v|--version "tag or branch"] [-p|-d|--podman|--docker]

-i|--image      Set the name of the image
                  Default is "${IMAGE_NAME}".
-v|--version    Set the Proton Mail Bridge version. Must be a tag or branch name.
                  Default is the latest release.
-p|--podman     Use podman to build the image.
-d|--docker     Use docker to build the image.
                  Default is docker. If specified multiple times, the last wins.
EOF
)"

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--image)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -p|--podman)
      BUILDER="podman"
      shift
      ;;
    -d|--docker)
      BUILDER="docker"
      shift
      ;;
    -h|--help)
      echo $USAGE
      exit 1
      ;;
  esac
done

if [ -z "$VERSION" ] ; then
  VERSION="$(curl -s -H "Accept: application/vnd.github+json" https://api.github.com/repos/ProtonMail/proton-bridge/releases/latest | jq -r '.tag_name')"
fi

labels=()
annotations=()
metadata=(
  'org.opencontainers.image.title=Proton Bridge Container'
  'org.opencontainers.image.authors=Ellie Tomkins'
  "org.opencontainers.image.version=$VERSION"
  "org.opencontainers.image.revision=$(git rev-parse HEAD)"
  'org.opencontainers.image.description=Run the ProtonMail bridge in a container.'
  'org.opencontainers.image.url=https://github.com/eltariel/proton-bridge-container'
  'org.opencontainers.image.source=https://github.com/eltariel/proton-bridge-container'
  'org.opencontainers.image.documentation=https://github.com/eltariel/proton-bridge-container/README.md'
  'org.opencontainers.image.licenses=Unlicense'
)
for m in "${metadata[@]}" ; do
  annotations+=("--annotation" "$m")
  labels+=("--label" "$m")
done

echo "Building $VERSION with $BUILDER"
"$BUILDER" build \
  --build-arg BRIDGE_VERSION="${VERSION}" \
  "${labels[@]}" "${annotations[@]}" \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --load \
  .

#!/bin/bash
# Clones the shlink repository with git from Github and builds the Dockerfile

echo "▶️ $0 $*"

set -e

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  echo "Usage: ${0} <branch> [--push|--push-only]"
  echo "  branch       The branch or tag to build. Required."
  echo "  --push       Pushes the built Docker image to the registry."
  echo "  --push-only  Only pushes the Docker image to the registry, but does not build it."
  echo ""

  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi


ROOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

###
# variables for fetching the source
###
SRC_ORG="${SRC_ORG-shlinkio}"
SRC_REPO="${SRC_REPO-shlink}"
BRANCH="${1}"
URL="${URL-https://github.com/${SRC_ORG}/${SRC_REPO}.git}"
SHLINK_PATH="${SHLINK_PATH-.shlink}"

###
# fetching the source
###
echo "🌐 Checking out '${BRANCH}' of shlink from the url '${URL}' into '${SHLINK_PATH}'"
if [ ! -d "${SHLINK_PATH}" ]; then
  git clone -q --depth 10 -b "${BRANCH}" "${URL}" "${SHLINK_PATH}"
fi

(
  cd "${SHLINK_PATH}"
  git remote set-url origin "${URL}"
  git fetch -tp --depth 10 origin "${BRANCH}"
  git checkout -f FETCH_HEAD
  git prune
  cd "${ROOTDIR}"
)
#/bin/cp -f "Dockerfile" "${SHLINK_PATH}/Dockerfile"
#/bin/cp -f ".dockerignore" "${SHLINK_PATH}/.dockerignore"
echo "✅ Checked out shlink"

###
# Determining the value for DOCKERFILE
# and checking whether it exists
###
DOCKERFILE="${DOCKERFILE-Dockerfile}"
if [ ! -f "${DOCKERFILE}" ]; then
  echo "🚨 The Dockerfile ${DOCKERFILE} doesn't exist."

  if [ -z "${DEBUG}" ]; then
    exit 1
  else
    echo "⚠️ Would exit here with code '1', but DEBUG is enabled."
  fi
fi

###
# variables for labelling the docker image
###
BUILD_DATE="$(date --utc --iso-8601=minutes)"

if [ -d ".git" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi

# Get the Git information from the shlink directory
if [ -d "${SHLINK_PATH}/.git" ]; then
  SHLINK_GIT_VERSION=$(cd ${SHLINK_PATH}; git describe | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
  SHLINK_GIT_REF=$(cd ${SHLINK_PATH}; git rev-parse HEAD)
  SHLINK_GIT_BRANCH=$(cd ${SHLINK_PATH}; git rev-parse --abbrev-ref HEAD)
  SHLINK_GIT_URL=$(cd ${SHLINK_PATH}; git remote get-url origin)
fi

# https://github.com/crystal-lang/crystal/pull/4687/files
PROJECT_VERSION="${SHLINK_GIT_VERSION-$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | head -n1 | awk '{print "v"$0}')}"

DOCKER_REGISTRY="${DOCKER_REGISTRY-docker.io}"
DOCKER_ORG="${DOCKER_ORG-shlinkio}"
DOCKER_REPO="${DOCKER_REPO-shlink}"
case "${BRANCH}" in
  master)
    TAG="${TAG-latest}";;
  develop)
    TAG="${TAG-snapshot}";;
  *)
    TAG="${TAG-$BRANCH}";;
esac

###
# Build 
###
echo "🏗 Building version '${PROJECT_VERSION}'"

TARGET_DOCKER_TAG="${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:${TAG}"
TARGET_DOCKER_FULL_TAG="${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:${PROJECT_VERSION}"

###
# composing the additional DOCKER_SHORT_TAG,
# i.e. "v2.6.1" becomes "v2.6",
# which is only relevant for version tags
###
if [[ "${PROJECT_VERSION}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
  MAJOR=${BASH_REMATCH[1]}
  MINOR=${BASH_REMATCH[2]}

  TARGET_DOCKER_SHORT_TAG="${DOCKER_SHORT_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:v${MAJOR}.${MINOR}}"
fi

echo "🐳 Building with Docker tags:"
echo "  - '${TARGET_DOCKER_TAG}'"

DOCKER_BUILD_ARGS=(
  --pull
  -f "${DOCKERFILE}"
  -t "${TARGET_DOCKER_TAG}"
)

if [ -n "${TARGET_DOCKER_FULL_TAG}" ]; then
  echo "  - '${TARGET_DOCKER_FULL_TAG}'"
  DOCKER_BUILD_ARGS+=( -t "${TARGET_DOCKER_FULL_TAG}" )
fi

if [ -n "${TARGET_DOCKER_SHORT_TAG}" ]; then
  echo "  - '${TARGET_DOCKER_SHORT_TAG}'"
  DOCKER_BUILD_ARGS+=( -t "${TARGET_DOCKER_SHORT_TAG}" )
fi

if [ -n "${DOCKER_CUSTOM_TAG}" ]; then
  echo "  - '${DOCKER_CUSTOM_TAG}'"
  DOCKER_BUILD_ARGS+=( -t "${DOCKER_CUSTOM_TAG}" )
fi

DOCKER_BUILD_ARGS+=(
  --label "org.label-schema.build-date=${BUILD_DATE}"
  --label "org.opencontainers.image.created=${BUILD_DATE}"

  --label "org.label-schema.version=${PROJECT_VERSION}"
  --label "org.opencontainers.image.version=${PROJECT_VERSION}"
)
if [ -d ".git" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "org.label-schema.vcs-ref=${GIT_REF}"
    --label "org.opencontainers.image.revision=${GIT_REF}"
  )
fi
if [ -d "${SHLINK_PATH}/.git" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "SHLINK_GIT_VERSION=${SHLINK_GIT_VERSION}"
    --label "SHLINK_GIT_BRANCH=${SHLINK_GIT_BRANCH}"
    --label "SHLINK_GIT_REF=${SHLINK_GIT_REF}"
    --label "SHLINK_GIT_URL=${SHLINK_GIT_URL}"
  )
fi

# --build-arg
DOCKER_BUILD_ARGS+=(
  --build-arg "SHLINK_PATH=${SHLINK_PATH}"
  --build-arg "PROJECT_VERSION=${PROJECT_VERSION//v}"
)

echo "🐳 Building the Docker image version '${PROJECT_VERSION}'."
docker build "${DOCKER_BUILD_ARGS[@]}" .
echo "✅ Finished building the Docker images version '${PROJECT_VERSION}'."


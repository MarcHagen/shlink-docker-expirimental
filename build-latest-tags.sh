#!/bin/bash
# Builds the latest released version

echo "▶️ $0 $*"

###
# Checking for the presence of GITHUB_OAUTH_CLIENT_ID
# and GITHUB_OAUTH_CLIENT_SECRET
###
if [ -n "${GITHUB_OAUTH_CLIENT_ID}" ] && [ -n "${GITHUB_OAUTH_CLIENT_SECRET}" ]; then
  echo "🗝 Performing authenticated Github API calls."
  GITHUB_OAUTH_PARAMS="client_id=${GITHUB_OAUTH_CLIENT_ID}&client_secret=${GITHUB_OAUTH_CLIENT_SECRET}"
else
  echo "🕶 Performing unauthenticated Github API calls. This might result in lower Github rate limits!"
  GITHUB_OAUTH_PARAMS=""
fi

###
# Calling Github to get the latest version
###
ORIGINAL_GITHUB_REPO="shlinkio/shlink"
GITHUB_REPO="${GITHUB_REPO-$ORIGINAL_GITHUB_REPO}"
URL_RELEASES="https://api.github.com/repos/${GITHUB_REPO}/tags?${GITHUB_OAUTH_PARAMS}"
# Composing the JQ commans to extract the most recent version number
set -e
JQ_LATEST=".[0].name"

CURL="curl -sS"

# Querying the Github API to fetch the most recent version number
VERSION=$($CURL "${URL_RELEASES}" | jq -r "${JQ_LATEST}")

./build.sh "${VERSION}" $@
exit $?
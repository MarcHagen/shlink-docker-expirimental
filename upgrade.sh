#!/bin/bash

echo "▶️ $0 $*"

export VERSION="custom" 
export DOCKER_CUSTOM_TAG="shlinkio/shlink:custom"
export PRERELEASE="false"

./build.sh master $@
docker-compose pull redis
docker-compose stop
docker-compose rm -f
docker-compose up -d

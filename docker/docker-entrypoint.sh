#!/usr/bin/env sh
set -e

echo "🏗 Creating fresh database if needed..."
php bin/cli db:create -n

echo "🏗 Updating database..."
php vendor/bin/doctrine-migrations migrations:migrate --no-interaction --allow-no-migration

echo "🏗 Clearing ORM cache..."
php vendor/bin/doctrine orm:clear-cache:metadata -n

echo "🏗 Generating proxies..."
php vendor/bin/doctrine orm:generate-proxies -n

echo "✅ Starting swoole..."
# When restarting the container, swoole might think it is already in execution
# This forces the app to be started every second until the exit code is 0
until php vendor/bin/mezzio-swoole start; do sleep 1 ; done

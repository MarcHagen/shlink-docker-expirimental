FROM php:7.4.4-alpine3.11 AS base

WORKDIR /app

LABEL Maintainer="Marc Hagen <hello@marchagen.nl>" \
      Description="Lightweight php 7.4 container based on alpine with Swoole enabled, composer installed."

ENV APCU_VERSION 5.1.18
ENV APCU_BC_VERSION 1.0.5
ENV INOTIFY_VERSION 2.0.0
ENV SWOOLE_VERSION 4.4.17
ENV REDIS_VERSION 5.2.1
ENV TZ UTC

RUN sed -i 's/dl-cdn.alpinelinux.org/dl-4.alpinelinux.org/g' /etc/apk/repositories \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS linux-headers tzdata \
    && apk add --no-cache icu libgd libpng zip libjpeg-turbo \
                          icu-dev libpng-dev libzip-dev  \
    && docker-php-source extract \
    && docker-php-ext-install gd pdo_mysql intl zip \
    # enable igbinary serializer support? [no]
    # enable lzf compression support? [no]
    # enable zstd compression support? [no]
    && printf "no\nno\nno\n" | pecl install redis-${REDIS_VERSION} \
    && pecl install inotify-${INOTIFY_VERSION} \
    #&& pecl install apcu-${APCU_VERSION} \
    #&& pecl install apcu_bc-${APCU_BC_VERSION} \
    # enable sockets supports? [no]
    # enable openssl support? [no]
    # enable http2 support? [yes]
    # enable mysqlnd support? [yes]
    && printf "no\nno\nyes\nyes\n" | pecl install swoole-${SWOOLE_VERSION} \
    && docker-php-ext-enable swoole redis inotify zip \
    #&& docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-source delete \
    #Disable timezones... use UTC
    # && ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime \ 
    # && echo "Europe/Amsterdam" > /etc/timezone \
    && apk del .phpize-deps icu-dev libpng-dev libmcrypt-dev \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/* $HOME/.cache # clears the cache

## Builder image
FROM base AS builder
COPY --from=composer:1.10.1 /usr/bin/composer /usr/local/bin

ENV COMPOSER_HOME /composer
ENV PATH /composer/vendor/bin:$PATH
RUN composer global require \
    --prefer-dist \
    #--apcu-autoloader \
    --optimize-autoloader \
        "hirak/prestissimo"

## Installer image
FROM builder AS installer

ARG SHLINK_PATH
ARG PROJECT_VERSION

COPY ${SHLINK_PATH}/ /app
RUN ln -s /app/bin/cli /app/bin/shlink \
    && sed -i "s/%SHLINK_VERSION%/${PROJECT_VERSION}/g" /app/config/autoload/app_options.global.php

RUN composer install \ 
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    #--apcu-autoloader \
    --no-suggest \
    --no-interaction \
    && composer clear-cache

## Runtime image
FROM base AS runtime

COPY --from=installer /app /app
ENV PATH /app/bin:/app/vendor/bin:$PATH

# Expose swoole port
EXPOSE 8080

# Copy config specific for the image
COPY docker/docker-entrypoint.sh docker-entrypoint.sh
COPY docker/config/shlink_in_docker.local.php /app/config/autoload/shlink_in_docker.local.php
COPY docker/config/php.ini ${PHP_INI_DIR}/

ENTRYPOINT ["/bin/sh", "./docker-entrypoint.sh"]

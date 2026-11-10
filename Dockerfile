# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE: the Apache
# variant of wodby/php.
ARG BASE_IMAGE

# PHP-FPM and Apache with Wodby's setup for Matomo, but no Matomo: an image
# built on this one installs a Matomo release with matomo-install-release.
FROM ${BASE_IMAGE}

ENV APP_NAME="Matomo" \
    # The Matomo major versions that Wodby's scripts support, separated by \
    # spaces. \
    MATOMO_MAJOR_VERSIONS="5" \
    \
    # PHP-FPM runs as the owner of the code, like Matomo's console commands, so \
    # files any of them write stay writable by the others. \
    PHP_FPM_USER="wodby" \
    # Matomo reads the Marketplace plugin directories from the environment. \
    PHP_FPM_CLEAR_ENV="no" \
    PHP_ALWAYS_POPULATE_RAW_POST_DATA="1" \
    PHP_MAX_EXECUTION_TIME="300" \
    PHP_ERROR_REPORTING="E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED" \
    \
    # Plugins installed from the Marketplace go to the files directory, so \
    # every container loads them and they outlive the image. \
    MATOMO_PLUGIN_DIRS="/var/www/html/marketplace-plugins;marketplace-plugins" \
    MATOMO_PLUGIN_COPY_DIR="/var/www/html/marketplace-plugins/"

USER root

COPY geolite /usr/local/share/matomo/geolite
COPY plugins /usr/local/share/matomo/plugins

RUN set -ex; \
    \
    # matomo-install-release checks the signature of the Matomo release. \
    apk add --no-cache gnupg; \
    \
    gunzip /usr/local/share/matomo/geolite/GeoLite2-City.mmdb.gz

COPY matomo.conf /etc/apache2/conf.d/matomo.conf
COPY init /docker-entrypoint-init.d/
COPY bin /usr/local/bin/

USER wodby

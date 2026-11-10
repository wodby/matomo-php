#!/usr/bin/env bash

# Tests matomo-php: the image itself, then matomo-install-release in an image
# built on it, then the whole app.sh suite against that image.

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

app="${NAME}-app"

cleanup() {
    local status=$?
    docker rmi -f "${app}" "${app}-notempty" > /dev/null 2>&1 || true
    exit "${status}"
}
trap cleanup EXIT

expect() {
    local description=$1 actual=$2 expected=$3
    echo -n "${description}... "
    if [[ "${actual}" != *"${expected}"* ]]; then
        echo "Error: expected ${expected}, got: ${actual}"
        exit 1
    fi
    echo "OK"
}

inspect() {
    docker run --rm --entrypoint sh "${1}" -c "${2}"
}

install() {
    docker run --rm --user root --entrypoint matomo-install-release "${IMAGE}" "${1}" 2>&1 || true
}

expect "Shipping no Matomo" "$(inspect "${IMAGE}" 'ls -A /var/www/html | wc -l')" "0"
expect "Shipping the WodbyInstall plugin" "$(inspect "${IMAGE}" 'ls /usr/local/share/matomo/plugins/WodbyInstall')" "WodbyInstall.php"
expect "Shipping the GeoLite database" "$(inspect "${IMAGE}" 'ls /usr/local/share/matomo/geolite')" "GeoLite2-City.mmdb"
expect "Shipping gpg for release checks" "$(inspect "${IMAGE}" 'command -v gpg')" "gpg"

expect "Refusing a version that is not a release" "$(install latest)" "Set a Matomo release version"
expect "Refusing an unsupported major version" "$(install 4.16.1)" "This image supports Matomo 5, not Matomo 4"

docker build -q -t "${app}-notempty" - > /dev/null <<DOCKERFILE
FROM ${IMAGE}
RUN touch /var/www/html/index.php
DOCKERFILE
expect "Refusing a directory that already has code" \
    "$(docker run --rm --user root --entrypoint matomo-install-release "${app}-notempty" "${MATOMO_VER}" 2>&1 || true)" "is not empty"

echo -n "Building an image with Matomo ${MATOMO_VER}... "
docker build -q -t "${app}" - > /dev/null <<DOCKERFILE
FROM ${IMAGE}
USER root
RUN matomo-install-release ${MATOMO_VER}
USER wodby
DOCKERFILE
echo "OK"

code() {
    inspect "${app}" "cd /var/www/html && ${1}"
}
expect "Installing the release" "$(code "grep -o \"VERSION = '[^']*'\" core/Version.php")" "'${MATOMO_VER}'"
expect "Adding the WodbyInstall plugin" "$(code 'ls plugins/WodbyInstall')" "WodbyInstall.php"
expect "Adding the GeoLite database" "$(code 'ls misc/GeoLite2-City.mmdb')" "GeoLite2-City.mmdb"
expect "Linking the settings to the files directory" "$(code 'readlink config/config.ini.php')" "/mnt/files/config/config.ini.php"
expect "Linking custom logos to the files directory" "$(code 'readlink misc/user')" "/mnt/files/misc-user"
expect "Linking Marketplace plugins to the files directory" "$(code 'readlink marketplace-plugins')" "/mnt/files/plugins"
expect "Writing Matomo's .htaccess files" "$(code 'ls core/.htaccess')" "core/.htaccess"
expect "Leaving everything owned by wodby" "$(code 'find . ! -user wodby | wc -l')" "0"

echo "Running the application tests with Matomo ${MATOMO_VER}"
IMAGE="${app}" NAME="${NAME}" ./app.sh

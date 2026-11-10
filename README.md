# Matomo PHP Docker Container Image

[![Build Status](https://github.com/wodby/matomo-php/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/matomo-php/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/matomo-php.svg)](https://hub.docker.com/r/wodby/matomo-php)

PHP-FPM and Apache with Wodby's setup for [Matomo](https://matomo.org), but without Matomo itself: an image built on
this one installs the Matomo release it wants. Use it to keep Matomo's version in your own repository, the way
[wodby/drupal-php](https://github.com/wodby/drupal-php) leaves Drupal's code to the application. For an image with
Matomo already installed, use [wodby/matomo](https://github.com/wodby/matomo).

## Docker Images

Use image revision tags such as `wodby/matomo-php:8.4-rN` to select a Wodby image revision. See
[release tags](https://github.com/wodby/matomo-php/tags) for available revisions and the
[image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.

- Based on the Apache variant of [wodby/php](https://github.com/wodby/php), where Apache passes PHP to PHP-FPM in the
  same container
- Built for `linux/amd64` and `linux/arm64`
- [GitHub actions builds](https://github.com/wodby/matomo-php/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/matomo-php)

Supported tags and respective `Dockerfile` links:

* `8.4`, `8`, `latest` [_(Dockerfile)_](https://github.com/wodby/matomo-php/tree/master/Dockerfile)

## Installing Matomo

`/var/www/html` is empty. Install a Matomo release in an image built on this one:

```dockerfile
FROM wodby/matomo-php:8.4
USER root
RUN matomo-install-release 5.14.2
USER wodby
```

`matomo-install-release` downloads the release from builds.matomo.org, checks its signature and puts it in
`/var/www/html` with Wodby's additions: the WodbyInstall plugin, the GeoLite database, Matomo's `.htaccess` files and
the links to the files directory. It supports the Matomo major versions in `MATOMO_MAJOR_VERSIONS` (`5`), and refuses
a directory that already has code. Add your own plugins to `/var/www/html/plugins` afterwards.

## Configuration

On every start the image writes `config/common.config.ini.php`, a layer Matomo reads but never writes, from:

| Variable                  | Default             | Description                                                                 |
|---------------------------|---------------------|-----------------------------------------------------------------------------|
| `DB_HOST`                 | `localhost`         |                                                                             |
| `DB_PORT`                 | `3306`              |                                                                             |
| `DB_NAME`                 | `matomo`            |                                                                             |
| `DB_USERNAME`             |                     |                                                                             |
| `DB_PASSWORD`             |                     |                                                                             |
| `MATOMO_DB_TABLES_PREFIX` | `matomo_`           |                                                                             |
| `MATOMO_SALT`             |                     | Required. A long random string that never changes                          |
| `MATOMO_URL`              | `WODBY_PRIMARY_URL` | Matomo's address; HTTPS here makes Matomo assume HTTPS behind the proxy     |
| `WODBY_HOSTS`             |                     | JSON array of trusted hosts                                                 |
| `MATOMO_TRUSTED_HOSTS`    |                     | More trusted hosts, separated by commas                                     |

It also turns off the web installer, Matomo's own updater and archiving triggered by viewing reports, and takes the
client address from `X-Forwarded-For`.

The files directory, `/mnt/files`, holds `config/config.ini.php` (the settings Matomo writes), custom logos
(`misc-user`, linked from `misc/user`) and plugins installed from the Marketplace (`plugins`, loaded through
`MATOMO_PLUGIN_DIRS`). Share it between all containers of an installation.

## Commands

| Command                  | What it does                                                                         |
|--------------------------|--------------------------------------------------------------------------------------|
| _(default)_              | Serves Matomo on port 80                                                             |
| `matomo-install-release` | Installs a verified Matomo release during an image build, see above                  |
| `matomo-update`          | Installs Matomo into an empty database, or runs `core:update` on an installed one    |
| `matomo-archive`         | Runs `core:archive` with `--url` set to `MATOMO_URL`; run it every hour              |

`matomo-update` installs Matomo the way the web installer does, with the `wodby:install` command of the bundled
WodbyInstall plugin. The superuser comes from `MATOMO_ADMIN_USERNAME` (default `admin`), `MATOMO_ADMIN_PASSWORD` and
`MATOMO_ADMIN_EMAIL`, and the first website from `MATOMO_SITE_URL`, named `MATOMO_SITE_NAME`. It refuses to install
without a password and email, or into a database that already has tables.

## Building with pinned base images

`base-images.mk` pins the `wodby/php` base image by digest. `make` builds `wodby/matomo-php:8.4`, and `make test`
installs Matomo `MATOMO_TEST_VER` on top of it and runs the application tests against MariaDB.

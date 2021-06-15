# Copyright (c) 2018 kalaksi@users.noreply.github.com.
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.

FROM debian:9.13-slim
LABEL maintainer="kalaksi@users.noreply.github.com"

# Some notes about the choices behind this Dockerfile:
# - Not using the official PHP image since it doesn't use the slim-flavor.
# - Using Debian package since they have already done the heavy lifting of patching the sources.

# Use a custom UID/GID that has a smaller chance for collisions with the host and other containers.
ENV PHPLDAPADMIN_UID 70859
ENV PHPLDAPADMIN_GID 70859

# phpldapadmin is only available in stretch-backports
RUN echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/backports.list

# Some trickery is needed to avoid unnecessary dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      php7.0-fpm \
      php7.0-ldap \
      ucf && \
    apt-get download phpldapadmin && \
    DEBIAN_FRONTEND=noninteractive dpkg --force-all -i phpldapadmin_*.deb && \
    rm phpldapadmin_*.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists

# Configure PHP.
RUN sed -Ei 's|^listen =.*|listen = [::]:9000|' /etc/php/7.0/fpm/pool.d/www.conf && \
    sed -Ei 's|^;?access.log =.*|access.log = /proc/self/fd/2|' /etc/php/7.0/fpm/pool.d/www.conf && \
    sed -Ei 's|^;?catch_workers_output =.*|catch_workers_output = yes|' /etc/php/7.0/fpm/pool.d/www.conf && \
    sed -Ei 's|^;?clear_env =.*|clear_env = no|' /etc/php/7.0/fpm/pool.d/www.conf && \
    sed -Ei 's|^;?error_log =.*|error_log = /proc/self/fd/2|' /etc/php/7.0/fpm/php-fpm.conf && \
    sed -Ei 's|^;?daemonize =.*|daemonize = no|' /etc/php/7.0/fpm/php-fpm.conf && \
    mkdir /run/php && \
    chown ${PHPLDAPADMIN_UID}:${PHPLDAPADMIN_GID} /run/php

# Add default configuration for nginx. This Using separate directory so it's simpler to mount to vanilla nginx-container.
# See docker-compose.yml for an example.
COPY nginx.conf /etc/nginx/conf.d/phpldapadmin.conf

# You should mount a volume on path /usr/share/phpldapadmin/htdocs for sharing the htdocs between this container
# and the HTTP server container.
RUN mv /usr/share/phpldapadmin/htdocs /usr/share/phpldapadmin/htdocs.orig && \
    mkdir /usr/share/phpldapadmin/htdocs && \
    chown ${PHPLDAPADMIN_UID}:${PHPLDAPADMIN_GID} /usr/share/phpldapadmin/htdocs && \
    chgrp -R ${PHPLDAPADMIN_GID} /etc/phpldapadmin

USER ${PHPLDAPADMIN_UID}:${PHPLDAPADMIN_GID}

# Makes sure any updates to phpldapadmin get copied to the htdocs data volume.
CMD set -eu; \
    cp -ua /usr/share/phpldapadmin/htdocs.orig/. /usr/share/phpldapadmin/htdocs/; \
    exec /usr/sbin/php-fpm7.0 -c /etc/php/7.0/fpm/php.ini -d 'error_reporting=E_COMPILE_ERROR|E_RECOVERABLE_ERROR|E_ERROR|E_CORE_ERROR'

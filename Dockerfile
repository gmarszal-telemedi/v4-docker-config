# ---------------------------------------------- Build Time Arguments --------------------------------------------------
ARG PHP_VERSION="8.2"
ARG PHP_ALPINE_VERSION="3.18"
ARG NGINX_VERSION="1.24"
ARG COMPOSER_VERSION="2"
ARG XDEBUG_VERSION="3.1.3"
ARG COMPOSER_AUTH
ARG APP_BASE_DIR="."
ARG NODE_VERSION="16.20.2"

FROM surnet/alpine-wkhtmltopdf:3.17.0-0.12.6-full as wkhtmltopdf

# --------------------------------------------- NODE Image ---------------------------------------------------
FROM node:$NODE_VERSION-alpine$PHP_ALPINE_VERSION AS node
# -------------------------------------------------- Composer Image ----------------------------------------------------

FROM composer:${COMPOSER_VERSION} as composer

# ======================================================================================================================
#                                                   --- Base ---
# ---------------  This stage install needed extenstions, plugins and add all needed configurations  -------------------
# ======================================================================================================================

FROM php:${PHP_VERSION}-fpm-alpine${PHP_ALPINE_VERSION} AS base

# Required Args ( inherited from start of file, or passed at build )
ARG XDEBUG_VERSION

# Set SHELL flags for RUN commands to allow -e and pipefail
# Rationale: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ------------------------------------- Install Packages Needed Inside Base Image --------------------------------------

RUN RUNTIME_DEPS="tini fcgi"; \
    SECURITY_UPGRADES="curl"; \
    apk add --no-cache --upgrade ${RUNTIME_DEPS} ${SECURITY_UPGRADES}

# ---------------------------------------- Install / Enable PHP Extensions ---------------------------------------------


RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    openssl \
    libzip-dev \
    icu-dev \
    icu-data-full \
    imagemagick-dev \
    libwebp-dev \
    libxpm-dev \
    freetype \
    libpng \
    libjpeg-turbo \
    freetype-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    rabbitmq-c-dev \
    php82-mysqli \
    php82-soap \
    php82-calendar \
    libmcrypt-dev \
    libssh2-dev \
    autoconf \
    build-base \
    libxml2-dev \
    libssh2 \
    libxslt-dev \
    curl \
    libgcc \
    libstdc++ \
    libx11 glib \
    libxrender \
    libxext \
    libintl \
    libressl \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    tzdata\
    imagemagick\
    gpgme \
    gnu-libiconv \
    qpdf \
    wget \
    php82-xsl \
    libxml2 \
    php82-gd \
    #php82-intl \
    linux-headers \
    openjdk8 \
    libc6-compat \
    # PHP Extensions --------------------------------- \
    && docker-php-ext-configure gd --enable-gd --prefix=/usr --with-jpeg --with-freetype \
#    intl \
#    bcmath \
    # PHP Extensions --------------------------------- \
    && docker-php-ext-install -j$(nproc) \
    gd          \
    intl        \
    opcache     \
    pdo_mysql   \
    zip         \
    bcmath      \
    sockets     \
    calendar    \
    soap        \
    xsl         \
    exif        \


    # Pecl Extensions -------------------------------- \
    && pecl install apcu imagick amqp-1.11.0 mcrypt ssh2 xdebug && docker-php-ext-enable apcu imagick amqp mcrypt ssh2 zip bcmath gd soap xdebug \
    # ---------------------------------------------------------------------
    # Install Xdebug at this step to make editing dev image cache-friendly, we delete xdebug from production image later
    #&& pecl install xdebug-${XDEBUG_VERSION} \
    # Cleanup ---------------------------------------- \
    && rm -r /tmp/pear; \
    # - Detect Runtime Dependencies of the installed extensions. \
    # - src: https://github.com/docker-library/wordpress/blob/master/latest/php8.0/fpm-alpine/Dockerfile \
    out="$(php -r 'exit(0);')"; \
    [ -z "$out" ]; err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
    [ -z "$err" ]; extDir="$(php -r 'echo ini_get("extension_dir");')"; \
    [ -d "$extDir" ]; \
    runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive "$extDir" \
    | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    # Save Runtime Deps in a virtual deps
    apk add --no-network --virtual .php-extensions-rundeps $runDeps; \
    # Uninstall Everything we Installed (minus the runtime Deps)
    apk del --no-network .build-deps; \
    # check for output like "PHP Warning:  PHP Startup: Unable to load dynamic library 'foo' (tried: ...)
    err="$(php --version 3>&1 1>&2 2>&3)"; 	[ -z "$err" ]

RUN wget -O /tmp/datadog-php-tracer.apk https://github.com/DataDog/dd-trace-php/releases/download/0.92.2/datadog-php-tracer_0.92.2_x86_64.apk
RUN apk add /tmp/datadog-php-tracer.apk --allow-untrusted

#RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
#    && architecture=$(uname -m) \
#    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/$architecture/$version \
#    && mkdir -p /tmp/blackfire \
#    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
#    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
#    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://127.0.0.1:8307\n" > /usr/local/etc/php/conf.d/98-blackfire.ini \
#    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz
# -----------------------------------------------
### WKHTMLTOPDF

RUN apk add --update \
    supervisor \
    imagemagick-dev \
    imagemagick \
    curl \
    libgcc \
    libstdc++ \
    glib \
    libx11  \
    libxrender \
    libxext \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    tzdata\
    gpgme \
    gnu-libiconv \
    qpdf \
    wget \
    yarn \
    openjdk8 \
    screen

COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/wkhtmltopdf
COPY --from=wkhtmltopdf /bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf
COPY --from=wkhtmltopdf /bin/wkhtmltoimage /bin/wkhtmltoimage
COPY --from=wkhtmltopdf /bin/wkhtmltoimage /usr/local/bin/wkhtmltoimage
COPY --from=wkhtmltopdf /bin/libwkhtmltox* /bin/
COPY --from=wkhtmltopdf /bin/libwkhtmltox* /usr/local/bin/

ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so
ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
ENV PATH="$JAVA_HOME/bin:${PATH}"

####

# ------------------------------------------------- NODE Deps ----------------------------------------------------------
RUN apk add --update build-base python3
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin
# ------------------------------------------------- Permissions --------------------------------------------------------

# - Clean bundled config/users & recreate them with UID 1000 for docker compatability in dev container.
# - Create composer directories (since we run as non-root later)
# - Add Default Config
RUN deluser --remove-home www-data && adduser -u1000 -D www-data && rm -rf /var/www /usr/local/etc/php-fpm.d/* && \
    mkdir -p /var/www/.composer /app && chown -R www-data:www-data /app /var/www/.composer; \
    # ------------------------------------------------ PHP Configuration ---------------------------------------------------
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Add in Base PHP Config
COPY docker/kubephp/docker/php/base-*   $PHP_INI_DIR/conf.d

# ---------------------------------------------- open SSL Configuration -------------------------------------------------
COPY docker/kubephp/docker/ssl/openssl.cnf /etc/ssl/openssl.cnf

# ---------------------------------------------- PHP FPM Configuration -------------------------------------------------

# PHP-FPM config
COPY docker/kubephp/docker/fpm/*.conf  /usr/local/etc/php-fpm.d/


# --------------------------------------------------- Scripts ----------------------------------------------------------

COPY docker/kubephp/docker/entrypoint/*-base docker/kubephp/docker/post-build/*-base docker/kubephp/docker/pre-run/*-base \
    docker/kubephp/docker/fpm/healthcheck-fpm	\
    docker/kubephp/docker/scripts/command-loop*	\
    # to
    /usr/local/bin/

RUN  chmod +x /usr/local/bin/*-base /usr/local/bin/healthcheck-fpm /usr/local/bin/command-loop*

# ---------------------------------------------------- Composer --------------------------------------------------------

COPY --from=composer /usr/bin/composer /usr/bin/composer

# ----------------------------------------------------- MISC -----------------------------------------------------------

WORKDIR /app
USER www-data

# Common PHP Frameworks Env Variables
ENV GOOGLE_CLOUD_PROJECT='telemedico-prod-v1-03aa'
ENV APP_ENV prod_k8s
ENV APP_DEBUG 0

# Validate FPM config (must use the non-root user)
RUN php-fpm -t

# ---------------------------------------------------- HEALTH ----------------------------------------------------------

HEALTHCHECK CMD ["healthcheck-fpm"]

# -------------------------------------------------- ENTRYPOINT --------------------------------------------------------

ENTRYPOINT ["entrypoint-base"]
CMD ["php-fpm"]

# ======================================================================================================================
#                                                  --- Vendor ---
# ---------------  This stage will install composer runtime dependinces and install app dependinces.  ------------------
# ======================================================================================================================

FROM composer as vendor

ARG PHP_VERSION
ARG COMPOSER_AUTH
ARG APP_BASE_DIR

# A Json Object with remote repository token to clone private Repos with composer
# Reference: https://getcomposer.org/doc/03-cli.md#composer-auth
ENV COMPOSER_AUTH $COMPOSER_AUTH

WORKDIR /app

# Copy Dependencies files
COPY $APP_BASE_DIR/composer.json composer.json
COPY $APP_BASE_DIR/composer.lock composer.lock
COPY $APP_BASE_DIR/shared shared/

# Set PHP Version of the Image
RUN composer config platform.php ${PHP_VERSION}; \
    # Install Dependencies
    composer install -n --no-progress --ignore-platform-reqs --no-dev --prefer-dist --no-scripts --no-autoloader

FROM node as vendor-nodejs
ARG APP_BASE_DIR
WORKDIR /app

COPY $APP_BASE_DIR/.npmrc .npmrc
COPY $APP_BASE_DIR/package.json package.json
COPY $APP_BASE_DIR/yarn.lock yarn.lock
RUN yarn install

# ======================================================================================================================
# ==============================================  PRODUCTION IMAGE  ====================================================
#                                                   --- PROD ---
# ======================================================================================================================

FROM base AS app

ARG APP_BASE_DIR
USER root

# Copy PHP Production Configuration
COPY docker/kubephp/docker/php/prod-*   $PHP_INI_DIR/conf.d/

# Copy Prod Scripts && delete xdebug
COPY docker/kubephp/docker/entrypoint/*-prod docker/kubephp/docker/post-build/*-prod docker/kubephp/docker/pre-run/*-prod \
    # to
    /usr/local/bin/

RUN  chmod +x /usr/local/bin/*-prod #&& pecl uninstall xdebug

USER www-data

# ----------------------------------------------- Production Config -----------------------------------------------------

# Copy Vendor
COPY --chown=www-data:www-data --from=vendor /app/vendor /app/vendor
COPY --chown=www-data:www-data --from=vendor-nodejs /app/node_modules /app/node_modules

# Copy App Code
COPY --chown=www-data:www-data $APP_BASE_DIR/ .

## Run Composer Install again
## ( this time to run post-install scripts, autoloader, and post-autoload scripts using one command )
RUN composer install --optimize-autoloader --apcu-autoloader --no-dev -n --no-progress && \
    composer check-platform-reqs && \
    post-build-base && post-build-prod && \
    composer dump-autoload --no-dev --classmap-authoritative

# Project specific data
RUN php bin/console bazinga:js-translation:dump assets/js --format=json --pattern=/translations/{domain}.json
RUN php bin/console fos:js-routing:dump --format=json --target=assets/js/fos_js_routes.json
RUN php bin/console assets:install
RUN php bin/console cache:warmup --env=prod_k8s

ENTRYPOINT ["entrypoint-prod"]
CMD ["php-fpm"]

# ======================================================================================================================
# ==============================================  DEVELOPMENT IMAGE  ===================================================
#                                                   --- DEV ---
# ======================================================================================================================

FROM base as app-dev


ENV APP_ENV dev
ENV APP_DEBUG 1

# Switch root to install stuff
USER root

# For Composer Installs
RUN apk --no-cache add git openssh bash;
    # Enable Xdebug
    #docker-php-ext-enable xdebug

# For Xdebuger to work, it needs the docker host IP
# - in Mac AND Windows, `host.docker.internal` resolve to Docker host IP
# - in Linux, `172.17.0.1` is the host IP
# By default, `host.docker.internal` is set as extra host in docker-compose.yml, so it also works in Linux without any
# additional setting. This env is reserved for people who want to customize their own compose configuration.
#ENV XDEBUG_CLIENT_HOST="host.docker.internal"

# ---------------------------------------------------- Scripts ---------------------------------------------------------

# Copy Dev Scripts
COPY docker/kubephp/docker/php/dev-*   $PHP_INI_DIR/conf.d/
COPY docker/kubephp/docker/entrypoint/*-dev  docker/kubephp/docker/post-build/*-dev docker/kubephp/docker/pre-run/*-dev \
    # to
    /usr/local/bin/

RUN chmod +x /usr/local/bin/*-dev; \
    mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

USER www-data
# ------------------------------------------------- Entry Point --------------------------------------------------------

# Entrypoints
ENTRYPOINT ["entrypoint-dev"]
CMD ["php-fpm"]

# ENCORE prod
FROM node AS encore-prod
WORKDIR /app
COPY --chown=www-data:www-data --from=app /app /app
RUN yarn run encore production


FROM app AS cronjob

COPY --chown=www-data:www-data --from=encore-prod /app/public /app/public

USER root

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

FROM app AS app-post
COPY --chown=www-data:www-data --from=encore-prod /app/public /app/public

# ======================================================================================================================
# ======================================================================================================================
#                                                  --- NGINX ---
# ======================================================================================================================
# ======================================================================================================================
FROM nginx:${NGINX_VERSION}-alpine AS nginx

RUN rm -rf /var/www/* /etc/nginx/conf.d/* && adduser -u 1000 -D -S -G www-data www-data
COPY docker/kubephp/docker/nginx/nginx-*   /usr/local/bin/
COPY docker/kubephp/docker/nginx          /etc/nginx/
RUN chown -R www-data /etc/nginx/ && chmod +x /usr/local/bin/nginx-*

# The PHP-FPM Host
## Localhost is the sensible default assuming image run on a k8S Pod
ENV PHP_FPM_HOST "localhost"
ENV PHP_FPM_PORT "9000"
ENV NGINX_LOG_FORMAT "json"

# For Documentation
EXPOSE 8080
EXPOSE 443

# Switch User
USER www-data

# Add Healthcheck
HEALTHCHECK CMD ["nginx-healthcheck"]

# Add Entrypoint
ENTRYPOINT ["nginx-entrypoint"]

# ======================================================================================================================
#                                                 --- NGINX PROD ---
# ======================================================================================================================

FROM nginx AS web

USER root

RUN SECURITY_UPGRADES="curl"; \
    apk add --no-cache --upgrade ${SECURITY_UPGRADES}

USER www-data

# Copy Public folder + Assets that's going to be served from Nginx
COPY --chown=www-data:www-data --from=encore-prod /app/public /app/public

# ======================================================================================================================
#                                                 --- NGINX DEV ---
# ======================================================================================================================
FROM nginx AS web-dev

ENV NGINX_LOG_FORMAT "combined"

COPY --chown=www-data:www-data docker/kubephp/docker/nginx/dev/*.conf   /etc/nginx/conf.d/
COPY --chown=www-data:www-data docker/kubephp/docker/nginx/dev/certs   /etc/nginx/certs/

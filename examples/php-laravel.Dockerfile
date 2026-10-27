# ═══════════════════════════════════════════════════════════════════════════
#  EXEMPLO — Dockerfile de desenvolvimento para projeto PHP 8.x / Laravel
# ═══════════════════════════════════════════════════════════════════════════
#  Referência para adicionar um 4º microsserviço PHP ao ambiente.
#  Salve como <projeto>/docker/Dockerfile.dev e registre no docker-compose.yml:
#
#    meu_servico:
#      build:
#        context: ../meu-servico
#        dockerfile: docker/Dockerfile.dev
#      working_dir: /var/www/meu-servico
#      volumes:
#        - ../meu-servico:/var/www/meu-servico
#
#  As três regras que fazem esta imagem ser de DEV e não de produção:
#    1. sem COPY do código        → ele vem por volume
#    2. sem composer install      → roda contra o volume, via make install
#    3. sem USER fixo             → uid remapeado para o do host
# ═══════════════════════════════════════════════════════════════════════════

FROM php:8.3-fpm

ARG UID=1000
ARG GID=1000
# Troque pelo caminho do seu serviço; precisa ser idêntico ao working_dir do
# compose E ao root do vhost no nginx/default.conf.
ARG APP_PATH=/var/www/meu-servico

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev libzip-dev libicu-dev libonig-dev libpng-dev libxml2-dev \
        libcurl4-openssl-dev unzip git curl \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql pgsql bcmath intl mbstring zip gd xml curl pcntl opcache \
    # soap só é necessário para quem fala com a SEFAZ (nfe-api). Remova se não for o caso.
    && docker-php-ext-install soap \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*

RUN usermod -u ${UID} www-data && groupmod -g ${GID} www-data

RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'upload_max_filesize=32M'; \
        echo 'post_max_size=32M'; \
        echo 'memory_limit=512M'; \
    } > /usr/local/etc/php/conf.d/zz-dev.ini

RUN git config --global --add safe.directory ${APP_PATH}

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR ${APP_PATH}

EXPOSE 9000
CMD ["php-fpm"]

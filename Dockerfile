# syntax=docker/dockerfile:1.7
# ============================================================
# Stage 1 — Build del SPA Vue.
# ============================================================
FROM node:22-alpine AS frontend

WORKDIR /app

# Instalamos deps primero (cacheable mientras package*.json no cambien).
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --no-audit --no-fund

# Copiamos el código del frontend y generamos /app/dist.
COPY frontend/ ./
RUN npm run build

# ============================================================
# Stage 2 — Vendor de Composer (sin dev deps).
# ============================================================
FROM composer:2 AS vendor

WORKDIR /app

COPY backend/composer.json backend/composer.lock ./
# --no-scripts evita correr post-install (que necesita artisan + el resto del
# código); el dump-autoload final corre en la imagen runtime ya con todo el árbol.
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --no-interaction

# ============================================================
# Stage 3 — Runtime: nginx + php-fpm (serversideup).
# ============================================================
FROM serversideup/php:8.4-fpm-nginx-alpine

USER root

WORKDIR /var/www/html

# Código backend.
COPY --chown=www-data:www-data backend/ /var/www/html/

# Vendor de Composer (compilado en stage 2).
COPY --from=vendor --chown=www-data:www-data /app/vendor /var/www/html/vendor

# Build del SPA: el index.html y assets quedan en public/, servidos por nginx
# como SPA con fallback a /index.html.
COPY --from=frontend --chown=www-data:www-data /app/dist /var/www/html/public/

# Generamos autoload optimizado y cachés de config/route. El cache de view se
# regenera en runtime cuando es necesario.
RUN cd /var/www/html \
    && composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && php artisan config:clear \
    && php artisan route:clear \
    && chown -R www-data:www-data storage bootstrap/cache

# nginx: routing /api y /up → PHP-FPM, todo lo demás → SPA (index.html).
COPY docker/nginx-server.conf /etc/nginx/server-opts.d/fincore.conf

# Entrypoint script — corre migraciones en cada arranque (idempotente).
COPY docker/entrypoint.sh /etc/entrypoint.d/30-fincore.sh
RUN chmod +x /etc/entrypoint.d/30-fincore.sh

# Volvemos al user no-root estándar de serversideup.
USER www-data

#!/bin/sh
# Entrypoint propio que corre antes de levantar php-fpm + nginx. La imagen
# serversideup/php ejecuta todo lo que tenga permiso x en /etc/entrypoint.d/
# en orden numérico, así que este archivo lleva prefijo "30-" para correr
# después de los setups base (00-, 10-, 20-...).
#
# Idempotente: php artisan migrate es seguro de correr cada arranque; sólo
# aplica migraciones nuevas. --force salta el prompt interactivo que pide
# confirmar en producción.

set -e

cd /var/www/html

php artisan migrate --force

# config:cache y route:cache se hicieron en build, pero los rehacemos por si
# las env vars cambiaron entre deploys (Fly inyecta vía secrets).
php artisan config:cache
php artisan route:cache

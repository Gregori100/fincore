#!/usr/bin/env bash
# install.sh — Setup inicial de FinCore.
#
# Idempotente: puedes correrlo varias veces sin romper nada.
#   1. Crea .env raíz desde .env.example (config del stack Docker).
#   2. Crea backend/.env desde backend/.env.example (config de Laravel).
#   3. Autodetecta puertos libres y rellena UID/GID del usuario actual.
#   4. Instala dependencias PHP (composer) vía imagen oficial.
#   5. Genera APP_KEY si falta.
#   6. Construye la imagen sail-8.4/app.
#   7. Levanta postgres y redis y espera a que estén healthy.
#   8. Corre migraciones y seeders de Laravel (crea la cuenta Bolsa).
#
# Tras correr esto, usa ./scripts/fincore start para arrancar el resto.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
GREY=$'\033[90m'
RESET=$'\033[0m'

step() { printf "${CYAN}▶ %s${RESET}\n" "$1"; }
ok()   { printf "${GREEN}✓ %s${RESET}\n" "$1"; }
warn() { printf "${YELLOW}! %s${RESET}\n" "$1"; }
err()  { printf "${RED}✗ %s${RESET}\n" "$1" >&2; }

command -v docker >/dev/null || { err "Docker no está instalado."; exit 1; }
docker compose version >/dev/null 2>&1 || { err "Necesitas docker compose v2."; exit 1; }
command -v ss >/dev/null 2>&1 || warn "Comando 'ss' no encontrado; la autodetección de puertos puede no funcionar."

# --- helpers para .env ---

env_has() { grep -qE "^$1=" .env; }

env_get() { grep -E "^$1=" .env | tail -n1 | cut -d= -f2-; }

# Añade una línea VAR=VALUE al .env, garantizando que la línea anterior termine
# en newline (evita que ediciones manuales sin "\n" final concatenen la nueva
# variable a la última línea, p. ej. FOO=1BAR=2).
env_append() {
    if [[ -s .env && -n "$(tail -c1 .env)" ]]; then
        printf '\n' >> .env
    fi
    printf '%s\n' "$1" >> .env
}

# Reemplaza in-place la primera línea VAR=... en .env por VAR=VALUE.
# Usa "|" como delimitador para no romper si el valor incluye "/".
env_replace() {
    local var="$1" value="$2"
    sed -i "s|^${var}=.*|${var}=${value}|" .env
}

# Devuelve 0 si un contenedor de *este* proyecto compose ya publica el puerto $1.
# Lo tratamos como "libre" porque al recrearlo va a tomar el mismo mapping.
my_project_uses_port() {
    docker compose ps --format json 2>/dev/null \
        | grep -qE "\"PublishedPort\":$1\b"
}

# Devuelve 0 si algún proceso del host escucha en el puerto $1
# (excluyendo contenedores del propio proyecto, para que reinstalar no
# desplace los puertos que ya están bien asignados).
port_in_use() {
    my_project_uses_port "$1" && return 1
    ss -ltn 2>/dev/null \
        | awk -v p=":$1" '$4 ~ p"$" {found=1} END {exit !found}'
}

# Busca el primer puerto libre comenzando en $1 (rango de 100 puertos).
find_free_port() {
    local port="$1"
    local i
    for i in $(seq 1 100); do
        if ! port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
    err "No se encontró puerto libre cerca de $1"
    return 1
}

# ensure_port VAR DEFAULT
#   Si VAR ya está en .env, sólo avisa si el puerto definido está ocupado.
#   Si no está, autodetecta el primer puerto libre desde DEFAULT y lo añade.
ensure_port() {
    local var="$1" default="$2"
    if env_has "$var"; then
        local current
        current=$(env_get "$var")
        if port_in_use "$current"; then
            # Variable configurada pero el puerto está ocupado: reasignamos al
            # siguiente libre desde el valor actual (queda cerca de la
            # preferencia del usuario en lugar de saltar al default).
            local free
            free=$(find_free_port "$current") || return 1
            env_replace "$var" "$free"
            warn "$var=$current estaba ocupado; reasignado a $free"
        else
            printf "  ${GREY}$var=$current${RESET}\n"
        fi
        return
    fi
    local free
    free=$(find_free_port "$default") || return 1
    env_append "$var=$free"
    if [[ "$free" == "$default" ]]; then
        ok "$var=$free añadido a .env"
    else
        ok "$var=$free añadido a .env (default $default estaba ocupado)"
    fi
}

# ensure_var VAR VALUE
#   Añade VAR=VALUE si no está en .env.
ensure_var() {
    local var="$1" value="$2"
    if env_has "$var"; then
        printf "  ${GREY}$var ya configurado${RESET}\n"
    else
        env_append "$var=$value"
        ok "$var=$value añadido a .env"
    fi
}

# 1. Archivos .env
step "Verificando archivos .env"
if [[ ! -f .env ]]; then
    cp .env.example .env
    ok ".env raíz creado desde .env.example (config del stack Docker)"
else
    printf "  ${GREY}.env raíz ya existe${RESET}\n"
fi

if [[ ! -f backend/.env ]]; then
    cp backend/.env.example backend/.env
    ok "backend/.env creado desde backend/.env.example (config de Laravel)"
else
    printf "  ${GREY}backend/.env ya existe${RESET}\n"
fi

# 2. Puertos y permisos
step "Autodetectando puertos libres y UID/GID"
ensure_port APP_PORT 80
ensure_port VITE_PORT 5173
ensure_port FORWARD_DB_PORT 5432
ensure_port FORWARD_REDIS_PORT 6379
ensure_port FORWARD_MAILPIT_PORT 1025
ensure_port FORWARD_MAILPIT_DASHBOARD_PORT 8025
ensure_var WWWUSER "$(id -u)"
ensure_var WWWGROUP "$(id -g)"

# Sincronizamos APP_URL y FRONTEND_URL en backend/.env con los puertos que
# acabamos de fijar en el .env raíz. Sin esto, los links de email de Laravel
# apuntan al hostname interno de Docker (http://api) y el navegador no puede
# resolverlos.
backend_env_replace() {
    local var="$1" value="$2"
    if grep -qE "^${var}=" backend/.env; then
        sed -i "s|^${var}=.*|${var}=${value}|" backend/.env
    else
        printf '%s=%s\n' "$var" "$value" >> backend/.env
    fi
}
APP_PORT_VAL=$(env_get APP_PORT)
VITE_PORT_VAL=$(env_get VITE_PORT)
backend_env_replace APP_URL "http://localhost:${APP_PORT_VAL}"
backend_env_replace FRONTEND_URL "http://localhost:${VITE_PORT_VAL}"
ok "APP_URL y FRONTEND_URL sincronizados en backend/.env"

# 3. Dependencias PHP
step "Instalando dependencias PHP"
if [[ ! -d backend/vendor ]]; then
    docker run --rm \
        -v "$REPO_ROOT/backend:/app" \
        -w /app \
        composer:2 install --no-interaction --prefer-dist
    ok "vendor/ instalado"
else
    printf "  ${GREY}backend/vendor/ ya existe (saltando)${RESET}\n"
fi

# 4. APP_KEY
step "Verificando APP_KEY"
if ! grep -qE '^APP_KEY=base64:.+' backend/.env; then
    docker run --rm \
        -v "$REPO_ROOT/backend:/var/www/html" \
        -w /var/www/html \
        php:8.4-cli php artisan key:generate --force
    ok "APP_KEY generado"
else
    printf "  ${GREY}APP_KEY ya configurado${RESET}\n"
fi

# 5. Construir imagen sail
step "Construyendo imagen sail-8.4/app (puede tardar la primera vez)"
docker compose build api
ok "Imagen lista"

# 6. Levantar infra (postgres + redis) y esperar healthy
step "Levantando postgres y redis"
docker compose up -d pgsql redis

wait_healthy() {
    local svc="$1"
    local container
    container=$(docker compose ps -q "$svc")
    [[ -z "$container" ]] && { err "Servicio $svc no encontrado"; return 1; }

    printf "  esperando ${svc}"
    for _ in $(seq 1 60); do
        local state
        state=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        if [[ "$state" == "healthy" ]]; then
            printf " ${GREEN}healthy${RESET}\n"
            return 0
        fi
        printf "."
        sleep 1
    done
    printf " ${RED}timeout${RESET}\n"
    return 1
}

wait_healthy pgsql
wait_healthy redis
ok "Infra lista (base de datos fincore creada por POSTGRES_DB)"

# 7. Migraciones + seeders (este último crea la cuenta Bolsa)
step "Corriendo migraciones y seeders de Laravel"
docker compose run --rm --no-deps api php artisan migrate --force --seed
ok "Migraciones y seeders aplicados (cuenta Bolsa creada si no existía)"

echo
ok "Instalación completa."
echo
echo "Siguientes pasos:"
echo "  ${CYAN}./scripts/fincore start${RESET}    # arrancar todo el stack"
echo "  ${CYAN}./scripts/fincore status${RESET}   # ver estado"
echo "  ${CYAN}./scripts/fincore help${RESET}     # todos los comandos"

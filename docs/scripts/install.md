# `scripts/install.sh`

Bootstrap completo del stack. Lo corres **una vez** al clonar el repo, o cuando hagas un nuke total. Es **idempotente**: ejecutarlo de nuevo no rompe nada, detecta lo que ya existe y solo completa lo que falta.

## Uso

```bash
./scripts/install.sh
```

No toma argumentos ni opciones.

## Qué hace, paso a paso

### 1. Verifica que Docker está disponible
Sale con error claro si falta `docker` o si la versión de Compose es anterior a v2.

### 2. Crea los dos archivos `.env`
- **`.env`** raíz desde `.env.example`: configuración del stack Docker (puertos del host, credenciales de Postgres, UID/GID, Xdebug).
- **`backend/.env`** desde `backend/.env.example`: configuración interna de Laravel (APP_KEY, DB connection, etc.).

Si alguno ya existe lo respeta — nunca sobreescribe configuración manual.

> ¿Por qué dos `.env`? El de raíz lo lee `docker compose` para sustituir variables en `compose.yaml`. El de `backend/` lo lee Laravel **dentro** del contenedor. `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` deben coincidir en ambos porque uno inicializa Postgres y el otro se conecta a él.

### 3. Autodetecta puertos libres y rellena UID/GID

Para cada puerto (`APP_PORT`, `VITE_PORT`, `FORWARD_DB_PORT`, `FORWARD_REDIS_PORT`, `FORWARD_MAILPIT_PORT`, `FORWARD_MAILPIT_DASHBOARD_PORT`):

| Estado en `.env` | Estado del puerto | Comportamiento |
|------------------|-------------------|----------------|
| No existe la variable | Default libre | Añade `VAR=default` |
| No existe la variable | Default ocupado | Busca el siguiente libre y añade `VAR=<libre>` |
| Existe la variable | Libre | Lo respeta, info gris |
| Existe la variable | **Ocupado** | **Reasigna al siguiente libre desde su valor actual** y avisa con `!` |

> El "siguiente libre desde el actual" significa que si tenías `APP_PORT=8080` y está ocupado, busca `8081, 8082, ...`, no salta a `80`. Así respeta tu preferencia incremental.

> Un contenedor **del propio proyecto** que ya publica el puerto se considera "libre" (porque al recrearlo va a tomar el mismo mapping). Esto evita que reinstalar te desplace todos los puertos.

`WWWUSER` y `WWWGROUP` se rellenan con tu `id -u` y `id -g` actuales para evitar problemas de ownership en archivos que el contenedor escriba al volumen.

### 4. Instala dependencias PHP

Si `backend/vendor/` no existe, corre `composer install` usando la imagen oficial `composer:2` con `--no-interaction --prefer-dist`. No necesitas Composer instalado localmente.

Si `backend/vendor/` ya existe, se salta este paso.

### 5. Genera `APP_KEY`

Si `backend/.env` no tiene un `APP_KEY=base64:...`, corre `php artisan key:generate --force` usando la imagen `php:8.4-cli`.

Idempotente: si ya hay key, no la regenera.

### 6. Construye la imagen `sail-8.4/app`

Llama `docker compose build api`. La primera vez tarda varios minutos (instala dependencias de sistema en Ubuntu 24.04). Las siguientes ejecuciones aprovechan la caché de Docker y son rápidas.

### 7. Levanta `pgsql` y `redis`, espera healthy

Hace `docker compose up -d pgsql redis` y luego sondea el `Health.Status` de cada uno hasta 60 segundos. La cuenta `fincore` la crea automáticamente Postgres al inicializar (gracias a `POSTGRES_DB` en `compose.yaml`).

### 8. Corre migraciones + seeders

```bash
docker compose run --rm --no-deps api php artisan migrate --force --seed
```

- `migrate`: crea las tablas `accounts` y `journal_entries`.
- `--force`: omite la confirmación interactiva (el script no es TTY-friendly).
- `--seed`: corre `DatabaseSeeder`, que crea la **cuenta Bolsa** singleton (`type=cash`, `is_protected=true`).

> Sin `--seed`, la base queda con tablas vacías y la cuenta Bolsa no existe. Eso rompe los comandos `fin:income`, `fin:expense`, etc. porque asumen que Bolsa existe en `id=1`.

## Salida exitosa

Termina mostrando los siguientes pasos:

```
✓ Instalación completa.

Siguientes pasos:
  ./scripts/fincore start    # arrancar todo el stack
  ./scripts/fincore status   # ver estado
  ./scripts/fincore help     # todos los comandos
```

## Cuándo re-correrlo

| Situación | ¿Re-correr install.sh? |
|-----------|------------------------|
| Cambio de versión de PHP, Composer, o dependencias | Sí, después de `rm -rf backend/vendor` |
| Cambio en `.env.example` que quieres adoptar | Sí, pero respeta lo que ya tienes en `.env`. Compara manualmente si dudas. |
| Puerto se ocupó después de instalar | Sí — re-correrlo reasigna el puerto |
| Quiero resetear solo la base de datos | **No**. Usa [reset.md](./reset.md) nivel 1. |
| Quiero empezar de cero absoluto | Sí, después del nuke total ([reset.md](./reset.md) nivel 4) |

## Troubleshooting

### "Docker no está instalado"
Instala Docker Desktop (Mac/Windows) o Docker Engine (Linux). Verifica con `docker version`.

### "Necesitas docker compose v2"
La nueva sintaxis es `docker compose` (sin guión). Si tu instalación es vieja con `docker-compose`, actualiza Docker.

### "Comando 'ss' no encontrado"
En Linux suele venir con `iproute2`. En macOS usa el package `iproute2mac` o ignora la advertencia: la autodetección de puertos puede fallar silenciosamente pero la instalación continúa.

### El build de Sail tarda >5 minutos
Normal en la primera ejecución (instala Ubuntu + extensiones PHP). Subsecuentes corren en segundos por la caché de Docker.

### `migrate` falla con "could not find driver"
Significa que la imagen Sail se construyó sin la extensión `pdo_pgsql`. Reconstrúyela con `./scripts/fincore rebuild`.

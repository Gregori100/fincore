# Reset y nuke total

Cuando algo se rompe o quieres empezar desde cero, hay **cuatro niveles** de reset según qué tan profundo quieres ir. De más leve a más destructivo.

## Tabla resumen

| Nivel | Qué borra | Cuándo usarlo |
|-------|-----------|---------------|
| **1** | Tablas de la base de datos | Solo necesitas vaciar tablas y resembrar la Bolsa |
| **2** | Contenedores (mantiene volúmenes) | Rename de servicio o config de Compose cambió |
| **3** | Contenedores + volúmenes | BD corrupta o quieres empezar con datos limpios sin reinstalar deps |
| **4** | Todo: containers, volúmenes, imágenes, deps, `.env` | Reset absoluto, algo está raro a nivel profundo |

---

## Nivel 1 — Reset de la base de datos

```bash
docker compose exec api php artisan migrate:fresh --seed --force
```

O usando el manager:
```bash
./scripts/fincore migrate --fresh --seed --force
```

**Qué hace:**
- Tira todas las tablas (`migrate:fresh`).
- Las vuelve a crear desde las migraciones.
- Corre el seeder, que crea la cuenta **Bolsa** singleton.
- `--force` salta la confirmación interactiva (necesaria fuera de TTY).

**Qué se conserva:** todo lo demás. Contenedores, volúmenes, código, `.env`, dependencias.

**Cuándo usarlo:**
- Hiciste muchas pruebas con `fin:income/expense/etc.` y quieres limpiar movimientos sin tocar nada más.
- Quieres validar que el seeder funciona desde una BD vacía.

---

## Nivel 2 — Recrear contenedores (mantiene datos)

```bash
./scripts/fincore down
./scripts/fincore start
```

O directo:
```bash
docker compose down --remove-orphans
docker compose up -d
```

**Qué hace:**
- Elimina los contenedores (`down`).
- `--remove-orphans` limpia containers con nombres viejos (útil si renombraste servicios en `compose.yaml`).
- `start` los vuelve a crear desde la misma imagen.

**Qué se conserva:** volúmenes (datos de Postgres y Redis), imagen `sail-8.4/app`, código.

**Cuándo usarlo:**
- Renombraste un servicio en `compose.yaml` (ej. `laravel.test` → `api`) y los contenedores viejos siguen ahí como huérfanos.
- Cambiaste env vars en `.env` que solo se aplican al crear el contenedor (no a su mero arranque).
- Sospechas que algún proceso quedó en mal estado dentro del contenedor.

---

## Nivel 3 — Borrar volúmenes (pierde datos)

```bash
docker compose down --remove-orphans --volumes
./scripts/fincore start
docker compose exec api php artisan migrate --force --seed
```

**Qué hace:**
- `--volumes` elimina también `fincore_sail-pgsql` y `fincore_sail-redis`.
- Postgres recrea la BD vacía al arrancar (gracias a `POSTGRES_DB`).
- Re-corres migraciones + seeder para tener Bolsa y estructura.

**Qué se conserva:** imagen `sail-8.4/app`, `backend/vendor/`, `frontend/node_modules/`, `.env`, código.

**Cuándo usarlo:**
- La BD quedó corrupta o en estado inconsistente.
- Quieres validar el flujo de instalación de datos sin pagar el costo de reinstalar dependencias.

---

## Nivel 4 — Nuke total

Todo desde cero absoluto. Útil cuando algo profundo está roto y no sabes dónde.

```bash
# 1. Tirar todo: containers + volúmenes + huérfanos
docker compose down --remove-orphans --volumes

# 2. Eliminar la imagen construida del backend
docker rmi sail-8.4/app 2>/dev/null || true

# 3. Eliminar dependencias instaladas
rm -rf backend/vendor frontend/node_modules

# 4. Eliminar archivos .env generados
rm -f .env backend/.env

# 5. Reinstalar todo desde cero
./scripts/install.sh

# 6. Levantar el stack
./scripts/fincore start

# 7. Verificar
./scripts/fincore status
docker compose exec api php artisan fin:state
```

### Como oneliner

```bash
docker compose down --remove-orphans --volumes && \
docker rmi sail-8.4/app 2>/dev/null; \
rm -rf backend/vendor frontend/node_modules .env backend/.env && \
./scripts/install.sh && \
./scripts/fincore start && \
docker compose exec api php artisan fin:state
```

### Qué pasa con cada paso

| Paso | Qué borra | Qué conserva |
|------|-----------|--------------|
| `down --remove-orphans --volumes` | Contenedores + volúmenes + redes + huérfanos | Imágenes, código, archivos en `backend/` y `frontend/` |
| `rmi sail-8.4/app` | Imagen construida del backend | Imágenes base (`postgres:17-alpine`, `node:22-alpine`, `composer:2`, `php:8.4-cli`) |
| `rm -rf backend/vendor` | Dependencias PHP | Código en `backend/app/`, `backend/database/`, etc. |
| `rm -rf frontend/node_modules` | Dependencias JS | Código en `frontend/src/`, `package.json`, etc. |
| `rm -f .env backend/.env` | Configuraciones (puertos, APP_KEY, DB creds) | `*.env.example` (los templates) |
| `./scripts/install.sh` | — | Regenera todo lo borrado |

**Cuándo usarlo:**
- Cambios drásticos en `compose.yaml`, `Dockerfile`, o `composer.json` que sospechas no se están aplicando.
- Quieres probar que un dev nuevo puede clonar y arrancar desde cero.
- Demos / videos donde quieres "instalación limpia" reproducible.

---

## Cómo confirmar que quedó limpio

```bash
# Sin contenedores del proyecto
docker ps -a | grep fincore || echo "limpio"

# Sin volúmenes del proyecto
docker volume ls | grep fincore || echo "limpio"

# Sin imagen sail
docker images | grep sail-8.4 || echo "limpio"

# Sin vendor ni node_modules
ls backend/vendor frontend/node_modules 2>&1 | grep -i "no such"
```

Si después del install + start ves la cuenta Bolsa con balance 0 en `fin:state`, el nuke quedó perfecto.

---

## Solución de problemas comunes

### Puerto 80 (o 6379, o cualquier otro) ocupado tras nuke

Desde la mejora reciente, `install.sh` autocorrige: detecta el puerto ocupado y reasigna al siguiente libre. La salida lo muestra con `!`:
```
! APP_PORT=80 estaba ocupado; reasignado a 81
```

Si por alguna razón el autodetect no aplica, edita `.env` manualmente:
```bash
sed -i 's/^APP_PORT=80$/APP_PORT=81/' .env
./scripts/fincore start
```

### Contenedores con nombre viejo (`fincore-laravel.test-1`)

El rename de servicio dejó huérfanos. `--remove-orphans` los limpia:
```bash
docker compose down --remove-orphans
./scripts/fincore start
```

### `Untagged: sail-8.4/app` pero `docker images` lo sigue mostrando

Probablemente otro proyecto Sail también usa esa imagen. Está bien — no la borres si la compartes.

### El install.sh falla a la mitad

Suele ser una de:
- Puerto ocupado y sin autocorrect (versión vieja del script).
- Docker daemon no corriendo.
- Conexión a internet caída durante el `composer install`.

Después de arreglar la causa raíz, simplemente vuelve a correr `./scripts/install.sh`: es idempotente.

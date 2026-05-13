# `scripts/fincore`

Gestor CLI del stack Docker, estilo `git`. Subcomandos para arrancar, detener, reiniciar, revisar estado, ver logs y abrir shells.

Es **local al proyecto**: siempre se invoca como `./scripts/fincore`, no está en `$PATH` global. Si lo ejecutas desde una subcarpeta, igual funciona porque resuelve el repo root vía `dirname "${BASH_SOURCE[0]}"`.

> **Importante**: este NO es el CLI de FinCore (la app). Es el gestor de Docker. El CLI real de la app son los `php artisan fin:*` que viven dentro del contenedor `api`, documentados en [../cli/](../cli/).

## Uso general

```bash
./scripts/fincore <subcomando> [argumentos...]
```

Sin subcomando equivale a `status`.

## Subcomandos

### `start` (alias: `up`)

Arranca el stack completo en background.

```bash
./scripts/fincore start
```

Verifica que la instalación esté completa (`backend/.env` y `backend/vendor/` deben existir; si no, te dice que corras `./scripts/install.sh` primero). Después hace `docker compose up -d` y muestra el estado + URLs:

```
  Backend  → http://localhost:81
  Frontend → http://localhost:5173
  Mailpit  → http://localhost:8025
```

> Los puertos vienen del `.env`. Si tu `APP_PORT` quedó en 81 por autodetect, ahí lo verás.

### `stop`

Detiene todos los servicios pero **conserva los contenedores** (no los borra). Útil cuando vas a apagar la laptop y quieres retomar al día siguiente sin perder estado.

```bash
./scripts/fincore stop
```

### `restart [servicio]`

Reinicia uno o todos los servicios.

```bash
./scripts/fincore restart           # todos
./scripts/fincore restart api       # solo el backend
./scripts/fincore restart frontend  # solo Vite
```

### `down`

**Detiene Y elimina los contenedores.** Pide confirmación antes (`y/N`). Los volúmenes y la imagen se conservan, así que tus datos de Postgres siguen ahí.

```bash
./scripts/fincore down
```

> Para borrar también volúmenes (datos), usa `docker compose down --volumes` directamente. Eso es nivel 3 de [reset.md](./reset.md).

### `status` (alias: `ps`)

Tabla con estado, health y puertos publicados de cada servicio.

```bash
./scripts/fincore status
```

Salida:
```
SERVICIO           ESTADO       HEALTH     PUERTOS
────────           ──────       ──────     ───────
api                running      -          81→80/tcp
frontend           running      -          5173→5173/tcp
pgsql              running      healthy    5432→5432/tcp
redis              running      healthy    6380→6379/tcp
mailpit            running      -          1025→1025/tcp, 8025→8025/tcp
```

- **ESTADO**: `running` (verde), `exited` (rojo), `down` o ausente (gris).
- **HEALTH**: solo aplica a servicios con `healthcheck:` definido en `compose.yaml` (pgsql y redis). El resto muestra `-`.
- **PUERTOS**: mapeo `host→contenedor`. La columna te dice exactamente a qué puerto del host pegar.

### `health`

Verificación activa más allá del estado del contenedor: hace `curl` contra `/up` (endpoint nativo de Laravel para health checks) y contra el puerto del frontend.

```bash
./scripts/fincore health
```

Útil para confirmar que la app está realmente sirviendo, no solo que el contenedor está vivo.

### `logs <servicio>`

Sigue los logs en vivo (tail 100, follow). Ideal para depurar:

```bash
./scripts/fincore logs api
./scripts/fincore logs pgsql
./scripts/fincore logs frontend
```

Salir con `Ctrl+C`.

### `migrate [args]`

Corre migraciones de Laravel. Pasa cualquier argumento de `artisan migrate` adelante:

```bash
./scripts/fincore migrate                       # equivale a php artisan migrate
./scripts/fincore migrate --seed                # migrate + seed
./scripts/fincore migrate --fresh --seed --force  # drop + migrate + seed (RESET total)
./scripts/fincore migrate:status                # no funciona — el comando solo acepta args de "migrate"
```

Detecta si `api` está corriendo: si sí, usa `docker compose exec`; si no, usa `docker compose run --rm --no-deps` (para que funcione incluso recién instalado, antes del primer `start`).

### `shell <servicio>`

Abre una shell interactiva dentro del contenedor. Para `api` usa `bash`; para `pgsql`, `redis` y `frontend` (que son Alpine/minimalistas) usa `sh`.

```bash
./scripts/fincore shell api        # bash en backend Laravel
./scripts/fincore shell pgsql      # sh en Postgres
./scripts/fincore shell frontend   # sh en node Alpine
```

Desde adentro puedes correr cualquier cosa: `php artisan tinker`, `psql`, `redis-cli`, etc.

### `rebuild`

Reconstruye la imagen `sail-8.4/app` (útil si cambiaste el Dockerfile o quieres invalidar caché) y vuelve a levantar el stack.

```bash
./scripts/fincore rebuild
```

### `help`

Muestra la lista resumida de subcomandos. Equivale al header del archivo.

```bash
./scripts/fincore help
./scripts/fincore -h
./scripts/fincore --help
```

## Cómo funciona por dentro

- Detecta el repo root subiendo desde la ubicación del script (`dirname "${BASH_SOURCE[0]}"`).
- Lee `APP_PORT` y `VITE_PORT` del `.env` raíz para imprimir URLs correctas. No "fuentea" el archivo entero para no contagiar el shell.
- Todos los `docker compose ...` se ejecutan con el `compose.yaml` del repo root.
- Los nombres de servicio (`api`, `frontend`, `pgsql`, `redis`) están hardcoded en el array `SERVICES`. Si renombras un servicio en `compose.yaml`, actualiza también esta lista.

## Tabla rápida

| Tarea | Comando |
|-------|---------|
| Levantar todo | `./scripts/fincore start` |
| Ver estado | `./scripts/fincore` (default = status) |
| Logs del backend | `./scripts/fincore logs api` |
| Entrar al contenedor backend | `./scripts/fincore shell api` |
| Reiniciar solo backend | `./scripts/fincore restart api` |
| Apagar (mantener datos) | `./scripts/fincore stop` |
| Apagar y borrar contenedores | `./scripts/fincore down` |
| Reset BD | `./scripts/fincore migrate --fresh --seed --force` |
| Reconstruir imagen | `./scripts/fincore rebuild` |

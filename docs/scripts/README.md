# Scripts de FinCore

El directorio `scripts/` en la raíz del repo contiene **dos scripts shell** que cubren todo el ciclo de vida del stack Docker. Esta carpeta los documenta a fondo.

## Los dos scripts y sus roles

| Script | Cuándo usarlo | Doc |
|--------|---------------|-----|
| **`scripts/install.sh`** | Una vez (primera instalación) o tras un nuke total. Configura `.env`, descarga dependencias, construye la imagen Docker, inicializa la base de datos. | [install.md](./install.md) |
| **`scripts/fincore`** | Todos los días. Levanta, detiene, reinicia el stack; revisa estado y logs; abre shell dentro de los contenedores. | [fincore.md](./fincore.md) |

Además, cuando algo se rompe o quieres empezar limpio, hay **cuatro niveles de reset** descritos en [reset.md](./reset.md).

## Filosofía

- **Todo dentro de Docker**: no se requiere PHP, Composer ni Node instalados localmente. Los scripts usan las imágenes oficiales `composer:2` y `php:8.4-cli` para tareas de bootstrap.
- **Local al proyecto**: ninguno se instala globalmente. Siempre se invocan como `./scripts/<nombre>` desde la raíz del repo.
- **Idempotente**: `install.sh` puede correrse muchas veces sin romper nada — detecta lo que ya existe y lo respeta o regenera según corresponda.
- **Sin estado oculto**: lo que el script hace queda escrito en `.env` o en los contenedores; no hay archivos de marcador ni configuración escondida.

## Flujo típico

```bash
# Primera vez (o tras un nuke)
./scripts/install.sh

# Todos los días
./scripts/fincore start
./scripts/fincore status
./scripts/fincore logs api
./scripts/fincore stop
```

## Diferencia respecto a `php artisan fin:*`

`./scripts/fincore` es el **gestor de Docker**: start/stop, logs, salud. NO es el CLI de la aplicación.

El **CLI de la aplicación** (`fin:income`, `fin:expense`, etc.) corre dentro del contenedor `api` y se documenta aparte en [../cli/](../cli/).

## Cambios recientes notables

- **Mailpit añadido al stack**: nuevo servicio en `compose.yaml` que intercepta los emails de auth (verificación + reset). UI web en `http://localhost:8025` (puerto autodetectado por `install.sh`). El backend manda emails a `mailpit:1025` vía SMTP en lugar del driver `log`.
- **Auth con Sanctum + Bearer tokens**: la API ahora requiere `Authorization: Bearer <token>` en `/api/finance/*` y email verificado. La cuenta Bolsa pasó de ser global a ser una por usuario (la crea el listener `CreateUserBolsaAccount` al registrarse).
- **Rename del servicio backend (`laravel.test` → `api`)**: el contenedor antes se llamaba `fincore-laravel.test-1`; ahora es `fincore-api-1`. Si tienes contenedores viejos colgando, `docker compose down --remove-orphans` los limpia. El cambio fue cosmético — la lógica interna del contenedor (imagen Sail, supervisord, etc.) es idéntica.
- **Autodetect de puertos ampliado**: si `APP_PORT` (o cualquier `*_PORT`) ya está en `.env` pero su valor está ocupado en el host, `install.sh` ahora **reasigna** automáticamente al siguiente puerto libre. Antes solo avisaba y dejaba la configuración rota.
- **DatabaseSeeder vacío**: la cuenta Bolsa ya no se crea por seeder (ahora la crea el listener cuando alguien se registra). El seeder se mantiene como placeholder por si en el futuro queremos crear datos de dev.

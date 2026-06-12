# Deploy "casero" via Tailscale

Solución mientras no hay hosting con tarjeta. La PC corre el stack Docker
unificado (nginx + php-fpm + SPA built) y Tailscale lo hace accesible desde el
celular y otros devices con URL HTTPS estable y certificado válido. Cero costo,
cero tarjeta, pero **depende de tu PC encendida**.

> Cuando migres a Fly.io o un VPS, este modo queda como respaldo "demo local"
> y el `fly.toml` toma el relevo.

## Dos modos de acceso (no son excluyentes)

| Modo | Cuándo conviene | Privacidad | Setup |
|---|---|---|---|
| **Tailscale client** (recomendado por default) | Solo vos y devices que controlás (laptop, celular, tablet) | Solo dispositivos en tu tailnet entran | Instalar app Tailscale en cada device + login con misma cuenta |
| **Tailscale Funnel** | Mostrar la app a alguien sin Tailscale (familiar, demo) | URL pública en internet — cualquiera con el link entra | Habilitar Funnel en admin + `sudo tailscale funnel --bg 8081` |

**Recomendación**: arrancar con **client mode** (Tailscale en celular). Sólo
prender Funnel cuando lo necesites para terceros. Apagarlo después con
`sudo tailscale funnel reset` para reducir superficie expuesta.

## Arquitectura

```
   internet (HTTPS)
   ─────────────────────►
                          tailscale-funnel relay (Cloudflare-grade)
                          ─────────────────────►
                                                  loma-latitude-3540
                                                  (tu PC con tailscaled)
                                                  ─────────────────────►
                                                                         localhost:8081
                                                                         (fincore-tailscale-app)
                                                                         ─────────────────────►
                                                                                                fincore-tailscale-pgsql
                                                                                                (volume fincore_sail-pgsql)
```

- **Una sola imagen** (la del `Dockerfile` raíz) sirve SPA + API en el mismo
  origen (`nginx` delante de `php-fpm`). Cero CORS.
- **Postgres reusa el volume de Sail dev** (`fincore_sail-pgsql`). Tus datos
  actuales son los datos de prod. No hay migración.
- **Tailscale Funnel** redirige la URL pública `https://<host>.<tailnet>.ts.net`
  a `localhost:8081` en tu PC.

## Pre-requisitos

1. `tailscale` instalado y logueado en tu PC (`tailscale status` muestra tu IP
   100.x.y.z).
2. Docker funcionando.
3. Sail dev **apagado** (`./scripts/fincore stop` o `docker compose down`). El
   stack de Tailscale Funnel y Sail comparten el mismo Postgres data dir; no
   pueden estar arriba al mismo tiempo.

## Setup inicial (una sola vez)

### 1. Habilitar Funnel en tu admin de Tailscale

1. Entrar a [login.tailscale.com/admin/settings/features](https://login.tailscale.com/admin/settings/features).
2. Activar **HTTPS Certificates**.
3. Activar **Funnel** (te pide aceptar términos).
4. En [DNS](https://login.tailscale.com/admin/dns), verificar que **MagicDNS**
   esté ON.
5. (Opcional) Cambiar el "Tailnet name" a algo legible (`gregori100.ts.net`).
   Solo se puede hacer **una vez** y cambia las URLs de todos tus nodos. Si lo
   cambiás, actualizá `APP_URL` y `FRONTEND_URL` en `.env.tailscale`.

### 2. Construir la imagen productiva

Desde la raíz del repo:

```bash
docker compose -f compose.tailscale.yml build
```

Tarda ~3-5 min la primera vez (3 stages: build SPA Vue → vendor Composer →
runtime nginx+php-fpm). Builds posteriores son rápidos por la cache de Docker.

### 3. Levantar el stack

```bash
docker compose -f compose.tailscale.yml up -d
```

Esto levanta `fincore-tailscale-pgsql` (con tus datos de dev) y
`fincore-tailscale-app` (la imagen unificada). El `entrypoint.sh` corre
migraciones idempotentes en cada arranque.

Verificar logs:

```bash
docker compose -f compose.tailscale.yml logs -f app
```

Healthcheck local antes de exponer:

```bash
curl -i http://localhost:8081/up           # debe responder 200
curl -i http://localhost:8081/api/auth/me  # debe responder 401 (sin token)
```

### 4a. Habilitar acceso desde celular — modo recomendado: Tailscale client

1. Instalar la app **Tailscale** en el celular (Play Store / App Store).
2. Sign in con la misma cuenta que en la laptop (GitHub `Gregori100` en este caso).
3. La app conecta al tailnet automáticamente; verás tu laptop en la lista de
   devices.
4. Abrir en el browser del celular:
   ```
   https://loma-latitude-3540.tail285790.ts.net
   ```
5. Login con tu user de dev (es la misma BD que dev).

> **Funciona en cualquier red** (4G, wifi pública, hotel) — Tailscale arma el
> túnel WireGuard sobre cualquier conexión.

### 4b. (Opcional) Exponer públicamente con Funnel

Sólo si querés que la URL sea accesible desde **cualquier dispositivo en
internet** (no solo los que tienen Tailscale instalado).

```bash
sudo tailscale funnel --bg 8081
```

> **Ojo con la propagación DNS**: la primera vez puede tardar 5-30 minutos en
> que la URL resuelva desde resolvers públicos (Google, Cloudflare). Si en tu
> celular con datos ves "no se puede acceder al sitio", consultá DNS público
> desde la laptop (`dig @8.8.8.8 <tu-host>.<tailnet>.ts.net`) — si devuelve
> vacío, esperá más; si devuelve IP, el celular debería abrir tras limpiar su
> caché DNS (modo avión → datos).

Para apagar Funnel:
```bash
sudo tailscale funnel reset
```

### 5. Smoke

1. Abrir la URL en el browser del celular.
2. Login con tu user de dev.
3. Crear un movimiento de prueba, verificar que aparece.
4. (Opcional) En Chrome Android: menú → "Agregar a pantalla de inicio". Te
   queda el ícono como app independiente (pre-PWA install — el siguiente
   sprint pule esto con manifest + service worker).

## Operación rutinaria

### Apagar el stack
```bash
docker compose -f compose.tailscale.yml down
```

### Apagar Funnel
```bash
sudo tailscale funnel --bg 8081 off
# o forma equivalente
sudo tailscale funnel reset
```

### Ver logs
```bash
docker compose -f compose.tailscale.yml logs -f app
docker compose -f compose.tailscale.yml logs -f pgsql
```

### Actualizar la app tras cambios de código
```bash
docker compose -f compose.tailscale.yml build app
docker compose -f compose.tailscale.yml up -d --force-recreate app
```

### Ver los emails que Laravel iba a mandar
`MAIL_MAILER=log` deja los emails en el log de la app:
```bash
docker compose -f compose.tailscale.yml logs app | grep -B2 -A20 'Subject:'
```

## Troubleshooting

### "Volume `fincore_sail-pgsql` not found"
Necesitás que el volume exista (lo crea Sail la primera vez). Levantá Sail una
vez (`./scripts/fincore start && ./scripts/fincore stop`) y volvé a intentar.

### "Postgres locked by another process"
Sail dev está arriba. Bajar antes de levantar este stack:
```bash
./scripts/fincore stop   # o docker compose down
docker compose -f compose.tailscale.yml up -d
```

### "Port 8081 already in use"
Otro contenedor del usuario está usando 8081. Editá el compose y cambiá a
8181 o 9081 (libre). No olvides actualizar el comando `tailscale funnel`.

### "Funnel returned 502 Bad Gateway"
La app no está respondiendo en localhost:8081. Verificar:
```bash
docker compose -f compose.tailscale.yml ps          # app debe estar 'healthy'
curl -i http://localhost:8081/up                    # debe ser 200
```

### "404 al refrescar una ruta del SPA"
nginx debería caer al `index.html`. Verificá que el container esté usando la
imagen actualizada (build después del último cambio en `docker/nginx-server.conf`).

### Cambié el tailnet name; ahora 419/CSRF mismatch
Tras renombrar el tailnet, la URL pública cambió. Actualizar `APP_URL` y
`FRONTEND_URL` en `.env.tailscale` y recrear el container:
```bash
docker compose -f compose.tailscale.yml up -d --force-recreate app
```

## Lo que NO está cubierto en este modo

- **Email real**: `MAIL_MAILER=log` por simplicidad. Si necesitás verificar
  cuentas nuevas o reset de password reales, cambiar a `smtp` con Resend (no
  pide tarjeta para el free tier de 3000 emails/mes; sí pide verificar
  identidad de envío).
- **PWA install bonito**: por ahora "Agregar a pantalla de inicio" en Chrome
  da un ícono que abre la URL. El sprint siguiente añade `manifest.json` +
  service worker para experiencia tipo app nativa.
- **Backup de la BD**: usar el endpoint `/finance/backup/export` desde la UI.
  Está cubierto desde adentro de la app.
- **Disponibilidad 24/7**: si apagás la PC o se cae el internet de tu casa, la
  app no responde. Ese es el costo de no pagar hosting.

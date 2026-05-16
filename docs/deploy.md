# Deploy a Fly.io

Guía paso a paso del **primer deploy** y la actualización rutinaria de FinCore en Fly.io. El objetivo es tener la app accesible vía HTTPS en `https://<app>.fly.dev`, con Postgres persistente y emails reales de Resend.

## Arquitectura del deploy

```
                    ┌───────────────────────────────┐
   internet (HTTPS) │  Fly proxy + TLS automático   │
   ─────────────────►                               │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │      fincore (Fly app)        │
                    │  ┌─────────────────────────┐  │
                    │  │  nginx (port 8080)      │  │
                    │  │   /api, /up → php-fpm   │  │
                    │  │   /        → SPA dist   │  │
                    │  └─────────────────────────┘  │
                    │  Volume: fincore_storage      │
                    │   → /var/www/html/storage     │
                    └───────────────┬───────────────┘
                                    │ 6PN private network
                                    │ fincore-db.internal:5432
                    ┌───────────────▼───────────────┐
                    │   fincore-db (Fly app)        │
                    │   postgres:17-alpine          │
                    │   Volume: fincore_pgdata      │
                    │    → /var/lib/postgresql/data │
                    └───────────────────────────────┘
```

Una sola app pública (`fincore`) que sirve SPA + API desde el mismo origen (cero CORS, Sanctum funciona limpio). Postgres vive en otra app sin puertos públicos, accesible sólo desde la red privada de Fly.

## Pre-requisitos

1. **Cuenta en Fly.io** con `flyctl` instalado:
   ```bash
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```
2. **Cuenta en Resend** (resend.com). Crear una API key (`re_...`) en el dashboard. Free tier: 3000 emails/mes.
3. **Docker local** funcionando, para builds remotos opcionales y para probar la imagen antes (`docker build -t fincore:test .` en raíz).

## Primer deploy (one-time)

### 1. Inicializar la app principal

Desde la raíz del repo:

```bash
# Crea la app sin lanzar build; usa el fly.toml versionado.
fly launch --copy-config --no-deploy --name fincore --region qro
```

Si el nombre `fincore` ya está tomado en Fly, elegir otro (ej. `fincore-cassellis`) y actualizar:

- `fly.toml` → `app = "fincore-cassellis"`
- `APP_URL` y `FRONTEND_URL` → `"https://fincore-cassellis.fly.dev"`
- `MAIL_FROM_ADDRESS` → `"noreply@<app>.fly.dev"`

### 2. Crear el volume de storage

```bash
fly volumes create fincore_storage --region qro --size 1
```

### 3. Setear los secrets

```bash
# Generar APP_KEY localmente.
APP_KEY=$(docker compose exec -T api php artisan key:generate --show)

fly secrets set \
  APP_KEY="$APP_KEY" \
  DB_USERNAME=postgres \
  DB_PASSWORD="<password fuerte para postgres>" \
  MAIL_PASSWORD="<resend API key — re_...>"
```

> El `DB_PASSWORD` debe coincidir con `POSTGRES_PASSWORD` que se setea en la app de Postgres (paso 5). Anotalo antes de seguir.

### 4. Inicializar la app de Postgres

```bash
cd db
fly launch --copy-config --no-deploy --name fincore-db --region qro
fly volumes create fincore_pgdata --region qro --size 1 -a fincore-db
```

### 5. Secrets de Postgres

```bash
fly secrets set -a fincore-db \
  POSTGRES_USER=postgres \
  POSTGRES_PASSWORD="<mismo password que en DB_PASSWORD del paso 3>"
```

### 6. Deploy de Postgres (primero)

```bash
fly deploy -a fincore-db
fly logs -a fincore-db   # esperar a ver "database system is ready to accept connections"
```

### 7. Deploy de la app

Desde la raíz del repo:

```bash
fly deploy
fly logs   # verificar que migrate corre limpio y nginx escucha en :8080
```

El primer build tarda **3–5 minutos**. Builds posteriores con cache son ~1–2 min.

### 8. Smoke test

- Abrir `https://fincore.fly.dev/` → pantalla de login.
- Registrar usuario nuevo → confirmar en el dashboard de Resend que el email salió.
- Click en el link del email → marca verified.
- Login → crear cuenta débito, registrar gasto, abrir `/reports/cashflow`.
- Repetir desde el celular vía red móvil (sin wifi local) para confirmar HTTPS público.

## Operación diaria

### Actualizar la app

```bash
git pull              # bajar cambios
fly deploy            # build + push + rolling restart
```

`fly deploy` corre el `entrypoint.sh` en el nuevo container, que hace `php artisan migrate --force` automáticamente. Migraciones nuevas se aplican en el deploy.

### Ver logs

```bash
fly logs             # tail en vivo de la app
fly logs -a fincore-db   # logs de postgres
```

### Abrir shell en la VM

```bash
fly ssh console
# dentro:
cd /var/www/html
php artisan tinker
```

### Backup manual de Postgres

```bash
fly ssh console -a fincore-db
# dentro:
pg_dump -U postgres fincore > /tmp/backup.sql

# desde tu máquina, exfiltrar el archivo:
fly ssh sftp get /tmp/backup.sql ./backup-$(date +%F).sql
```

Para algo más automatizado, agregar un cron job dentro del contenedor de Postgres o usar `fly machines exec` desde un workflow externo. Out of scope de este sprint.

### Rotar secrets

```bash
fly secrets set MAIL_PASSWORD="<nueva API key>"
# Fly restartea la app automáticamente.
```

### Apagar / encender la app (free tier)

`auto_stop_machines = "stop"` ya está configurado, así que la app se duerme sola sin tráfico (~5 min) y se levanta sola en el siguiente request. Si querés forzar:

```bash
fly machines stop --select   # apagado manual
fly machines start --select  # encendido manual
```

## Cambiar a dominio propio

Una vez que tengas un dominio (ej. `app.midominio.com`):

```bash
fly certs add app.midominio.com
# Fly imprime un registro CNAME que debes agregar en tu DNS:
#   app.midominio.com CNAME fincore.fly.dev
```

Después actualizar los secrets:

```bash
fly secrets set APP_URL=https://app.midominio.com FRONTEND_URL=https://app.midominio.com
```

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---|---|---|
| 502 al abrir la URL | nginx levantó pero php-fpm crashea | `fly logs` → buscar exception de Laravel (usualmente `APP_KEY` faltante o DB inalcanzable) |
| Emails no llegan | `MAIL_PASSWORD` mal seteado, o Resend rechaza el `from` | Dashboard de Resend → "Emails" para ver bounces. El dominio remitente debe estar verificado en Resend, o usar `onboarding@resend.dev` mientras tanto |
| `connection refused to fincore-db.internal` | App de Postgres no levantó o secret de `DB_PASSWORD` no coincide | `fly logs -a fincore-db`, comparar `fly secrets list` vs `fly secrets list -a fincore-db` |
| HTTPS pero la SPA no carga | Build de Vue no copió `dist/` al image | `fly ssh console`, `ls /var/www/html/public` debe contener `index.html` y `assets/` |
| 419 / CSRF token mismatch | TrustProxies no respeta `X-Forwarded-*` | Confirmar que `bootstrap/app.php` tiene `$middleware->trustProxies(at: '*')` y que el build se rehizo después |

## Costos esperados

- **App principal**: shared-cpu-1x 512 MB. Con `auto_stop_machines` baja a 0 sin tráfico → ~$0/mes para uso esporádico.
- **App Postgres**: shared-cpu-1x 256 MB siempre encendida (no se duerme). ~$2/mes.
- **Volumes**: 1 GB cada uno × $0.15/GB-mes = **$0.30/mes**.
- **Resend**: $0 (free tier).
- **Total estimado**: **$2–3/mes** para uso personal.

Si querés bajar más, también podés dormir la app de Postgres con `auto_stop_machines` y revivirla cuando entres — pero hay riesgo de timeout en el primer login post-suspensión.

## Lo que NO cubre esta guía

- **Multi-region** (latencia internacional). Para un usuario en MX, una sola región (`qro`) sobra.
- **CDN delante** (Cloudflare). Si el sitio crece y querés caching agresivo de assets, agregar después.
- **Worker queue separado**. Hoy `QUEUE_CONNECTION=sync` corre los jobs en la misma request; suficiente para los pocos emails que mandamos.
- **CI/CD con GitHub Actions**. Push manual con `fly deploy` desde local funciona perfecto para esta escala.
- **Backups automatizados de Postgres**. Pendiente: a futuro, un cron o un workflow externo.
- **Sentry / observabilidad externa**. `fly logs` alcanza por ahora.

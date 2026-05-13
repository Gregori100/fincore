# API: Auth

Sanctum + Bearer tokens. Flujo completo: registro → email verification → login → operaciones → logout.

## POST `/api/auth/register`

Crea un usuario nuevo. Dispara el evento `Registered` que:
1. Envía email de verificación.
2. Crea automáticamente la cuenta **Bolsa** (`type=cash`, `is_protected=true`) del usuario.

**Rate limit**: 6 req/min/IP.

### Request
```json
{
  "name": "Diego",
  "email": "diego@example.com",
  "password": "secret1234",
  "password_confirmation": "secret1234"
}
```

### Response 201
```json
{
  "user": {
    "id": 1,
    "name": "Diego",
    "email": "diego@example.com",
    "email_verified_at": null,
    "created_at": "2026-05-13T19:30:00.000000Z",
    "updated_at": "2026-05-13T19:30:00.000000Z"
  },
  "token": "1|abc123def456..."
}
```

### Errores
- `422` si email duplicado, password sin confirmar, o validation falla.

## POST `/api/auth/login`

**Rate limit**: 6 req/min/IP.

### Request
```json
{
  "email": "diego@example.com",
  "password": "secret1234",
  "device_name": "web-chrome"
}
```
`device_name` es opcional (default `default`); útil para nombrar tokens y luego listarlos/revocarlos por dispositivo.

### Response 200
```json
{
  "user": { ... },
  "token": "2|xyz789..."
}
```

### Errores
- `422` credenciales inválidas: `{ "errors": { "email": ["Credenciales inválidas."] } }`.

## GET `/api/auth/me`

Retorna el usuario autenticado. **Requiere auth.**

### Response 200
```json
{
  "user": {
    "id": 1,
    "name": "Diego",
    "email": "diego@example.com",
    "email_verified_at": "2026-05-13T19:35:00.000000Z"
  }
}
```

## POST `/api/auth/logout`

Revoca el token actual (el que viene en `Authorization`). **Requiere auth.**

### Response 200
```json
{ "message": "Sesión cerrada." }
```

Los siguientes requests con el mismo token devuelven `401`.

## POST `/api/auth/logout-all`

Revoca **todos** los tokens del usuario, no solo el actual. **Requiere auth.**

### Response 200
```json
{ "message": "Todas las sesiones cerradas." }
```

## Email verification

### GET `/api/auth/email/verify/{id}/{hash}`

Link que viene en el email de verificación. Es una URL **firmada** con TTL (default 60 min). Al visitarla:
1. Valida el hash contra `sha1(user.email)`.
2. Marca al usuario como verificado.
3. Redirige a `FRONTEND_URL/email-verified`.

**No requiere auth** (el hash firma la autorización).

### POST `/api/auth/email/verification-notification`

Reenvía el email de verificación al usuario actual. **Requiere auth.** Rate-limit 6/min.

### Response 200
```json
{ "message": "Email de verificación reenviado." }
```

Si el usuario ya está verificado:
```json
{ "message": "Email ya verificado." }
```

## Password reset

### POST `/api/auth/password/forgot`

Envía un email con un link de reset al `FRONTEND_URL/reset-password?token=...&email=...`. **Rate limit**: 6/min.

#### Request
```json
{ "email": "diego@example.com" }
```

#### Response 200
```json
{ "message": "We have emailed your password reset link." }
```

Si el email no existe en BD, retorna `422`.

### POST `/api/auth/password/reset`

Recibe el token + email + nueva password. **Rate limit**: 6/min.

#### Request
```json
{
  "token": "abc123...",
  "email": "diego@example.com",
  "password": "newSecret1234",
  "password_confirmation": "newSecret1234"
}
```

#### Response 200
```json
{ "message": "Your password has been reset." }
```

Token inválido o expirado → `422`.

## Mailpit en desarrollo

En desarrollo Docker, los emails (verificación + reset) no se envían a internet — se interceptan por Mailpit. Visita **http://localhost:8025** (o el puerto que `install.sh` te haya asignado) para ver los emails y abrir los links.

## Cómo el frontend debe guardar el token

Patrón recomendado para Vue/Pinia:
- Token en memoria (Pinia store) durante la sesión.
- Refresh token en localStorage solo si quieres persistencia entre recargas.
- Al recargar el navegador con solo memoria: re-login (UX aceptable para app personal).

## Ciclo completo de ejemplo

```bash
# 1. Registro
TOKEN=$(curl -s -X POST http://localhost/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Diego","email":"diego@example.com","password":"secret1234","password_confirmation":"secret1234"}' \
  | jq -r .token)

# 2. Sin verificar email: /finance da 403
curl -s http://localhost/api/finance/state -H "Authorization: Bearer $TOKEN"
# → { "message": "Your email address is not verified." }, status 403

# 3. Abrir Mailpit, copiar link de verificación
open http://localhost:8025
# (manual: copia el link y pega en navegador o curl)

# 4. Después de verificar: /finance funciona
curl http://localhost/api/finance/state -H "Authorization: Bearer $TOKEN" | jq

# 5. Logout
curl -X POST http://localhost/api/auth/logout -H "Authorization: Bearer $TOKEN"
```

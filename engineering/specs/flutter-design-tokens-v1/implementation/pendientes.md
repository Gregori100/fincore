# Pendientes — flutter-design-tokens-v1

## Del sprint

### T017 — Tests unitarios de tokens (baja prioridad)

Los tokens son constantes triviales; su única validación posible es leer su valor y comparar contra el mismo valor. No ofrecen defensa real contra regresión (el archivo `fincore_typography.dart` es su propia especificación).

**Cuándo abrir**: si se agrega un token nuevo con lógica derivada (por ejemplo, un token que se computa a partir de otros: `kEdgeCard = EdgeInsets.all(kSpaceLg)`), un test unitario que valide la relación es útil. Hoy los tokens son valores literales aislados.

### T021 — Smoke manual desktop (SM-01 a SM-06)

Correr `flutter run -d linux` y validar las 6 pantallas principales contra memoria/screenshots pre-sprint. **Diego lo ejecuta al abrir la app**.

Cambios visuales sub-perceptibles esperados (documentados en `decisiones-implementacion.md`):

- Chips: radius 16 → 12 (menos redondeados).
- FilledButton: vertical 14 → 12 (levemente más bajo).
- Alphas de estados seleccionados en pickers: 0.10 → 0.20 (tint más visible).
- Movement row: padding horizontal 14 → 16 (más aire).
- Entries list bottom padding: 80 → 96 (más FAB clearance).
- SectionTitle (headers "MIS CUENTAS"): idénticos (era 11/w600/textSubtle/1.2, ahora `overline` con los mismos valores).

Si algo se ve mal, hotfix en un commit adicional sin bloquear el sprint.

### T022 — Smoke manual Android (SM-01 a SM-09)

Cuando el `flutter build apk --release --split-per-abi` termine, correr:
```
~/Android/Sdk/platform-tools/adb install -r \
  mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
Y validar 9 pantallas + comportamiento con teclado y gestos de nav bar.

## Deuda documentada (para sprints futuros)

Estos NO son del scope del Sprint 1; se listan para trazabilidad.

### Sprint 2 — Language cleanup
- Purga total del voseo rioplatense (`pagás`, `configurá`, `probá`, `acotá`, `necesitás`, `registrá`) en widgets, screens y specs. Ya identificado en la auditoría (S3).

### Sprint 6 — Component library
- Migrar iconografía outlined vs filled con criterio (convención documentada en CLAUDE.md, ejecución masiva pendiente).
- Refactor de `BaseCard` a variantes semánticas `InfoCard`/`ActionCard`/`AlertCard`.
- Extracción de `SelectableCard` compartido para `KindPicker`/`AccountTypePicker` (hoy son gemelos visuales sin código compartido).
- `EmptyState`/`ErrorState`/`LoadingState` compartidos.
- Migrar `credit` type en dashboard de `warning` (amarillo) a `textMuted` o color propio (regla nueva de CLAUDE.md).

### Retrocompatibilidad de tokens
- Evaluar crear `bodyL` (15/w600) en `fincore_typography.dart` si aparecen más widgets pidiendo un token entre `bodyM` (14) y `headingM` (16). Hoy la única deuda es en 2 líneas del `DestructiveDialog` CTAs.
- Evaluar aclarar en CLAUDE.md que sizes intrínsecos de iconos, hero circles y touch targets no requieren `token-exception` (reduce ruido en el code review de futuros sprints — de 14 excepciones bajaríamos a 6-8).

### Migración de screens
- Cada sprint por módulo (Entry form, Dashboard, Reports, Settings, Weekly Budgets) debe migrar los `.dart` de su screen a los tokens en el mismo cambio (regla "boy scout" documentada en CLAUDE.md).

## Bugs no reportados en este sprint

Ninguno. Sprint fue refactor puro sin regresiones detectadas.

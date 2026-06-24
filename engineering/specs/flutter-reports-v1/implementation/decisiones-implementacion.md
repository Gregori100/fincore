# Decisiones tomadas durante implementación — flutter-reports-v1

## DI-01: `Stream<SpendingReport>` con cache en state

El plan DT-06 dejaba abierto si usar `Future` o `Stream` para el reporte. La implementación adoptó **`Stream`** con cache en el state del widget:

```dart
Stream<SpendingReport>? _reportStream;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _reportStream ??= _buildStream();
}

void _updateRange({DateTime? from, DateTime? to}) {
  setState(() {
    if (from != null) _from = from;
    if (to != null) _to = to;
    _reportStream = _buildStream();
  });
}
```

**Razón**:

- `customSelect(...).watch()` con `readsFrom: {journalEntries, categories}` da reactividad gratis: si Diego registra un movimiento desde otra pantalla y vuelve al reporte, ya se ve actualizado sin reentrar.
- El cache evita recrear el Stream en cada `build()`, que de otra forma colgaría `pumpAndSettle` en widget tests (el StreamBuilder ve un Stream nuevo cada frame).
- Patrón idéntico al de `DashboardScreen` para streams BO/DE/CR.

## DI-02: bucket "Sin categoría" con `colorSlug`/`iconSlug` null

El spec/plan sugerían slugs concretos para el bucket "Sin categoría" (`gray` + `category_outlined`). La implementación dejó `colorSlug` y `iconSlug` como **`null`** en el `SpendingBucket` y delegó el fallback al consumidor:

```dart
final color = colorBySlug(bucket.colorSlug);  // colorBySlug(null) → fallback gray
final icon = iconBySlug(bucket.iconSlug);     // iconBySlug(null) → fallback label_outline
```

**Razón**:

- `colorBySlug` y `iconBySlug` ya tienen fallbacks definidos en `category_catalog.dart` (`kFallbackCategoryColor` + `kFallbackCategoryIcon`).
- Hardcodear slug `'category_outlined'` que no existe en el catálogo era confuso.
- El modelo refleja el dominio con honestidad: "sin categoría" → sin slug → null. Render decide.

## DI-03: barras horizontales con `Stack` + `FractionallySizedBox`

En lugar de `fl_chart` (ver Desviación-1), la barra horizontal es:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: SizedBox(
    height: 8,
    child: Stack(
      children: [
        Container(color: FincoreColors.surfaceElevated),
        FractionallySizedBox(
          widthFactor: widthFactor,  // bucket.total / maxTotal, clamp [0,1]
          child: Container(color: color),
        ),
      ],
    ),
  ),
)
```

**Razón**: simple, sin animaciones, accesible y suficiente para el caso de uso. Mismo color que el icono de la categoría arriba de la barra.

## DI-04: Loading state con `SizedBox(height: 1)` (no Skeleton)

Ver Desviación-5. `Skeleton` y `CircularProgressIndicator` tienen animaciones perpetuas que cuelgan `pumpAndSettle`. Trade-off UX vs testabilidad: ganamos tests confiables.

## DI-05: Tests usan `context.push('/reports')` desde el Dashboard

Ver Desviación-4. No usar `initialRoute: '/reports'` del harness — `router.go` cuelga `pumpAndSettle`. El helper `pushReports(tester)` privado encapsula el patrón en `reports_screen_test.dart`.

## DI-06: `_TotalCard` solo render del `report`, sin Stream propio

El `_TotalCard` recibe el `SpendingReport` ya hidratado por el `StreamBuilder` del padre. No tiene Stream interno, no se rinde si no hay data. Mantiene la responsabilidad única.

## DI-07: 1 movimiento vs N movimientos pluralización

El texto del `_TotalCard` distingue "1 movimiento" vs "N movimientos":

```dart
final movimientos = report.count == 1 ? '1 movimiento' : '${report.count} movimientos';
```

Patrón visto en otros lugares del proyecto. Sin librería de i18n adicional.

## DI-08: `OutlinedButton.icon` con label multilinea

El header muestra `Desde\nfecha`:

```dart
OutlinedButton.icon(
  icon: Icon(Icons.calendar_today, size: 16),
  label: Text('Desde\n${dateFormat.format(_from)}', textAlign: TextAlign.center),
  ...
)
```

**Razón**: con el ancho del botón limitado al 50% de la pantalla y el formato de fecha en español ("23 jun 2026"), una sola línea desborda. Multilinea + center es legible y consistente con Material 3.

## DI-09: `pushReports` con `Scaffold` como hint del context

```dart
Future<void> pushReports(WidgetTester tester) async {
  final ctx = tester.element(find.byType(Scaffold));
  GoRouter.of(ctx).push('/reports');
  await tester.pumpAndSettle();
}
```

**Razón**: cualquier widget en el tree del Dashboard sirve para obtener un `BuildContext` válido para `GoRouter.of(ctx).push(...)`. Usar `Scaffold` es el patrón ya establecido en `entry_form_kinds_test.dart` y otros sprints.

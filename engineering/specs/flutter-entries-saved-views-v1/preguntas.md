# Preguntas abiertas

## Datos

- ID: P-001
  Estado: respondida
  Pregunta: ¿Cómo se guarda la dimensión "fecha" en una vista?
  Por que importa: cambia el comportamiento al aplicar la vista en
  un momento distinto al de guardado.
  Opciones:
    A) **Preset semántico (rolling)**: si la vista se guardó con
       preset `thisMonth`, al aplicar en otro mes ajusta al mes
       corriente. Útil si Diego guarda "Gastos del mes" y quiere que
       siempre sea "el mes en que estoy".
    B) **Rango fijo siempre**: guarda `from=2026-05-01, to=2026-05-31`
       siempre. Útil si Diego guarda "Mayo 2026" como auditoría
       histórica fija.
    C) **Híbrido (Recomendado)**: si el preset al guardar era
       `thisMonth`/`lastMonth`/`thisYear`, se guarda como preset
       semántico → rolling al aplicar. Si era `custom`, se guarda
       `from`/`to` exactos → fijo al aplicar. Refleja la intención
       del usuario al momento de guardar.
  Por que importa: define la lógica de `toSavedJson()`/`fromSavedJson()`.
  Impacto si cambia: 5-10 líneas en serializer. Trivial.
  Recomendación inicial: opción **C** (híbrido). Coherente con la
  intención del usuario al guardar.
  Respuesta o decision: **opción C — híbrido**. Confirmado. El
  serializer detecta el preset al guardar: si es semántico
  (thisMonth/lastMonth/thisYear), guarda solo el slug; al aplicar
  recalcula con `dateRangeForPreset(preset, DateTime.now())`. Si era
  `custom`, guarda `from`/`to` exactos como ISO8601.

## UX

- ID: P-002
  Estado: respondida
  Pregunta: ¿Dónde aparece la UI de vistas guardadas?
  Por que importa: define el flujo de uso (cuántos taps para
  guardar/aplicar).
  Opciones:
    A) **Dentro del panel de filtros**: arriba del panel aparece una
       sección "Mis vistas" con dropdown + botón Guardar. Aplicar =
       abrir panel → seleccionar vista → cierra panel automáticamente.
       Centralizado, pero más taps para aplicar.
    B) **En el AppBar de `/entries`** (al lado del icono filtros):
       icono "📚 Mis vistas" abre dropdown. Aplicar = 2 taps (sin
       abrir el panel). Guardar se queda dentro del panel.
       Aplicación más rápida, separación de responsabilidades.
    C) **Híbrido (Recomendado)**: Guardar dentro del panel (donde
       Diego configura los filtros). Aplicar/eliminar/renombrar
       desde un menú accesible en AppBar (icono ⋮ o "Vistas").
       Best-of-both: configurar y guardar juntos; aplicar rápido.
  Por que importa: cambia layout del panel y AppBar.
  Impacto si cambia: 20-50 líneas en `entries_list_screen.dart` o
  `entries_filters_screen.dart`.
  Recomendación inicial: opción **C** (híbrido). Guardar donde se
  configuran los filtros es natural; aplicar desde AppBar evita un
  paso extra cuando ya sabés qué vista querés.
  Respuesta o decision: **opción C — híbrido**. Confirmado.
  - **Guardar**: botón "Guardar vista" dentro del panel de filtros
    (`EntriesFiltersScreen`), debajo de la última sección antes del
    bottom bar.
  - **Aplicar/Renombrar/Eliminar**: icono nuevo de bookmarks
    (📖 / `Icons.bookmark_outline`) en el AppBar de
    `EntriesListScreen`, al lado del icono de filtros (`Icons.tune`).
    Tap abre dropdown con la lista. Cada item con menú ⋮ para
    renombrar/eliminar.

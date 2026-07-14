import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guardrail contra voseo rioplatense en `mobile/lib/`.
///
/// Sprint `flutter-language-cleanup-v1`. Escanea todos los `.dart` bajo
/// `mobile/lib/` (excluyendo `.g.dart` generados) y falla si detecta voseo.
/// Regla vinculante documentada en `CLAUDE.md` → "Convenciones del repo".
///
/// Usar `tienes/puedes/aquí` en UI y comentarios; nunca `tenés/podés/acá`.
///
/// Si un caso legítimo requiere una excepción (por ejemplo, un test que
/// verifica ausencia de voseo o un archivo que enumera los patrones),
/// agregar el path al set `_excludedPaths` con comentario explicativo.
void main() {
  // Regex del voseo — cubre imperativo y presente rioplatense de los verbos
  // más comunes + adverbios y modalizadores típicos. Case-insensitive.
  //
  // Solo incluimos formas INEQUÍVOCAS del voseo. Se excluyen verbos donde
  // la forma con tilde también es forma neutral legítima (`partí/salí/dormí`
  // = pretérito 1ra persona neutro: "yo partí"; también imperativo voseo
  // "¡Partí!"). Ante ambigüedad, preferir NO bloquear.
  final voseoPattern = RegExp(
    r'\b(pagás|configurá|probá|acotá|poné|tocá|ingresá|guardá|elegí|hacé|'
    r'deslizá|necesitás|registrá|querés|tenés|podés|acá|allá|andá|seteás|'
    r'fijate|dale|mirá|volvé|corré)\b',
    caseSensitive: false,
  );

  // Paths a excluir del escaneo. Absolute paths dentro de lib/.
  // Vacío por default: cualquier excepción legítima debe justificarse aquí.
  final excludedPaths = <String>{
    // sin excepciones al día del sprint 2
  };

  test('mobile/lib no contiene voseo rioplatense', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'El test debe correr desde el directorio mobile/ (donde vive lib/).',
    );

    final violations = <String>[];
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !excludedPaths.contains(f.path));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = voseoPattern.firstMatch(line);
        if (match != null) {
          violations.add(
            '${file.path}:${i + 1}: '
            'coincide "${match.group(0)}" → '
            '${line.trim()}',
          );
        }
      }
    }

    if (violations.isNotEmpty) {
      fail(
        'Voseo rioplatense detectado en ${violations.length} sitio(s):\n\n'
        '${violations.join('\n')}\n\n'
        'Regla del repo: usar "tienes/puedes/aquí" en lugar de "tenés/podés/acá".\n'
        'Ver CLAUDE.md → "Convenciones del repo" → español neutral.\n'
        'Si necesitas una excepción legítima, agregar el path al set '
        '`excludedPaths` en `test/language/no_voseo_test.dart` con '
        'comentario justificativo.',
      );
    }
  });
}

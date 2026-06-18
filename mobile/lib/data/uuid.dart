import 'dart:math';

/// Generador simple de UUID v7 (RFC 9562) usando milisegundos epoch + random.
/// Compatible con los UUIDs v7 que el backend Laravel legacy generaba con
/// `HasUuids` (importante para preservar IDs al importar un backup v1).
///
/// Formato: tttttttt-tttt-7xxx-yxxx-xxxxxxxxxxxx
/// donde t = 48 bits de timestamp ms, x = random, y = variant (8/9/a/b).
class UuidV7 {
  static final _random = Random.secure();

  static String generate() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    // 48 bits de timestamp (12 hex digits).
    final tsHex = ms.toRadixString(16).padLeft(12, '0');

    // 4 hex digits: version (7) + 12 bits random.
    final version = 0x7000 | _random.nextInt(0x1000);
    final versionHex = version.toRadixString(16).padLeft(4, '0');

    // 4 hex digits: variant (10xx) + 14 bits random.
    final variant = 0x8000 | _random.nextInt(0x4000);
    final variantHex = variant.toRadixString(16).padLeft(4, '0');

    // 12 hex digits random restantes.
    final rand1 = _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0');
    final rand2 = _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');

    return '${tsHex.substring(0, 8)}-${tsHex.substring(8)}-$versionHex-$variantHex-$rand1$rand2';
  }
}
